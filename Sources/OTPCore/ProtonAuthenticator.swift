import CryptoKit
import Foundation

/// Import of Proton Authenticator exports.
///
/// Plain: `{"version": 1, "entries": [{"content": {"uri": "otpauth://…", "entry_type": "Totp", "name": "…"}}]}`.
/// Encrypted: `{"version": 1, "salt": <Base64>, "content": <Base64 nonce (12) ‖ ciphertext ‖ tag (16)>}`.
/// Key = Argon2id(password, salt, t=2, m=19 MiB, p=1, 32 bytes); cipher = AES-256-GCM with the
/// associated data "proton.authenticator.export.v1".
public enum ProtonAuthenticator {
    static let aad = Data("proton.authenticator.export.v1".utf8)

    static func root(_ data: Data) -> JSONValue? {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data), root["version"] != nil else { return nil }
        if root["salt"]?.string != nil, root["content"]?.string != nil { return root }
        if let entries = root["entries"]?.array, entries.allSatisfy({ $0["content"]?["uri"] != nil }) { return root }
        return nil
    }

    public static func isExport(_ data: Data) -> Bool { root(data) != nil }

    public static func isEncrypted(_ data: Data) -> Bool { root(data)?["salt"]?.string != nil }

    public static func decode(_ data: Data, password: String? = nil) throws -> TwoFAS.Backup {
        guard var root = root(data) else { throw ImportError.invalidFile }
        if let salt = root["salt"]?.string, let content = root["content"]?.string {
            guard let password, !password.isEmpty else { throw ImportError.passwordRequired }
            guard root["version"]?.int == 1 else {
                throw ImportError.unsupported("This Proton Authenticator export uses a newer format that TrayOTP can't read yet.")
            }
            guard let salt = Data(base64Encoded: salt), let content = Data(base64Encoded: content) else {
                throw ImportError.invalidFile
            }
            guard let key = Argon2.id(password: Array(password.utf8), salt: Array(salt), iterations: 2,
                                      memoryKiB: 19 * 1024, parallelism: 1, length: 32),
                  let box = try? AES.GCM.SealedBox(combined: content),
                  let plain = try? AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
            else { throw ImportError.wrongPassword }
            guard let inner = try? JSONDecoder().decode(JSONValue.self, from: plain) else { throw ImportError.invalidFile }
            root = inner
        }

        var tokens: [Token] = []
        var skipped: [String] = []
        for entry in root["entries"]?.array ?? [] {
            let content = entry["content"]
            let name = content?["name"]?.string ?? ""
            guard let uri = content?["uri"]?.string else { continue }
            do {
                var token = try OTPField.parse(uri, name: nil)
                if token.account == nil, !name.isEmpty { token.account = name }
                tokens.append(token)
            } catch {
                skipped.append("\(name.isEmpty ? "Unnamed" : name) (\(error.localizedDescription))")
            }
        }
        return TwoFAS.Backup(tokens: tokens, skipped: skipped)
    }
}
