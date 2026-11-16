import Foundation

public enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    /// Accepts "SHA1", "sha-1", "HmacSHA1" and similar spellings.
    public init?(lenient raw: String) {
        let s = raw.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "HMAC", with: "")
        self.init(rawValue: s)
    }
}

public enum OTPKind: String, Codable, CaseIterable, Sendable {
    case totp = "TOTP"
    case hotp = "HOTP"
    case steam = "STEAM"
}

public struct Token: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// Display name, e.g. "GitHub". Maps to 2FAS `name`.
    public var name: String
    public var issuer: String?
    public var account: String?
    /// Normalized Base32 secret.
    public var secret: String
    public var kind: OTPKind
    public var algorithm: OTPAlgorithm
    public var digits: Int
    public var period: Int
    public var counter: UInt64
    /// 2FAS badge color name ("Default", "Red", "LightBlue"...).
    public var color: String?
    /// The original 2FAS service object, kept for lossless export.
    public var extra: JSONValue?
    /// User-chosen icon as PNG data. Not part of 2FAS backups.
    public var icon: Data?
    /// The `TokenGroup.id` this token belongs to; nil = ungrouped.
    public var groupId: String?

    public init(
        id: UUID = UUID(),
        name: String,
        issuer: String? = nil,
        account: String? = nil,
        secret: String,
        kind: OTPKind = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0,
        color: String? = nil,
        extra: JSONValue? = nil,
        icon: Data? = nil,
        groupId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.account = account
        self.secret = Base32.normalize(secret)
        self.kind = kind
        self.algorithm = algorithm
        self.digits = kind == .steam ? 5 : digits
        self.period = period > 0 ? period : 30
        self.counter = counter
        self.color = color
        self.extra = extra
        self.icon = icon
        self.groupId = groupId
    }

    public var isValid: Bool {
        Base32.decode(secret).map { !$0.isEmpty } ?? false && (5...10).contains(digits)
    }

    /// The current code, or nil if the secret is not valid Base32.
    public func code(at date: Date = Date()) -> String? {
        guard let key = Base32.decode(secret), !key.isEmpty else { return nil }
        switch kind {
        case .hotp:
            return OTP.hotp(key: key, counter: counter, digits: digits, algorithm: algorithm)
        case .totp:
            return OTP.hotp(key: key, counter: timeStep(at: date), digits: digits, algorithm: algorithm)
        case .steam:
            return OTP.steam(key: key, counter: timeStep(at: date), algorithm: algorithm)
        }
    }

    /// Seconds left before the code changes (TOTP/Steam only).
    public func secondsRemaining(at date: Date = Date()) -> Int {
        let t = Int(date.timeIntervalSince1970)
        return period - (t % period)
    }

    func timeStep(at date: Date) -> UInt64 {
        UInt64(max(0, date.timeIntervalSince1970)) / UInt64(period)
    }

    /// Text shown under the name: account if present, else issuer.
    public var subtitle: String? {
        if let account, !account.isEmpty { return account }
        if let issuer, !issuer.isEmpty, issuer != name { return issuer }
        return nil
    }
}

extension String {
    /// "123456" → "123 456", "12345678" → "1234 5678".
    public var otpGrouped: String {
        guard count >= 6 else { return self }
        let mid = index(startIndex, offsetBy: count / 2)
        return "\(self[..<mid]) \(self[mid...])"
    }
}
