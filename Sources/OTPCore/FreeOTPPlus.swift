import Foundation

/// Import of FreeOTP+ JSON exports: `{"tokens": [...], "tokenOrder": ["Issuer:label", ...]}`.
/// Secrets are arrays of signed bytes. The original FreeOTP's encrypted backup format is not supported.
public enum FreeOTPPlus {
    static func root(_ data: Data) -> JSONValue? {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data),
              let tokens = root["tokens"]?.array,
              tokens.allSatisfy({ $0["secret"]?.array != nil })
        else { return nil }
        return root
    }

    public static func isExport(_ data: Data) -> Bool { root(data) != nil }

    public static func decode(_ data: Data) throws -> TwoFAS.Backup {
        guard let root = root(data), let entries = root["tokens"]?.array else { throw ImportError.invalidFile }
        let order = (root["tokenOrder"]?.array ?? []).compactMap(\.string)

        var keyed: [(key: String, token: Token)] = []
        var skipped: [String] = []
        for e in entries {
            let issuer = e["issuerExt"]?.string ?? e["issuerInt"]?.string ?? ""
            let account = e["label"]?.string ?? ""
            let label = Token.label(issuer: issuer, account: account)
            let bytes = (e["secret"]?.array ?? []).compactMap(\.int).map { UInt8(truncatingIfNeeded: $0) }
            guard !bytes.isEmpty else {
                skipped.append("\(label) (empty secret)")
                continue
            }
            let kind: OTPKind
            switch e["type"]?.string?.uppercased() {
            case "TOTP": kind = issuer == "Steam" ? .steam : .totp
            case "HOTP": kind = .hotp
            case let other:
                skipped.append("\(label) (\(other ?? "unknown") is not supported)")
                continue
            }
            let token = Token.imported(
                issuer: issuer, account: account, secret: Base32.encode(Data(bytes)), kind: kind,
                algorithm: e["algo"]?.string.flatMap(OTPAlgorithm.init(lenient:)) ?? .sha1,
                digits: e["digits"]?.int ?? 6, period: e["period"]?.int ?? 30,
                counter: UInt64(max(0, e["counter"]?.int ?? 0)))
            keyed.append((issuer.isEmpty ? account : "\(issuer):\(account)", token))
        }
        // Keep FreeOTP+'s manual order; tokens it doesn't list go last.
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let tokens = keyed.enumerated()
            .sorted { (rank[$0.element.key] ?? Int.max, $0.offset) < (rank[$1.element.key] ?? Int.max, $1.offset) }
            .map(\.element.token)
        return TwoFAS.Backup(tokens: tokens, skipped: skipped)
    }
}
