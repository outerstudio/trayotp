import Foundation

/// Import of Raivo OTP exports: a password-protected ZIP (WinZip AES) holding `raivo-otp-export.json`,
/// or that JSON file on its own: `[{"issuer", "account", "secret", "algorithm", "digits", "kind", "timer", "counter"}]`
/// with every value written as a string.
public enum Raivo {
    static let fileName = "raivo-otp-export.json"

    static func entries(_ data: Data) -> [JSONValue]? {
        guard let array = (try? JSONDecoder().decode(JSONValue.self, from: data))?.array,
              array.allSatisfy({ $0["secret"] != nil && $0["kind"] != nil })
        else { return nil }
        return array
    }

    static func zipEntry(_ data: Data) -> Zip.Entry? {
        guard Zip.isZip(data) else { return nil }
        return (try? Zip.entries(data))?.first { $0.name == fileName || $0.name.hasSuffix("/" + fileName) }
    }

    public static func isExport(_ data: Data) -> Bool { zipEntry(data) != nil || entries(data) != nil }

    public static func isEncrypted(_ data: Data) -> Bool { zipEntry(data).map(Zip.isEncrypted) ?? false }

    public static func decode(_ data: Data, password: String? = nil) throws -> TwoFAS.Backup {
        if let entries = entries(data) { return parse(entries) }
        guard let entry = zipEntry(data) else { throw ImportError.invalidFile }
        if Zip.isEncrypted(entry), password?.isEmpty ?? true { throw ImportError.passwordRequired }
        let json: Data
        do {
            json = try Zip.extract(entry, from: data, password: password)
        } catch Zip.Error.wrongPassword {
            throw ImportError.wrongPassword
        } catch Zip.Error.unsupported {
            throw ImportError.unsupported(String(localized: "This ZIP uses an encryption or compression method TrayOTP can't read. Unzip it with another tool, then import raivo-otp-export.json."))
        } catch {
            throw ImportError.invalidFile
        }
        guard let entries = entries(json) else { throw ImportError.invalidFile }
        return parse(entries)
    }

    static func parse(_ entries: [JSONValue]) -> TwoFAS.Backup {
        var tokens: [Token] = []
        var skipped: [String] = []
        for e in entries {
            let issuer = e["issuer"]?.string ?? ""
            let account = e["account"]?.string ?? ""
            let label = Token.label(issuer: issuer, account: account)
            let kind: OTPKind
            switch e["kind"]?.string?.uppercased() {
            case "TOTP": kind = .totp
            case "HOTP": kind = .hotp
            case let other:
                skipped.append(String(localized: "\(label) (\(other ?? "unknown") is not supported)"))
                continue
            }
            guard let secret = e["secret"]?.string, Base32.decode(secret).map({ !$0.isEmpty }) == true else {
                skipped.append(String(localized: "\(label) (invalid secret)"))
                continue
            }
            tokens.append(.imported(
                issuer: issuer, account: account, secret: secret, kind: kind,
                algorithm: e["algorithm"]?.string.flatMap(OTPAlgorithm.init(lenient:)) ?? .sha1,
                digits: e["digits"]?.int ?? 6, period: e["timer"]?.int ?? 30,
                counter: UInt64(max(0, e["counter"]?.int ?? 0))))
        }
        return TwoFAS.Backup(tokens: tokens, skipped: skipped)
    }
}
