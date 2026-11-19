import CryptoKit
import Foundation
import OTPCore
import Security

/// Everything we persist. Saved as AES-GCM encrypted JSON; the key lives in the Keychain.
struct Vault: Codable {
    var tokens: [Token] = []
    var groups: [TokenGroup] = []
    /// Proves the master password (see `ExportPassword`); nil until one is set.
    var exportVerifier: Data?

    init(tokens: [Token] = [], groups: [TokenGroup] = [], exportVerifier: Data? = nil) {
        self.tokens = tokens
        self.groups = groups
        self.exportVerifier = exportVerifier
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try c.decode([Token].self, forKey: .tokens)
        exportVerifier = try c.decodeIfPresent(Data.self, forKey: .exportVerifier)
        if let typed = try? c.decode([TokenGroup].self, forKey: .groups) {
            groups = typed
        } else {
            // Older vaults stored the raw 2FAS groups JSON, and token groups only inside `extra`.
            groups = TwoFAS.groups(from: (try? c.decode(JSONValue.self, forKey: .groups)) ?? .array([]))
            let known = Set(groups.map(\.id))
            for i in tokens.indices where tokens[i].groupId == nil {
                if let id = tokens[i].extra?["groupId"]?.string, known.contains(id) { tokens[i].groupId = id }
            }
        }
    }
}

enum VaultError: Error, LocalizedError {
    case keychain(OSStatus)
    case keyMissing
    case passwordRequired

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            let text = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
            return String(localized: "Keychain: \(text)")
        case .keyMissing:
            return String(localized: "The vault key is missing from the Keychain, so the saved tokens cannot be decrypted.")
        case .passwordRequired:
            return String(localized: "Enter your master password to unlock.")
        }
    }
}

struct VaultStore {
    // Keychain label for the vault key, independent of the bundle ID. Changing it orphans existing vaults.
    static let service = "com.trayotp.vault"
    static let account = "vault-key"

    var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TrayOTP", isDirectory: true).appendingPathComponent("vault.bin")
    }

    /// The re-encrypted vault while the key is being changed (see `rekey`).
    private var pendingURL: URL { fileURL.deletingPathExtension().appendingPathExtension("pending") }

    // MARK: Key

    /// The Keychain item's bytes: a raw 32-byte key, or a key wrapped with the master password.
    /// Prefers the data-protection keychain (needs a team-signed build), then the login keychain.
    func keyItem() throws -> Data? {
        try readKey(dataProtection: true) ?? readKey(dataProtection: false)
    }

    /// Throws `passwordRequired` when the key is protected by a master password.
    func loadOrCreateKey() throws -> SymmetricKey {
        if let data = try keyItem() {
            guard !MasterPassword.isWrapped(data) else { throw VaultError.passwordRequired }
            return SymmetricKey(data: data)
        }
        // Never replace a key while a vault exists: the old tokens would become unreadable.
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { throw VaultError.keyMissing }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        if (try? addKey(data, dataProtection: true)) == nil {
            try addKey(data, dataProtection: false)
        }
        return key
    }

    private func baseQuery(dataProtection: Bool) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        if dataProtection { q[kSecUseDataProtectionKeychain as String] = true }
        return q
    }

    private func readKey(dataProtection: Bool) throws -> Data? {
        var q = baseQuery(dataProtection: dataProtection)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        switch status {
        case errSecSuccess: return out as? Data
        case errSecItemNotFound, errSecMissingEntitlement: return nil
        default: throw VaultError.keychain(status)
        }
    }

    /// Overwrites the existing Keychain item (or creates it).
    private func replaceKeyItem(_ data: Data) throws {
        for dataProtection in [true, false] {
            let status = SecItemUpdate(baseQuery(dataProtection: dataProtection) as CFDictionary,
                                       [kSecValueData as String: data] as CFDictionary)
            switch status {
            case errSecSuccess: return
            case errSecItemNotFound, errSecMissingEntitlement: continue
            default: throw VaultError.keychain(status)
            }
        }
        if (try? addKey(data, dataProtection: true)) == nil {
            try addKey(data, dataProtection: false)
        }
    }

    /// Re-encrypts the vault under `newKey` and stores `keyItem` (the new key, raw or wrapped).
    /// Crash-safe: the new vault goes to vault.pending first, then the Keychain is updated, then the
    /// file is renamed over vault.bin. `load` finishes a switch that was interrupted between steps.
    func rekey(_ vault: Vault, newKey: SymmetricKey, keyItem: Data) throws {
        try write(vault, key: newKey, to: pendingURL)
        try replaceKeyItem(keyItem)
        guard rename(pendingURL.path, fileURL.path) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: fileURL.path])
        }
    }

    private func addKey(_ data: Data, dataProtection: Bool) throws {
        var q = baseQuery(dataProtection: dataProtection)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        q[kSecAttrLabel as String] = "TrayOTP vault key"
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
    }

    // MARK: Vault file

    func load(key: SymmetricKey) throws -> Vault {
        let fm = FileManager.default
        if let vault = try? read(fileURL, key: key) {
            // A leftover pending file means a key change failed before the Keychain was updated.
            try? fm.removeItem(at: pendingURL)
            return vault
        }
        // The Keychain already holds the new key but the rename didn't happen: finish it.
        if fm.fileExists(atPath: pendingURL.path), let vault = try? read(pendingURL, key: key) {
            _ = rename(pendingURL.path, fileURL.path)
            return vault
        }
        guard fm.fileExists(atPath: fileURL.path) else { return Vault() }
        return try read(fileURL, key: key)  // rethrow the real error
    }

    func save(_ vault: Vault, key: SymmetricKey) throws {
        try write(vault, key: key, to: fileURL)
    }

    private func read(_ url: URL, key: SymmetricKey) throws -> Vault {
        let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: url))
        let plain = try AES.GCM.open(sealed, using: key)
        return try JSONDecoder().decode(Vault.self, from: plain)
    }

    private func write(_ vault: Vault, key: SymmetricKey, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let plain = try JSONEncoder().encode(vault)
        guard let combined = try AES.GCM.seal(plain, using: key).combined else { return }
        try combined.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
