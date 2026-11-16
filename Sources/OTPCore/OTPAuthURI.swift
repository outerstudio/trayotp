import Foundation

public enum TokenInputError: Error, Equatable, LocalizedError {
    case empty
    case notOTPAuth
    case missingSecret
    case invalidSecret
    case unsupportedType(String)

    public var errorDescription: String? {
        switch self {
        case .empty: return "Nothing to add."
        case .notOTPAuth: return "Not an otpauth:// link."
        case .missingSecret: return "The link has no secret."
        case .invalidSecret: return "The secret is not valid Base32."
        case .unsupportedType(let t): return "Unsupported OTP type “\(t)”."
        }
    }
}

/// Parses `otpauth://totp/Issuer:account?secret=...&issuer=...` links (Key URI Format).
public enum OTPAuthURI {
    public static func parse(_ string: String) throws -> Token {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              comps.scheme?.lowercased() == "otpauth",
              let host = comps.host?.lowercased()
        else { throw TokenInputError.notOTPAuth }

        let kind: OTPKind
        switch host {
        case "totp": kind = .totp
        case "hotp": kind = .hotp
        case "steam": kind = .steam
        default: throw TokenInputError.unsupportedType(host)
        }

        var query: [String: String] = [:]
        for item in comps.percentEncodedQueryItems ?? [] {
            // Form-style encoders (Ente, Aegis) write spaces as "+"; a real plus arrives as %2B.
            let value = (item.value ?? "").replacingOccurrences(of: "+", with: "%20")
            query[item.name.lowercased()] = value.removingPercentEncoding ?? value
        }

        guard let rawSecret = query["secret"], !rawSecret.isEmpty else { throw TokenInputError.missingSecret }
        guard let key = Base32.decode(rawSecret), !key.isEmpty else { throw TokenInputError.invalidSecret }

        // Label is "Issuer:account" or just "account". `comps.path` is already percent-decoded.
        var label = comps.path
        if label.hasPrefix("/") { label.removeFirst() }
        var labelIssuer: String?
        var account: String? = label.isEmpty ? nil : label
        if let colon = label.firstIndex(of: ":") {
            labelIssuer = String(label[..<colon]).trimmingCharacters(in: .whitespaces)
            account = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }

        let issuer = query["issuer"].flatMap { $0.isEmpty ? nil : $0 } ?? labelIssuer
        let name = issuer ?? account ?? "Unnamed"

        return Token(
            name: name,
            issuer: issuer,
            account: account,
            secret: rawSecret,
            kind: query["encoder"]?.lowercased() == "steam" ? .steam : kind,
            algorithm: query["algorithm"].flatMap(OTPAlgorithm.init(lenient:)) ?? .sha1,
            digits: query["digits"].flatMap(Int.init) ?? 6,
            period: query["period"].flatMap(Int.init) ?? 30,
            counter: query["counter"].flatMap(UInt64.init) ?? 0
        )
    }

    /// Builds an otpauth:// link. `steamHost` writes Steam tokens as otpauth://steam/ (Ente, Aegis)
    /// instead of otpauth://totp/...&encoder=steam. `extra` appends parameters such as Ente's codeDisplay.
    public static func make(_ token: Token, steamHost: Bool = false, extra: [(String, String)] = []) -> String {
        var comps = URLComponents()
        comps.scheme = "otpauth"
        switch token.kind {
        case .hotp: comps.host = "hotp"
        case .steam: comps.host = steamHost ? "steam" : "totp"
        case .totp: comps.host = "totp"
        }
        let account = token.account ?? token.name
        comps.path = "/" + (token.issuer.map { "\($0):\(account)" } ?? account)
        var items = [
            ("secret", token.secret),
            ("algorithm", token.algorithm.rawValue),
            ("digits", String(token.digits)),
        ]
        if let issuer = token.issuer { items.append(("issuer", issuer)) }
        if token.kind == .hotp {
            items.append(("counter", String(token.counter)))
        } else {
            items.append(("period", String(token.period)))
        }
        if token.kind == .steam && !steamHost { items.append(("encoder", "steam")) }
        items += extra

        // Encode "+", "&", "=" and "#" too: readers treat "+" as a space.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        comps.percentEncodedQueryItems = items.map {
            URLQueryItem(name: $0.0, value: $0.1.addingPercentEncoding(withAllowedCharacters: allowed))
        }
        return comps.string ?? ""
    }
}

/// What the user pasted: an otpauth:// link or a bare Base32 secret.
public enum TokenInput {
    public static func parse(_ text: String, fallbackName: String = "") throws -> Token {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TokenInputError.empty }
        if trimmed.lowercased().hasPrefix("otpauth://") {
            return try OTPAuthURI.parse(trimmed)
        }
        guard let key = Base32.decode(trimmed), !key.isEmpty else { throw TokenInputError.invalidSecret }
        let name = fallbackName.trimmingCharacters(in: .whitespaces)
        return Token(name: name.isEmpty ? "Unnamed" : name, issuer: name.isEmpty ? nil : name, secret: trimmed)
    }
}
