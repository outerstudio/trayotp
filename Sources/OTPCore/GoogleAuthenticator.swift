import Foundation

/// Import and export of Google Authenticator's "Transfer accounts" QR codes: `otpauth-migration://offline?data=<Base64>`,
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
            throw ImportError.unsupported(String(localized: "This Google Authenticator transfer code is damaged. Scan or copy it again."))
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
                skipped.append(String(localized: "\(label) (MD5 is not supported)"))
                continue
            }
            let kind: OTPKind
            switch int(6) {
            case 0, 2: kind = .totp
            case 1: kind = .hotp
            case let other:
                skipped.append(String(localized: "\(label) (OTP type \(other) is not supported)"))
                continue
            }
            guard !secret.isEmpty else {
                skipped.append(String(localized: "\(label) (empty secret)"))
                continue
            }
            tokens.append(.imported(issuer: issuer, account: name.trimmingCharacters(in: .whitespaces),
                                    secret: Base32.encode(secret), kind: kind, algorithm: algorithm,
                                    digits: int(5) == 2 ? 8 : 6, counter: int(7)))
        }
        return TwoFAS.Backup(tokens: tokens, skipped: skipped)
    }
}

extension GoogleAuthenticator {
    /// Accounts per QR code, like Google Authenticator's own export. Still easy to scan off a Mac screen.
    public static let batchSize = 10

    /// Google's payload has no period field and only 6 or 8 digits; Steam isn't supported.
    public static func canExport(_ token: Token) -> Bool {
        switch token.kind {
        case .steam: return false
        case .hotp: return token.digits == 6 || token.digits == 8
        case .totp: return (token.digits == 6 || token.digits == 8) && token.period == 30
        }
    }

    /// One `otpauth-migration://` link per QR code, for Google Authenticator's Transfer accounts → Import accounts.
    /// Tokens it can't hold are left out (see `canExport`).
    public static func encode(_ backup: TwoFAS.Backup) -> [String] {
        let tokens = backup.tokens.filter(canExport)
        guard !tokens.isEmpty else { return [] }
        let batches = stride(from: 0, to: tokens.count, by: batchSize).map { Array(tokens[$0..<min($0 + batchSize, tokens.count)]) }
        return batches.map { batch in
            var payload: [UInt8] = []
            for t in batch {
                var otp = Protobuf.bytes(1, Array(Base32.decode(t.secret) ?? Data()))
                otp += Protobuf.bytes(2, Array((t.account ?? t.name).utf8))
                otp += Protobuf.bytes(3, Array((t.issuer ?? t.name).utf8))
                let algorithm: UInt64 = switch t.algorithm {
                case .sha1: 1
                case .sha256: 2
                case .sha512: 3
                }
                otp += Protobuf.varint(4, algorithm)
                otp += Protobuf.varint(5, t.digits == 8 ? 2 : 1)
                otp += Protobuf.varint(6, t.kind == .hotp ? 1 : 2)
                if t.kind == .hotp { otp += Protobuf.varint(7, t.counter) }
                payload += Protobuf.bytes(1, otp)
            }
            // Each code is a complete export of its own (batch 1 of 1). Google Authenticator rejects
            // "code 1 of N" codes that it didn't make itself, even when scanned in order.
            payload += Protobuf.varint(2, 1)
            payload += Protobuf.varint(3, 1)
            payload += Protobuf.varint(4, 0)
            payload += Protobuf.varint(5, UInt64(UInt32.random(in: 1...UInt32(Int32.max))))
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let data = Data(payload).base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "otpauth-migration://offline?data=\(data)"
        }
    }
}

/// Just enough protobuf to read and write Google's MigrationPayload: varints and length-delimited fields.
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

    static func varint(_ number: Int, _ value: UInt64) -> [UInt8] {
        encode(UInt64(number << 3)) + encode(value)
    }

    static func bytes(_ number: Int, _ value: [UInt8]) -> [UInt8] {
        encode(UInt64(number << 3 | 2)) + encode(UInt64(value.count)) + value
    }

    private static func encode(_ value: UInt64) -> [UInt8] {
        var v = value
        var out: [UInt8] = []
        repeat {
            let byte = UInt8(v & 0x7F)
            v >>= 7
            out.append(v == 0 ? byte : byte | 0x80)
        } while v != 0
        return out
    }

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
