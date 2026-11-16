import CommonCrypto
import Foundation

enum CryptoUtil {
    static func pbkdf2SHA256(password: [UInt8], salt: [UInt8], iterations: UInt32, length: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: length)
        let status = password.withUnsafeBufferPointer { pw in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                pw.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) }, pw.count,
                salt, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &out, out.count
            )
        }
        precondition(status == kCCSuccess, "PBKDF2 failed")
        return out
    }

    static func hex(_ string: String) -> Data? {
        let chars = Array(string.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var data = Data(capacity: chars.count / 2)
        func nibble(_ c: UInt8) -> UInt8? {
            switch c {
            case 48...57: return c - 48
            case 97...102: return c - 87
            case 65...70: return c - 55
            default: return nil
            }
        }
        var i = 0
        while i < chars.count {
            guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
            data.append(hi << 4 | lo)
            i += 2
        }
        return data
    }

    // MARK: scrypt (RFC 7914). Not in CommonCrypto or CryptoKit; Aegis vaults use it.

    static func scrypt(password: [UInt8], salt: [UInt8], n: Int, r: Int, p: Int, length: Int) -> [UInt8]? {
        guard n > 1, n & (n - 1) == 0, r > 0, p > 0, n <= 1 << 22, r * p < 1 << 20 else { return nil }
        let blockWords = 32 * r
        var b = pbkdf2SHA256(password: password, salt: salt, iterations: 1, length: p * 128 * r)

        var x = [UInt32](repeating: 0, count: blockWords)
        var y = [UInt32](repeating: 0, count: blockWords)
        var v = [UInt32](repeating: 0, count: blockWords * n)

        for chunk in 0..<p {
            let offset = chunk * 128 * r
            for k in 0..<blockWords {
                let o = offset + k * 4
                x[k] = UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
            }
            v.withUnsafeMutableBufferPointer { vp in
                x.withUnsafeMutableBufferPointer { xp in
                    y.withUnsafeMutableBufferPointer { yp in
                        for i in 0..<n {
                            (vp.baseAddress! + i * blockWords).update(from: xp.baseAddress!, count: blockWords)
                            blockMix(xp, yp, r: r)
                        }
                        for _ in 0..<n {
                            let j = Int(xp[(2 * r - 1) * 16]) & (n - 1)
                            let vj = vp.baseAddress! + j * blockWords
                            for k in 0..<blockWords { xp[k] ^= vj[k] }
                            blockMix(xp, yp, r: r)
                        }
                    }
                }
            }
            for k in 0..<blockWords {
                let o = offset + k * 4
                b[o] = UInt8(truncatingIfNeeded: x[k])
                b[o + 1] = UInt8(truncatingIfNeeded: x[k] >> 8)
                b[o + 2] = UInt8(truncatingIfNeeded: x[k] >> 16)
                b[o + 3] = UInt8(truncatingIfNeeded: x[k] >> 24)
            }
        }
        return pbkdf2SHA256(password: password, salt: b, iterations: 1, length: length)
    }

    /// scryptBlockMix: B → B', using `y` as scratch space of the same size.
    private static func blockMix(_ b: UnsafeMutableBufferPointer<UInt32>, _ y: UnsafeMutableBufferPointer<UInt32>, r: Int) {
        var t = [UInt32](repeating: 0, count: 16)
        for k in 0..<16 { t[k] = b[(2 * r - 1) * 16 + k] }
        for i in 0..<(2 * r) {
            for k in 0..<16 { t[k] ^= b[i * 16 + k] }
            salsa20_8(&t)
            // Even blocks go to the first half, odd blocks to the second.
            let dest = (i % 2 == 0 ? i / 2 : r + i / 2) * 16
            for k in 0..<16 { y[dest + k] = t[k] }
        }
        b.baseAddress!.update(from: y.baseAddress!, count: 32 * r)
    }

    private static func salsa20_8(_ b: inout [UInt32]) {
        var x = b
        func rotl(_ a: UInt32, _ n: UInt32) -> UInt32 { (a << n) | (a >> (32 - n)) }
        for _ in 0..<4 {
            x[4] ^= rotl(x[0] &+ x[12], 7);   x[8] ^= rotl(x[4] &+ x[0], 9)
            x[12] ^= rotl(x[8] &+ x[4], 13);  x[0] ^= rotl(x[12] &+ x[8], 18)
            x[9] ^= rotl(x[5] &+ x[1], 7);    x[13] ^= rotl(x[9] &+ x[5], 9)
            x[1] ^= rotl(x[13] &+ x[9], 13);  x[5] ^= rotl(x[1] &+ x[13], 18)
            x[14] ^= rotl(x[10] &+ x[6], 7);  x[2] ^= rotl(x[14] &+ x[10], 9)
            x[6] ^= rotl(x[2] &+ x[14], 13);  x[10] ^= rotl(x[6] &+ x[2], 18)
            x[3] ^= rotl(x[15] &+ x[11], 7);  x[7] ^= rotl(x[3] &+ x[15], 9)
            x[11] ^= rotl(x[7] &+ x[3], 13);  x[15] ^= rotl(x[11] &+ x[7], 18)
            x[1] ^= rotl(x[0] &+ x[3], 7);    x[2] ^= rotl(x[1] &+ x[0], 9)
            x[3] ^= rotl(x[2] &+ x[1], 13);   x[0] ^= rotl(x[3] &+ x[2], 18)
            x[6] ^= rotl(x[5] &+ x[4], 7);    x[7] ^= rotl(x[6] &+ x[5], 9)
            x[4] ^= rotl(x[7] &+ x[6], 13);   x[5] ^= rotl(x[4] &+ x[7], 18)
            x[11] ^= rotl(x[10] &+ x[9], 7);  x[8] ^= rotl(x[11] &+ x[10], 9)
            x[9] ^= rotl(x[8] &+ x[11], 13);  x[10] ^= rotl(x[9] &+ x[8], 18)
            x[12] ^= rotl(x[15] &+ x[14], 7); x[13] ^= rotl(x[12] &+ x[15], 9)
            x[14] ^= rotl(x[13] &+ x[12], 13); x[15] ^= rotl(x[14] &+ x[13], 18)
        }
        for k in 0..<16 { b[k] = b[k] &+ x[k] }
    }
}

/// Test hook: scrypt as a hex string (CryptoUtil is internal).
public func CryptoUtil_scryptHex(_ password: String, _ salt: String, _ n: Int, _ r: Int, _ p: Int) -> String {
    (CryptoUtil.scrypt(password: Array(password.utf8), salt: Array(salt.utf8), n: n, r: r, p: p, length: 64) ?? [])
        .map { String(format: "%02x", $0) }.joined()
}
