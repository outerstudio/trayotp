import Foundation

/// Builds groups by name while importing, reusing a group the file already named.
struct GroupCollector {
    private(set) var groups: [TokenGroup] = []

    mutating func id(for name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        if let g = groups.first(where: { $0.name == name }) { return g.id }
        let g = TokenGroup(name: name)
        groups.append(g)
        return g.id
    }
}

extension Token {
    /// A token from an app that stores issuer and account separately. Display name: issuer, else account.
    static func imported(issuer: String?, account: String?, secret: String, kind: OTPKind = .totp,
                         algorithm: OTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30, counter: UInt64 = 0,
                         groupId: String? = nil) -> Token {
        let issuer = issuer.flatMap { $0.isEmpty ? nil : $0 }
        let account = account.flatMap { $0.isEmpty ? nil : $0 }
        return Token(name: issuer ?? account ?? "Unnamed", issuer: issuer, account: account, secret: secret,
                     kind: kind, algorithm: algorithm, digits: digits, period: period, counter: counter, groupId: groupId)
    }

    /// "Issuer: account" for messages about entries that could not be imported.
    static func label(issuer: String?, account: String?) -> String {
        let label = [issuer, account].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
        return label.isEmpty ? "Unnamed" : label
    }
}

/// The OTP fields of password managers: an otpauth:// link, Bitwarden's steam://SECRET, or a bare Base32 secret.
enum OTPField {
    static func parse(_ raw: String, name: String?) throws -> Token {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.flatMap { $0.isEmpty ? nil : $0 }
        if value.lowercased().hasPrefix("steam://") {
            let secret = String(value.dropFirst("steam://".count))
            guard Base32.decode(secret).map({ !$0.isEmpty }) == true else { throw TokenInputError.invalidSecret }
            return Token(name: name ?? "Steam", issuer: "Steam", secret: secret, kind: .steam)
        }
        if value.lowercased().hasPrefix("otpauth://") {
            var token = try OTPAuthURI.parse(value)
            if token.issuer == nil, let name {
                token.issuer = name
                token.name = name
            }
            return token
        }
        return try TokenInput.parse(value, fallbackName: name ?? "")
    }
}

extension Data {
    var isUTF8Text: Bool { String(data: self, encoding: .utf8) != nil }

    func readUInt16LE(_ o: Int) -> Int { Int(self[startIndex + o]) | Int(self[startIndex + o + 1]) << 8 }
    func readUInt32LE(_ o: Int) -> Int { readUInt16LE(o) | readUInt16LE(o + 2) << 16 }
}
