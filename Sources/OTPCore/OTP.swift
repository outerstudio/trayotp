import CryptoKit
import Foundation

/// HOTP (RFC 4226) / TOTP (RFC 6238) code generation.
public enum OTP {
    public static func hmac(key: Data, message: Data, algorithm: OTPAlgorithm) -> Data {
        let k = SymmetricKey(data: key)
        switch algorithm {
        case .sha1: return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: k))
        case .sha256: return Data(HMAC<SHA256>.authenticationCode(for: message, using: k))
        case .sha512: return Data(HMAC<SHA512>.authenticationCode(for: message, using: k))
        }
    }

    /// RFC 4226 dynamic truncation → 31-bit integer.
    static func truncatedValue(key: Data, counter: UInt64, algorithm: OTPAlgorithm) -> UInt32 {
        var big = counter.bigEndian
        let message = Data(bytes: &big, count: MemoryLayout<UInt64>.size)
        let mac = [UInt8](hmac(key: key, message: message, algorithm: algorithm))
        let offset = Int(mac[mac.count - 1] & 0x0F)
        return (UInt32(mac[offset] & 0x7F) << 24)
            | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])
    }

    public static func hotp(key: Data, counter: UInt64, digits: Int, algorithm: OTPAlgorithm) -> String {
        let value = truncatedValue(key: key, counter: counter, algorithm: algorithm)
        var mod: UInt64 = 1
        for _ in 0..<digits { mod *= 10 }
        let code = UInt64(value) % mod
        let s = String(code)
        return String(repeating: "0", count: max(0, digits - s.count)) + s
    }

    /// Steam Guard: 5 characters from a custom alphabet, 30 s period.
    public static func steam(key: Data, counter: UInt64, algorithm: OTPAlgorithm = .sha1) -> String {
        let alphabet = Array("23456789BCDFGHJKMNPQRTVWXY")
        var value = truncatedValue(key: key, counter: counter, algorithm: algorithm)
        var out = ""
        for _ in 0..<5 {
            out.append(alphabet[Int(value % UInt32(alphabet.count))])
            value /= UInt32(alphabet.count)
        }
        return out
    }
}
