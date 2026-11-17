import Foundation

/// Import of Google Authenticator's "Transfer accounts" QR codes: `otpauth-migration://offline?data=<Base64>`,
/// where `data` is a MigrationPayload protobuf. Large exports are split over several QR codes; each one is a
/// complete link, so they can be imported one at a time or together (one link per line).
/// Schema: https://github.com/beemdevelopment/Aegis/blob/master/app/src/main/proto/google_auth.proto
public enum GoogleAuthenticator {
    static let scheme = "otpauth-migration://"

    public static func isMigrationLink(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix(scheme)
    }

    static func links(in data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(isMigrationLink)
    }

    public static func isExport(_ data: Data) -> Bool { !links(in: data).isEmpty }

    public static func decode(_ data: Data) throws -> TwoFAS.Backup {
        let links = links(in: data)
        guard !links.isEmpty else { throw ImportError.invalidFile }
        var tokens: [Token] = []
        var skipped: [String] = []
        for link in links {
            let part = try decode(link: link)
            tokens += part.tokens
            skipped += part.skipped
        }
        return TwoFAS.Backup(tokens: tokens, skipped: skipped)
    }

    static func decode(link: String) throws -> TwoFAS.Backup {
        guard let comps = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
              comps.host?.lowercased() == "offline",
              var base64 = comps.percentEncodedQueryItems?.first(where: { $0.name == "data" })?.value
        else { throw ImportError.invalidFile }
        // Percent-decode, but keep "+" (a Base64 digit) even if a scanner left it unescaped.
        base64 = (base64.removingPercentEncoding ?? base64).replacingOccurrences(of: " ", with: "+")
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let payload = Data(base64Encoded: base64), let fields = try? Protobuf.fields(payload) else {
            throw ImportError.unsupported("This Google Authenticator transfer code is damaged. Scan or copy it again.")
        }

        var tokens: [Token] = []
        var skipped: [String] = []
        for case .bytes(let otp) in fields.filter({ $0.number == 1 }).map(\.value) {
            guard let params = try? Protobuf.fields(otp) else { continue }
            func bytes(_ n: Int) -> Data? {
                for f in params where f.number == n { if case .bytes(let d) = f.value { return d } }
                return nil
            }
            func int(_ n: Int) -> UInt64 {
                for f in params where f.number == n { if case .varint(let v) = f.value { return v } }
                return 0
            }
            let secret = bytes(1) ?? Data()
            var name = bytes(2).map { String(decoding: $0, as: UTF8.self) } ?? ""
            var issuer = bytes(3).map { String(decoding: $0, as: UTF8.self) } ?? ""
            if issuer.isEmpty, let colon = name.firstIndex(of: ":") {
                issuer = String(name[..<colon])
                name = String(name[name.index(after: colon)...])
            }
            let label = Token.label(issuer: issuer, account: name)

            let algorithm: OTPAlgorithm
            switch int(4) {
            case 0, 1: algorithm = .sha1
            case 2: algorithm = .sha256
            case 3: algorithm = .sha512
            default:
                skipped.append("\(label) (MD5 is not supported)")
                continue
            }
            let kind: OTPKind
            switch int(6) {
            case 0, 2: kind = .totp
            case 1: kind = .hotp
            case let other:
                skipped.append("\(label) (OTP type \(other) is not supported)")
                continue
            }
            guard !secret.isEmpty else {
                skipped.append("\(label) (empty secret)")
                continue
            }
            tokens.append(.imported(issuer: issuer, account: name.trimmingCharacters(in: .whitespaces),
                                    secret: Base32.encode(secret), kind: kind, algorithm: algorithm,
                                    digits: int(5) == 2 ? 8 : 6, counter: int(7)))
        }
        return TwoFAS.Backup(tokens: tokens, skipped: skipped)
    }
}

/// Just enough protobuf to read Google's MigrationPayload: varints and length-delimited fields.
enum Protobuf {
    enum Value {
        case varint(UInt64)
        case bytes(Data)
        case fixed
    }

    struct Field {
        let number: Int
        let value: Value
    }

    struct Malformed: Error {}

    static func fields(_ data: Data) throws -> [Field] {
        let bytes = [UInt8](data)
        var i = 0
        func varint() throws -> UInt64 {
            var result: UInt64 = 0
            var shift: UInt64 = 0
            while true {
                guard i < bytes.count, shift < 64 else { throw Malformed() }
                let b = bytes[i]
                i += 1
                result |= UInt64(b & 0x7F) << shift
                if b & 0x80 == 0 { return result }
                shift += 7
            }
        }
        var out: [Field] = []
        while i < bytes.count {
            let key = try varint()
            let number = Int(key >> 3)
            switch key & 7 {
            case 0: out.append(Field(number: number, value: .varint(try varint())))
            case 1: i += 8; out.append(Field(number: number, value: .fixed))
            case 2:
                let length = Int(try varint())
                guard length >= 0, i + length <= bytes.count else { throw Malformed() }
                out.append(Field(number: number, value: .bytes(Data(bytes[i..<(i + length)]))))
                i += length
            case 5: i += 4; out.append(Field(number: number, value: .fixed))
            default: throw Malformed()
            }
            guard i <= bytes.count else { throw Malformed() }
        }
        return out
    }
}
