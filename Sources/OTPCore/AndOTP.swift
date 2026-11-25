import CryptoKit
import Foundation

/// Import of andOTP backups: a plain JSON array, or an encrypted `.json.aes` / `.bin` file.
///
/// Encrypted (andOTP 0.6.3+): iterations (UInt32 big-endian) ‖ salt (12) ‖ nonce (12) ‖ ciphertext ‖ tag (16).
/// Key = PBKDF2-HMAC-SHA1(password, salt, iterations, 32 bytes), cipher = AES-256-GCM.
public enum AndOTP {
    static func entries(_ data: Data) -> [JSONValue]? {
        guard let array = (try? JSONDecoder().decode(JSONValue.self, from: data))?.array else { return nil }
        // Raivo also exports a JSON array; andOTP entries have "type", Raivo's have "kind".
        guard array.allSatisfy({ $0["secret"] != nil && $0["type"] != nil }) else { return nil }
        return array
    }

    public static func isPlain(_ data: Data) -> Bool { entries(data) != nil }

    /// andOTP's encrypted files have no header, so anything binary that's long enough is a candidate,
    /// except files that start like an image, PDF or ZIP.
    public static func mayBeEncrypted(_ data: Data) -> Bool {
        data.count >= 12 + 16 + 2 && !data.isUTF8Text && !hasKnownSignature(data)
    }

    static func hasKnownSignature(_ data: Data) -> Bool {
        let signatures: [[UInt8]] = [
            [0x89, 0x50, 0x4E, 0x47],   // PNG
            [0xFF, 0xD8, 0xFF],         // JPEG
            [0x47, 0x49, 0x46, 0x38],   // GIF
            [0x25, 0x50, 0x44, 0x46],   // PDF
            [0x50, 0x4B, 0x03, 0x04],   // ZIP
            [0x49, 0x49, 0x2A, 0x00],   // TIFF
            [0x4D, 0x4D, 0x00, 0x2A],   // TIFF
        ]
        if signatures.contains(where: { data.starts(with: $0) }) { return true }
        // HEIC/HEIF and other ISO media files (iPhone photos): "ftyp" at offset 4.
        return data.count >= 8 && data[data.startIndex + 4..<data.startIndex + 8].elementsEqual("ftyp".utf8)
    }

    public static func decode(_ data: Data, password: String? = nil) throws -> TwoFAS.Backup {
        if let entries = entries(data) { return parse(entries) }
        guard mayBeEncrypted(data) else { throw ImportError.invalidFile }
        guard let password, !password.isEmpty else { throw ImportError.passwordRequired }
        let bytes = [UInt8](data)
        let iterations = bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard (1...10_000_000).contains(iterations), bytes.count >= 4 + 12 + 12 + 16 else {
            throw ImportError.wrongPassword
        }
        let key = CryptoUtil.pbkdf2SHA1(password: Array(password.utf8), salt: Array(bytes[4..<16]),
                                       iterations: iterations, length: 32)
        guard let entries = open(Data(bytes[16...]), key: key) else { throw ImportError.wrongPassword }
        return parse(entries)
    }

    private static func open(_ combined: Data, key: [UInt8]) -> [JSONValue]? {
        guard let box = try? AES.GCM.SealedBox(combined: combined),
              let plain = try? AES.GCM.open(box, using: SymmetricKey(data: key))
        else { return nil }
        return entries(plain)
    }

    static func parse(_ entries: [JSONValue]) -> TwoFAS.Backup {
        var groups = GroupCollector()
        var tokens: [Token] = []
        var skipped: [String] = []
        for e in entries {
            var issuer = e["issuer"]?.string
            var account = e["label"]?.string ?? ""
            if issuer == nil, let dash = account.range(of: " - ") {
                // andOTP before 0.6 kept "Issuer - account" in the label.
                issuer = String(account[..<dash.lowerBound])
                account = String(account[dash.upperBound...])
            }
            let label = Token.label(issuer: issuer, account: account)
            let kind: OTPKind
            switch e["type"]?.string?.uppercased() {
            case "TOTP": kind = .totp
            case "HOTP": kind = .hotp
            case "STEAM": kind = .steam
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
                digits: e["digits"]?.int ?? 6, period: e["period"]?.int ?? 30,
                counter: UInt64(max(0, e["counter"]?.int ?? 0)),
                groupId: groups.id(for: e["tags"]?.array?.first?.string)))
        }
        return TwoFAS.Backup(tokens: tokens, groups: groups.groups, skipped: skipped)
    }
}
