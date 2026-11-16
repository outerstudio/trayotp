import CommonCrypto
import CryptoKit
import Foundation

/// Import/export of 2FAS backup files (`.2fas`, schema version 4).
///
/// Encrypted backups replace `services` with `servicesEncrypted` = "cipher:salt:iv"
/// (each Base64; cipher includes the 16-byte GCM tag at the end).
/// Key = PBKDF2-HMAC-SHA256(password, salt, 10 000 iterations, 32 bytes), cipher = AES-256-GCM.
/// `reference` is a fixed string encrypted the same way (same salt, new IV) and is
/// used to check the password before decrypting the services.
public enum TwoFAS {
    public typealias Error = ImportError

    public struct Backup: Sendable {
        public var tokens: [Token]
        public var groups: [TokenGroup]
        /// Entries that could not be imported, e.g. "Yandex: Work (unsupported type)".
        public var skipped: [String]

        public init(tokens: [Token], groups: [TokenGroup] = [], skipped: [String] = []) {
            self.tokens = tokens
            self.groups = groups
            self.skipped = skipped
        }
    }

    public static let schemaVersion = 4
    static let iterations: UInt32 = 10_000
    static let saltLength = 256
    static let ivLength = 12

    /// Plaintext 2FAS encrypts into `reference`.
    /// Source: twofas/2fas-android BackupContent.kt (`Reference`).
    static let reference =
        "tRViSsLKzd86Hprh4ceC2OP7xazn4rrt4xhfEUbOjxLX8Rc3mkISXE0lWbmnWfggogbBJhtYgpK6fMl1D6m"
        + "tsy92R3HkdGfwuXbzLebqVFJsR7IZ2w58t938iymwG4824igYy1wi6n2WDpO1Q1P69zwJGs2F5a1qP4MyIiDSD7NCV2OvidXQCBnDlGfmz0f1BQySRkkt4ryiJeCjD2o4QsveJ9uDBUn8ELyOrESv5R5DMDkD4iAF8TXU7KyoJujd"

    // MARK: - Import

