import Compression
import CryptoKit
import Foundation

/// Reads single files from a ZIP archive held in memory, including WinZip AES-encrypted entries
/// (what Raivo OTP and 7-Zip write). Only "stored" and "deflate" compression are supported.
enum Zip {
    struct Entry {
        let name: String
        let flags: Int
        let method: Int
        let compressedSize: Int
        let size: Int
        let localOffset: Int
        let extra: Data
    }

    enum Error: Swift.Error {
        case malformed
        case unsupported
        case wrongPassword
    }

    static func isZip(_ data: Data) -> Bool { data.starts(with: [0x50, 0x4B, 0x03, 0x04]) }

    static func entries(_ data: Data) throws -> [Entry] {
        guard data.count >= 22 else { throw Error.malformed }
        // End of central directory: the last "PK\5\6" within the final 64 KiB + 22 bytes.
        var eocd = data.count - 22
        let floor = max(0, data.count - 22 - 0xFFFF)
        while eocd >= floor, data.readUInt32LE(eocd) != 0x0605_4B50 { eocd -= 1 }
        guard eocd >= floor else { throw Error.malformed }
        let count = data.readUInt16LE(eocd + 10)
        var p = data.readUInt32LE(eocd + 16)

        var out: [Entry] = []
        for _ in 0..<count {
            guard p + 46 <= data.count, data.readUInt32LE(p) == 0x0201_4B50 else { throw Error.malformed }
            let nameLength = data.readUInt16LE(p + 28), extraLength = data.readUInt16LE(p + 30)
            let commentLength = data.readUInt16LE(p + 32)
            guard p + 46 + nameLength + extraLength <= data.count else { throw Error.malformed }
            let start = data.startIndex + p + 46
            out.append(Entry(
                name: String(decoding: data[start..<(start + nameLength)], as: UTF8.self),
                flags: data.readUInt16LE(p + 8),
                method: data.readUInt16LE(p + 10),
                compressedSize: data.readUInt32LE(p + 20),
                size: data.readUInt32LE(p + 24),
                localOffset: data.readUInt32LE(p + 42),
                extra: Data(data[(start + nameLength)..<(start + nameLength + extraLength)])))
            p += 46 + nameLength + extraLength + commentLength
        }
        return out
    }

    static func isEncrypted(_ entry: Entry) -> Bool { entry.flags & 1 != 0 }

    static func extract(_ entry: Entry, from data: Data, password: String?) throws -> Data {
        let local = entry.localOffset
        guard local + 30 <= data.count, data.readUInt32LE(local) == 0x0403_4B50 else { throw Error.malformed }
        let start = local + 30 + data.readUInt16LE(local + 26) + data.readUInt16LE(local + 28)
        guard start + entry.compressedSize <= data.count else { throw Error.malformed }
        var body = Data(data[(data.startIndex + start)..<(data.startIndex + start + entry.compressedSize)])

        var method = entry.method
        if isEncrypted(entry) {
            // WinZip AES: method 99 with the real method in extra field 0x9901. ZipCrypto isn't supported.
            guard method == 99, let aes = aesExtra(entry.extra), let password else { throw Error.unsupported }
            method = aes.method
            body = try decryptAES(body, strength: aes.strength, password: password)
        }
        switch method {
        case 0: return body
        case 8: return try inflate(body, size: entry.size)
        default: throw Error.unsupported
        }
    }

    private static func aesExtra(_ extra: Data) -> (strength: Int, method: Int)? {
        var p = 0
        while p + 4 <= extra.count {
            let id = extra.readUInt16LE(p), size = extra.readUInt16LE(p + 2)
            if id == 0x9901, size >= 7, p + 4 + 7 <= extra.count {
                return (Int(extra[extra.startIndex + p + 8]), extra.readUInt16LE(p + 9))
            }
            p += 4 + size
        }
        return nil
    }

    /// salt ‖ password verifier (2) ‖ AES-CTR ciphertext (little-endian counter from 1) ‖ HMAC-SHA1 (first 10 bytes).
    /// Keys: PBKDF2-HMAC-SHA1(password, salt, 1000) → AES key ‖ HMAC key ‖ verifier.
    private static func decryptAES(_ body: Data, strength: Int, password: String) throws -> Data {
        guard (1...3).contains(strength) else { throw Error.unsupported }
        let keyLength = 8 + 8 * strength, saltLength = 4 + 4 * strength
        let bytes = [UInt8](body)
        guard bytes.count >= saltLength + 2 + 10 else { throw Error.malformed }
        let derived = CryptoUtil.pbkdf2SHA1(password: Array(password.utf8), salt: Array(bytes[0..<saltLength]),
                                            iterations: 1000, length: 2 * keyLength + 2)
        guard Array(derived[(2 * keyLength)...]) == Array(bytes[saltLength..<(saltLength + 2)]) else { throw Error.wrongPassword }

        let cipher = Array(bytes[(saltLength + 2)..<(bytes.count - 10)])
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: cipher, using: SymmetricKey(data: derived[keyLength..<(2 * keyLength)]))
        guard Array(mac.prefix(10)) == Array(bytes.suffix(10)) else { throw Error.wrongPassword }

        let blocks = (cipher.count + 15) / 16
        var counters = [UInt8](repeating: 0, count: blocks * 16)
        for b in 0..<blocks {
            var n = UInt64(b + 1)
            for k in 0..<8 { counters[b * 16 + k] = UInt8(truncatingIfNeeded: n); n >>= 8 }
        }
        guard let stream = CryptoUtil.aesECBEncrypt(key: Array(derived[0..<keyLength]), data: counters) else { throw Error.malformed }
        return Data(zip(cipher, stream).map { $0 ^ $1 })
    }

    private static func inflate(_ body: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        guard size <= 64 << 20 else { throw Error.unsupported }
        var out = [UInt8](repeating: 0, count: size)
        let written = body.withUnsafeBytes { src in
            compression_decode_buffer(&out, size, src.bindMemory(to: UInt8.self).baseAddress!, body.count, nil, COMPRESSION_ZLIB)
        }
        guard written == size else { throw Error.malformed }
        return Data(out)
    }
}
