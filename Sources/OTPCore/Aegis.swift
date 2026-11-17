import CryptoKit
import Foundation

/// Import of Aegis Authenticator vault exports (plain or password-encrypted JSON).
/// Format: https://github.com/beemdevelopment/Aegis/blob/master/docs/vault.md
public enum Aegis {
    static func root(_ data: Data) -> JSONValue? {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data),
              root["header"]?.isObject == true, root["db"] != nil
        else { return nil }
        return root
    }

    public static func isVault(_ data: Data) -> Bool { root(data) != nil }

    public static func isEncrypted(_ data: Data) -> Bool {
        root(data)?["db"]?.string != nil
    }

    public static func decode(_ data: Data, password: String? = nil) throws -> TwoFAS.Backup {
        guard let root = root(data) else { throw ImportError.invalidFile }
        let db: JSONValue
        if let sealed = root["db"]?.string {
            guard let password, !password.isEmpty else { throw ImportError.passwordRequired }
            db = try decrypt(db: sealed, header: root["header"]!, password: password)
        } else {
            db = root["db"]!
        }
        return try parse(db: db)
    }

    // MARK: Decryption

    /// scrypt(password) unwraps the master key from a password slot; the master key opens `db`.
    static func decrypt(db sealed: String, header: JSONValue, password: String) throws -> JSONValue {
        let slots = header["slots"]?.array ?? []
        let passwordSlots = slots.filter { $0["type"]?.int == 1 }
        guard !passwordSlots.isEmpty else {
            throw ImportError.unsupported(String(localized: "This Aegis vault has no password slot. Export it again with a password."))
        }

        var masterKey: SymmetricKey?
        for slot in passwordSlots {
            guard let salt = slot["salt"]?.string.flatMap(CryptoUtil.hex),
                  let wrapped = slot["key"]?.string.flatMap(CryptoUtil.hex),
                  let n = slot["n"]?.int, let r = slot["r"]?.int, let p = slot["p"]?.int,
                  let derived = CryptoUtil.scrypt(password: Array(password.utf8), salt: Array(salt), n: n, r: r, p: p, length: 32),
                  let key = try? open(wrapped, params: slot["key_params"], key: SymmetricKey(data: derived))
            else { continue }
            masterKey = SymmetricKey(data: key)
            break
        }
        guard let masterKey else { throw ImportError.wrongPassword }

        guard let cipher = Data(base64Encoded: sealed),
              let plain = try? open(cipher, params: header["params"], key: masterKey),
              let db = try? JSONDecoder().decode(JSONValue.self, from: plain)
        else { throw ImportError.invalidFile }
        return db
    }

    /// AES-256-GCM with hex `nonce` and `tag` kept separately from the ciphertext.
    private static func open(_ cipher: Data, params: JSONValue?, key: SymmetricKey) throws -> Data {
        guard let nonce = params?["nonce"]?.string.flatMap(CryptoUtil.hex),
              let tag = params?["tag"]?.string.flatMap(CryptoUtil.hex)
        else { throw ImportError.invalidFile }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: cipher, tag: tag)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: Export

    /// Builds an Aegis vault (db version 3). With a password it is encrypted like Aegis does it:
    /// a random master key encrypts the db, and scrypt(password) wraps the master key in a password slot.
    public static func encode(_ backup: TwoFAS.Backup, password: String? = nil) throws -> Data {
        // Aegis requires UUIDs for groups; 2FAS group ids can be anything.
        var groupIds: [String: String] = [:]
        for g in backup.groups {
            groupIds[g.id] = UUID(uuidString: g.id) != nil ? g.id.lowercased() : UUID().uuidString.lowercased()
        }

        let entries: [JSONValue] = backup.tokens.map { t in
            var info: [String: JSONValue] = [
                "secret": .string(t.secret),
                "algo": .string(t.kind == .steam ? "SHA1" : t.algorithm.rawValue),
                "digits": .number(Double(t.kind == .steam ? 5 : t.digits)),
            ]
            if t.kind == .hotp {
                info["counter"] = .number(Double(t.counter))
            } else {
                info["period"] = .number(Double(t.kind == .steam ? 30 : t.period))
            }
            let icon = t.icon
            return .object([
                "type": .string(t.kind.rawValue.lowercased()),
                "uuid": .string(t.id.uuidString.lowercased()),
                "name": .string(t.account ?? ""),
                "issuer": .string(t.issuer ?? t.name),
                "note": .string(""),
                "favorite": .bool(false),
                "icon": icon.map { .string($0.base64EncodedString()) } ?? .null,
                "icon_mime": icon == nil ? .null : .string("image/png"),
                "icon_hash": icon.map { .string(SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()) } ?? .null,
                "info": .object(info),
                "groups": .array(t.groupId.flatMap { groupIds[$0] }.map { [.string($0)] } ?? []),
            ])
        }
        let db = JSONValue.object([
            "version": .number(3),
            "entries": .array(entries),
            "groups": .array(backup.groups.map { .object(["uuid": .string(groupIds[$0.id]!), "name": .string($0.name)]) }),
        ])

        var root: [String: JSONValue] = ["version": .number(1)]
        if let password, !password.isEmpty {
            let (header, sealed) = try encrypt(db: JSONEncoder().encode(db), password: password)
            root["header"] = header
            root["db"] = .string(sealed)
        } else {
            root["header"] = .object(["slots": .null, "params": .null])
            root["db"] = db
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(JSONValue.object(root))
    }

    static func encrypt(db: Data, password: String) throws -> (header: JSONValue, db: String) {
        let (n, r, p) = (32768, 8, 1)
        let masterKey = SymmetricKey(size: .bits256)
        let salt = TwoFAS.randomBytes(32)
        guard let derived = CryptoUtil.scrypt(password: Array(password.utf8), salt: Array(salt), n: n, r: r, p: p, length: 32)
        else { throw ImportError.invalidFile }

        let hex = { (d: Data) in d.map { String(format: "%02x", $0) }.joined() }
        let wrapped = try AES.GCM.seal(masterKey.withUnsafeBytes { Data($0) }, using: SymmetricKey(data: derived))
        let sealed = try AES.GCM.seal(db, using: masterKey)

        let slot = JSONValue.object([
            "type": .number(1),
            "uuid": .string(UUID().uuidString.lowercased()),
            "key": .string(hex(wrapped.ciphertext)),
            "key_params": .object(["nonce": .string(hex(Data(wrapped.nonce))), "tag": .string(hex(wrapped.tag))]),
            "n": .number(Double(n)), "r": .number(Double(r)), "p": .number(Double(p)),
            "salt": .string(hex(salt)),
            "repaired": .bool(true),
            "is_backup": .bool(false),
        ])
        let header = JSONValue.object([
            "slots": .array([slot]),
            "params": .object(["nonce": .string(hex(Data(sealed.nonce))), "tag": .string(hex(sealed.tag))]),
        ])
        return (header, sealed.ciphertext.base64EncodedString())
    }

    // MARK: Entries

    static func parse(db: JSONValue) throws -> TwoFAS.Backup {
        guard let entries = db["entries"]?.array else { throw ImportError.invalidFile }

        // Version 3 has a groups table; version 2 stored one group name per entry.
        var groups: [TokenGroup] = (db["groups"]?.array ?? []).compactMap { g in
            guard let id = g["uuid"]?.string, let name = g["name"]?.string else { return nil }
            return TokenGroup(id: id, name: name)
        }
        func groupId(forName name: String) -> String {
            if let g = groups.first(where: { $0.name == name }) { return g.id }
            let g = TokenGroup(name: name)
            groups.append(g)
            return g.id
        }

        var tokens: [Token] = []
        var skipped: [String] = []
        for e in entries {
            let issuer = e["issuer"]?.string ?? ""
            let account = e["name"]?.string ?? ""
            let label = [issuer, account].filter { !$0.isEmpty }.joined(separator: ": ")
            let info = e["info"]

            let kind: OTPKind
            switch e["type"]?.string?.lowercased() {
            case "totp": kind = .totp
            case "hotp": kind = .hotp
            case "steam": kind = .steam
            case let other:
                skipped.append(String(localized: "\(label.isEmpty ? "Unnamed" : label) (\(other ?? "unknown") is not supported)"))
                continue
            }
            guard let secret = info?["secret"]?.string, Base32.decode(secret).map({ !$0.isEmpty }) == true else {
                skipped.append(String(localized: "\(label.isEmpty ? "Unnamed" : label) (invalid secret)"))
                continue
            }

            var group: String?
            if let ids = e["groups"]?.array?.compactMap(\.string), let first = ids.first(where: { id in groups.contains { $0.id == id } }) {
                group = first
            } else if let name = e["group"]?.string, !name.isEmpty {
                group = groupId(forName: name)
            }

            tokens.append(Token(
                name: issuer.isEmpty ? (account.isEmpty ? "Unnamed" : account) : issuer,
                issuer: issuer.isEmpty ? nil : issuer,
                account: account.isEmpty ? nil : account,
                secret: secret,
                kind: kind,
                algorithm: info?["algo"]?.string.flatMap(OTPAlgorithm.init(lenient:)) ?? .sha1,
                digits: info?["digits"]?.int ?? 6,
                period: info?["period"]?.int ?? 30,
                counter: UInt64(max(0, info?["counter"]?.int ?? 0)),
                // Raw icon bytes (JPEG/PNG/SVG); the app re-encodes them as PNG.
                icon: e["icon"]?.string.flatMap { Data(base64Encoded: $0) },
                groupId: group
            ))
        }
        return TwoFAS.Backup(tokens: tokens, groups: groups, skipped: skipped)
    }
}
