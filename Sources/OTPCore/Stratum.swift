import CryptoKit
import Foundation

/// Import of Stratum (formerly Authenticator Pro) backups.
///
/// Plain: JSON with `Authenticators`, `Categories` and `AuthenticatorCategories` (category ↔ secret links).
/// Encrypted: "AUTHENTICATORPRO" ‖ salt (16) ‖ IV (12) ‖ ciphertext ‖ tag (16);
/// key = Argon2id(password, salt, t=3, m=64 MiB, p=4, 32 bytes), cipher = AES-256-GCM.
/// Legacy encrypted: "AuthenticatorPro" ‖ salt (20) ‖ IV (16) ‖ ciphertext;
/// key = PBKDF2-HMAC-SHA1(password, salt, 64 000 iterations, 32 bytes), cipher = AES-256-CBC.
public enum Stratum {
    static let header = Data("AUTHENTICATORPRO".utf8)
    static let legacyHeader = Data("AuthenticatorPro".utf8)

    static func root(_ data: Data) -> JSONValue? {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data), root["Authenticators"]?.array != nil
        else { return nil }
        return root
    }

    public static func isEncrypted(_ data: Data) -> Bool {
        data.starts(with: header) || data.starts(with: legacyHeader)
    }

    public static func isBackup(_ data: Data) -> Bool { isEncrypted(data) || root(data) != nil }

    public static func decode(_ data: Data, password: String? = nil) throws -> TwoFAS.Backup {
        if let root = root(data) { return parse(root) }
        guard isEncrypted(data) else { throw ImportError.invalidFile }
        guard let password, !password.isEmpty else { throw ImportError.passwordRequired }
        let bytes = [UInt8](data)
        let pw = Array(password.utf8)

        let plain: Data?
        if data.starts(with: header) {
            guard bytes.count > 16 + 16 + 12 + 16 else { throw ImportError.invalidFile }
            let salt = Array(bytes[16..<32]), iv = Data(bytes[32..<44]), body = Data(bytes[44...])
            guard let key = Argon2.id(password: pw, salt: salt, iterations: 3, memoryKiB: 1 << 16, parallelism: 4, length: 32),
                  let box = try? AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: body.dropLast(16), tag: body.suffix(16))
            else { throw ImportError.invalidFile }
            plain = try? AES.GCM.open(box, using: SymmetricKey(data: key))
        } else {
            guard bytes.count > 16 + 20 + 16 else { throw ImportError.invalidFile }
            let salt = Array(bytes[16..<36]), iv = Array(bytes[36..<52])
            let key = CryptoUtil.pbkdf2SHA1(password: pw, salt: salt, iterations: 64_000, length: 32)
            plain = CryptoUtil.aesCBCDecrypt(key: key, iv: iv, data: Array(bytes[52...])).map { Data($0) }
        }
        // CBC without a MAC: a wrong password usually fails the padding check, otherwise the JSON check.
        guard let plain, let root = root(plain) else { throw ImportError.wrongPassword }
        return parse(root)
    }

    static func parse(_ root: JSONValue) -> TwoFAS.Backup {
        let categories = (root["Categories"]?.array ?? [])
            .sorted { ($0["Ranking"]?.int ?? 0) < ($1["Ranking"]?.int ?? 0) }
            .compactMap { c -> TokenGroup? in
                guard let id = c["Id"]?.string, let name = c["Name"]?.string else { return nil }
                return TokenGroup(id: id, name: name)
            }
        var categoryOfSecret: [String: String] = [:]
        for link in root["AuthenticatorCategories"]?.array ?? [] {
            guard let secret = link["AuthenticatorSecret"]?.string, let id = link["CategoryId"]?.string,
                  categoryOfSecret[secret] == nil, categories.contains(where: { $0.id == id })
            else { continue }
            categoryOfSecret[secret] = id
        }

        let entries = (root["Authenticators"]?.array ?? []).enumerated()
            .sorted { ($0.element["Ranking"]?.int ?? 0, $0.offset) < ($1.element["Ranking"]?.int ?? 0, $1.offset) }
            .map(\.element)
        var tokens: [Token] = []
        var skipped: [String] = []
        for e in entries {
            let issuer = e["Issuer"]?.string ?? ""
            let account = e["Username"]?.string ?? ""
            let label = Token.label(issuer: issuer, account: account)
            let kind: OTPKind
            switch e["Type"]?.int {
            case 1: kind = .hotp
            case 2: kind = .totp
            case 4: kind = .steam
            case 3:
                skipped.append(String(localized: "\(label) (mOTP is not supported)"))
                continue
            case 5:
                skipped.append(String(localized: "\(label) (Yandex is not supported)"))
                continue
            case let other:
                skipped.append(String(localized: "\(label) (type \(other.map(String.init) ?? "unknown") is not supported)"))
                continue
            }
            guard let secret = e["Secret"]?.string, Base32.decode(secret).map({ !$0.isEmpty }) == true else {
                skipped.append(String(localized: "\(label) (invalid secret)"))
                continue
            }
            let algorithm: OTPAlgorithm = switch e["Algorithm"]?.int {
            case 1: .sha256
            case 2: .sha512
            default: .sha1
            }
            tokens.append(.imported(
                issuer: issuer, account: account, secret: secret, kind: kind, algorithm: algorithm,
                digits: e["Digits"]?.int ?? 6, period: e["Period"]?.int ?? 30,
                counter: UInt64(max(0, e["Counter"]?.int ?? 0)), groupId: categoryOfSecret[secret]))
        }
        return TwoFAS.Backup(tokens: tokens, groups: categories, skipped: skipped)
    }
}