    public static func isEncrypted(_ data: Data) -> Bool {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return false }
        return !(root["servicesEncrypted"]?.string ?? "").isEmpty
    }

    public static func decode(_ data: Data, password: String? = nil) throws -> Backup {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data), root.isObject else {
            throw Error.invalidFile
        }

        let services: [JSONValue]
        if let encrypted = root["servicesEncrypted"]?.string, !encrypted.isEmpty {
            guard let password, !password.isEmpty else { throw Error.passwordRequired }
            let (_, salt, _) = try split(encrypted)
            let key = deriveKey(password: password, salt: salt)

            if let ref = root["reference"]?.string, !ref.isEmpty {
                guard (try? open(ref, key: key)) != nil else { throw Error.wrongPassword }
            }
            guard let plain = try? open(encrypted, key: key) else { throw Error.wrongPassword }
            guard let list = try? JSONDecoder().decode(JSONValue.self, from: plain).array else {
                throw Error.invalidFile
            }
            services = list
        } else {
            services = root["services"]?.array ?? []
        }

        let sorted = services.enumerated().sorted { a, b in
            (a.element["order"]?["position"]?.int ?? a.offset) < (b.element["order"]?["position"]?.int ?? b.offset)
        }
        let tokens = sorted.compactMap { token(from: $0.element) }
        let groups = Self.groups(from: root["groups"] ?? .array([]))
        // Drop references to groups the file doesn't define.
        let known = Set(groups.map(\.id))
        let cleaned = tokens.map { t -> Token in
            var t = t
            if let id = t.groupId, !known.contains(id) { t.groupId = nil }
            return t
        }
        return Backup(tokens: cleaned, groups: groups)
    }

    /// Parses a 2FAS `groups` array. Also used to migrate vaults that stored the raw JSON.
    public static func groups(from json: JSONValue) -> [TokenGroup] {
        (json.array ?? []).compactMap { g in
            guard let id = g["id"]?.string, !id.isEmpty else { return nil }
            return TokenGroup(id: id, name: g["name"]?.string ?? "Group", isExpanded: g["isExpanded"]?.bool ?? true)
        }
    }

    /// Decrypts the `reference` field. Used by tests to check the constant against a real 2FAS file.
    public static func decryptReference(_ data: Data, password: String) throws -> String {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data),
              let ref = root["reference"]?.string
        else { throw Error.invalidFile }
        let (_, salt, _) = try split(ref)
        guard let plain = try? open(ref, key: deriveKey(password: password, salt: salt)) else { throw Error.wrongPassword }
        return String(decoding: plain, as: UTF8.self)
    }

    public static var referencePlaintext: String { reference }

    static func token(from service: JSONValue) -> Token? {
        guard let secret = service["secret"]?.string, !secret.isEmpty else { return nil }
        let otp = service["otp"]
        let kind = otp?["tokenType"]?.string.flatMap { OTPKind(rawValue: $0.uppercased()) } ?? .totp
        let counter = otp?["counter"]?.int ?? 0
        return Token(
            name: service["name"]?.string ?? otp?["issuer"]?.string ?? "Unnamed",
            issuer: nonEmpty(otp?["issuer"]?.string),
            account: nonEmpty(otp?["account"]?.string),
            secret: secret,
            kind: kind,
            algorithm: otp?["algorithm"]?.string.flatMap(OTPAlgorithm.init(lenient:)) ?? .sha1,
            digits: otp?["digits"]?.int ?? 6,
            period: otp?["period"]?.int ?? 30,
            counter: UInt64(max(0, counter)),
            color: service["badge"]?["color"]?.string,
            extra: service,
            groupId: service["groupId"]?.string
        )
    }

    // MARK: - Export

    public static func encode(_ backup: Backup, password: String? = nil, now: Date = Date()) throws -> Data {
        let millis = JSONValue.number((now.timeIntervalSince1970 * 1000).rounded())
        let services = JSONValue.array(backup.tokens.enumerated().map { service(from: $0.element, position: $0.offset, now: millis) })

        var root: [String: JSONValue] = [
            "services": .array([]),
            "groups": .array(backup.groups.map { g in
                .object([
                    "id": .string(g.id),
                    "name": .string(g.name),
                    "isExpanded": .bool(g.isExpanded),
                    "updatedAt": millis,
                ])
            }),
            "updatedAt": millis,
            "schemaVersion": .number(Double(schemaVersion)),
            "appVersionCode": .number(1),
            "appVersionName": .string("1.0"),
            "appOrigin": .string("trayotp"),
        ]

        if let password, !password.isEmpty {
            let salt = randomBytes(saltLength)
            let key = deriveKey(password: password, salt: salt)
            let plain = try JSONEncoder().encode(services)
            root["servicesEncrypted"] = .string(try seal(plain, key: key, salt: salt))
            root["reference"] = .string(try seal(Data(reference.utf8), key: key, salt: salt))
        } else {
            root["services"] = services
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(JSONValue.object(root))
    }

    /// Builds a 2FAS service object, starting from the original one when we have it.
    static func service(from token: Token, position: Int, now: JSONValue) -> JSONValue {
        var s: JSONValue = (token.extra?.isObject ?? false) ? token.extra! : .object([:])
        var otp: JSONValue = (s["otp"]?.isObject ?? false) ? s["otp"]! : .object([:])

        let account = token.account ?? ""
        otp["issuer"] = token.issuer.map(JSONValue.string) ?? .string(token.name)
        otp["account"] = .string(account)
        otp["label"] = .string(account.isEmpty ? token.name : "\(token.issuer ?? token.name):\(account)")
        otp["digits"] = .number(Double(token.digits))
        otp["period"] = .number(Double(token.period))
        otp["algorithm"] = .string(token.algorithm.rawValue)
        otp["tokenType"] = .string(token.kind.rawValue)
        otp["counter"] = .number(Double(token.counter))
        if otp["source"] == nil { otp["source"] = .string("Manual") }

        s["name"] = .string(token.name)
        s["secret"] = .string(token.secret)
        s["otp"] = otp
        s["order"] = .object(["position": .number(Double(position))])
        s["updatedAt"] = now
        if let color = token.color { s["badge"] = .object(["color": .string(color)]) }
        s["groupId"] = token.groupId.map(JSONValue.string) ?? .null
        // 2FAS declares these nullable without defaults, so always write them.
        for key in ["badge", "icon", "serviceTypeID"] where s[key] == nil { s[key] = .null }
        return s
    }

    // MARK: - Crypto

    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let pw = Array(password.utf8)
        var out = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltPtr in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, pw.count,
                saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &out, out.count
            )
        }
        precondition(status == kCCSuccess, "PBKDF2 failed")
        return SymmetricKey(data: out)
    }

    static func split(_ field: String) throws -> (cipher: Data, salt: Data, iv: Data) {
        let parts = field.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let cipher = Data(base64Encoded: String(parts[0])),
              let salt = Data(base64Encoded: String(parts[1])),
              let iv = Data(base64Encoded: String(parts[2])),
              cipher.count > 16
        else { throw Error.invalidFile }
        return (cipher, salt, iv)
    }

    static func open(_ field: String, key: SymmetricKey) throws -> Data {
        let (cipher, _, iv) = try split(field)
        let box = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: iv),
            ciphertext: cipher.dropLast(16),
            tag: cipher.suffix(16)
        )
        return try AES.GCM.open(box, using: key)
    }

    static func seal(_ plain: Data, key: SymmetricKey, salt: Data) throws -> String {
        let iv = randomBytes(ivLength)
        let box = try AES.GCM.seal(plain, using: key, nonce: AES.GCM.Nonce(data: iv))
        let cipher = box.ciphertext + box.tag
        return [cipher, salt, iv].map { $0.base64EncodedString() }.joined(separator: ":")
    }

    static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return Data(bytes)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}
