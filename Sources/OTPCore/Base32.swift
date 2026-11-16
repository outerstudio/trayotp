import Foundation

/// RFC 4648 Base32 decoding, lenient about the formats people paste:
/// lowercase, spaces, dashes and missing padding are all accepted.
public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let lookup: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (i, c) in alphabet.enumerated() { map[c] = UInt8(i) }
        return map
    }()

    /// Uppercases and strips whitespace, dashes and `=` padding.
    public static func normalize(_ input: String) -> String {
        input.uppercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "=" }
    }

    /// Returns nil if the string contains characters outside the Base32 alphabet.
    public static func decode(_ input: String) -> Data? {
        let chars = normalize(input)
        guard !chars.isEmpty else { return nil }

        var bytes = Data()
        bytes.reserveCapacity(chars.count * 5 / 8)
        var buffer: UInt32 = 0
        var bits = 0
        for c in chars {
            guard let value = lookup[c] else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> UInt32(bits)) & 0xFF))
            }
        }
        return bytes
    }

    public static func encode(_ data: Data) -> String {
        var out = ""
        var buffer: UInt32 = 0
        var bits = 0
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                out.append(alphabet[Int((buffer >> UInt32(bits)) & 0x1F)])
            }
        }
        if bits > 0 {
            out.append(alphabet[Int((buffer << UInt32(5 - bits)) & 0x1F)])
        }
        return out
    }
}
