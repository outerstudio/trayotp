import Foundation

/// Argon2id (RFC 9106, version 0x13) and the BLAKE2b hash it is built on (RFC 7693).
/// Neither is in CommonCrypto or CryptoKit; Proton Authenticator and Stratum backups use Argon2id.
enum Argon2 {
    /// - Parameters: `memoryKiB` is m (1 KiB blocks), `iterations` is t, `parallelism` is p.
    static func id(password: [UInt8], salt: [UInt8], iterations: Int, memoryKiB: Int, parallelism: Int, length: Int,
                   secret: [UInt8] = [], associatedData: [UInt8] = []) -> [UInt8]? {
        let p = parallelism
        guard p >= 1, p < 1 << 24, iterations >= 1, length >= 4, salt.count >= 8,
              memoryKiB >= 8 * p, memoryKiB <= 1 << 22 else { return nil }

        var h0Input: [UInt8] = []
        for v in [p, length, memoryKiB, iterations, 0x13, 2] { h0Input += le32(v) }
        for field in [password, salt, secret, associatedData] { h0Input += le32(field.count) + field }
        let h0 = Blake2b.hash(h0Input, length: 64)

        let blockCount = 4 * p * (memoryKiB / (4 * p))
        let laneLength = blockCount / p
        let segmentLength = laneLength / 4
        var memory = [UInt64](repeating: 0, count: blockCount * 128)

        memory.withUnsafeMutableBufferPointer { mem in
            let base = mem.baseAddress!
            for lane in 0..<p {
                for column in 0..<2 {
                    let block = longHash(h0 + le32(column) + le32(lane), length: 1024)
                    let dst = base + (lane * laneLength + column) * 128
                    for k in 0..<128 { dst[k] = le64(block, k * 8) }
                }
            }

            var address = [UInt64](repeating: 0, count: 128)
            var input = [UInt64](repeating: 0, count: 128)
            let zero = [UInt64](repeating: 0, count: 128)
            for pass in 0..<iterations {
                for slice in 0..<4 {
                    for lane in 0..<p {
                        // Argon2id: data-independent addressing for the first half of the first pass.
                        let independent = pass == 0 && slice < 2
                        if independent {
                            for k in 0..<128 { input[k] = 0 }
                            input[0] = UInt64(pass); input[1] = UInt64(lane); input[2] = UInt64(slice)
                            input[3] = UInt64(blockCount); input[4] = UInt64(iterations); input[5] = 2
                        }
                        var start = 0
                        if pass == 0 && slice == 0 {
                            start = 2
                            if independent { nextAddresses(&address, &input, zero) }
                        }
                        for index in start..<segmentLength {
                            let column = slice * segmentLength + index
                            let current = lane * laneLength + column
                            let previous = column == 0 ? current + laneLength - 1 : current - 1

                            let pseudoRandom: UInt64
                            if independent {
                                if index % 128 == 0 { nextAddresses(&address, &input, zero) }
                                pseudoRandom = address[index % 128]
                            } else {
                                pseudoRandom = base[previous * 128]
                            }

                            let refLane = pass == 0 && slice == 0 ? lane : Int((pseudoRandom >> 32) % UInt64(p))
                            let sameLane = refLane == lane
                            let areaSize: Int
                            if pass == 0 {
                                if slice == 0 { areaSize = index - 1 }
                                else if sameLane { areaSize = slice * segmentLength + index - 1 }
                                else { areaSize = slice * segmentLength - (index == 0 ? 1 : 0) }
                            } else {
                                if sameLane { areaSize = laneLength - segmentLength + index - 1 }
                                else { areaSize = laneLength - segmentLength - (index == 0 ? 1 : 0) }
                            }
                            var rel = pseudoRandom & 0xFFFF_FFFF
                            rel = (rel &* rel) >> 32
                            rel = UInt64(areaSize) - 1 - ((UInt64(areaSize) &* rel) >> 32)
                            let startPosition = pass == 0 || slice == 3 ? 0 : (slice + 1) * segmentLength
                            let refColumn = (startPosition + Int(rel)) % laneLength

                            fillBlock(prev: base + previous * 128, ref: base + (refLane * laneLength + refColumn) * 128,
                                      next: base + current * 128, xor: pass > 0)
                        }
                    }
                }
            }
        }

        var final = [UInt64](repeating: 0, count: 128)
        for lane in 0..<p {
            let last = (lane * laneLength + laneLength - 1) * 128
            for k in 0..<128 { final[k] ^= memory[last + k] }
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(1024)
        for w in final { for s in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: w >> UInt64(s))) } }
        return longHash(bytes, length: length)
    }

    // MARK: Internals

    private static func nextAddresses(_ address: inout [UInt64], _ input: inout [UInt64], _ zero: [UInt64]) {
        input[6] &+= 1
        zero.withUnsafeBufferPointer { z in
            input.withUnsafeMutableBufferPointer { i in
                address.withUnsafeMutableBufferPointer { a in
                    let zp = UnsafeMutablePointer(mutating: z.baseAddress!)
                    fillBlock(prev: zp, ref: i.baseAddress!, next: a.baseAddress!, xor: false)
                    fillBlock(prev: zp, ref: a.baseAddress!, next: a.baseAddress!, xor: false)
                }
            }
        }
    }

    /// The compression function G: next = P(prev ⊕ ref) ⊕ (prev ⊕ ref) [⊕ next, from the second pass on].
    private static func fillBlock(prev: UnsafeMutablePointer<UInt64>, ref: UnsafeMutablePointer<UInt64>,
                                  next: UnsafeMutablePointer<UInt64>, xor: Bool) {
        var r = [UInt64](repeating: 0, count: 128)
        var q = [UInt64](repeating: 0, count: 128)
        for k in 0..<128 { r[k] = prev[k] ^ ref[k]; q[k] = r[k] }
        if xor { for k in 0..<128 { q[k] ^= next[k] } }
        r.withUnsafeMutableBufferPointer { v in
            let v = v.baseAddress!
            for i in 0..<8 {
                let b = 16 * i
                round(v, b, b + 1, b + 2, b + 3, b + 4, b + 5, b + 6, b + 7,
                      b + 8, b + 9, b + 10, b + 11, b + 12, b + 13, b + 14, b + 15)
            }
            for i in 0..<8 {
                let b = 2 * i
                round(v, b, b + 1, b + 16, b + 17, b + 32, b + 33, b + 48, b + 49,
                      b + 64, b + 65, b + 80, b + 81, b + 96, b + 97, b + 112, b + 113)
            }
        }
        for k in 0..<128 { next[k] = q[k] ^ r[k] }
    }

    @inline(__always)
    private static func round(_ v: UnsafeMutablePointer<UInt64>, _ i0: Int, _ i1: Int, _ i2: Int, _ i3: Int,
                              _ i4: Int, _ i5: Int, _ i6: Int, _ i7: Int, _ i8: Int, _ i9: Int, _ i10: Int,
                              _ i11: Int, _ i12: Int, _ i13: Int, _ i14: Int, _ i15: Int) {
        gb(v, i0, i4, i8, i12); gb(v, i1, i5, i9, i13); gb(v, i2, i6, i10, i14); gb(v, i3, i7, i11, i15)
        gb(v, i0, i5, i10, i15); gb(v, i1, i6, i11, i12); gb(v, i2, i7, i8, i13); gb(v, i3, i4, i9, i14)
    }

    @inline(__always)
    private static func gb(_ v: UnsafeMutablePointer<UInt64>, _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        @inline(__always) func mix(_ x: UInt64, _ y: UInt64) -> UInt64 {
            x &+ y &+ 2 &* (x & 0xFFFF_FFFF) &* (y & 0xFFFF_FFFF)
        }
        @inline(__always) func rotr(_ x: UInt64, _ n: UInt64) -> UInt64 { (x >> n) | (x << (64 - n)) }
        v[a] = mix(v[a], v[b]); v[d] = rotr(v[d] ^ v[a], 32)
        v[c] = mix(v[c], v[d]); v[b] = rotr(v[b] ^ v[c], 24)
        v[a] = mix(v[a], v[b]); v[d] = rotr(v[d] ^ v[a], 16)
        v[c] = mix(v[c], v[d]); v[b] = rotr(v[b] ^ v[c], 63)
    }

    /// H' — variable-length hash built from BLAKE2b.
    private static func longHash(_ input: [UInt8], length: Int) -> [UInt8] {
        if length <= 64 { return Blake2b.hash(le32(length) + input, length: length) }
        var out: [UInt8] = []
        out.reserveCapacity(length)
        var v = Blake2b.hash(le32(length) + input, length: 64)
        let r = (length + 31) / 32 - 2
        out += v.prefix(32)
        for _ in 1..<r {
            v = Blake2b.hash(v, length: 64)
            out += v.prefix(32)
        }
        out += Blake2b.hash(v, length: length - 32 * r)
        return out
    }

    private static func le32(_ v: Int) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: UInt32(truncatingIfNeeded: v) >> UInt32($0 * 8)) }
    }

    private static func le64(_ b: [UInt8], _ o: Int) -> UInt64 {
        var w: UInt64 = 0
        for k in 0..<8 { w |= UInt64(b[o + k]) << UInt64(k * 8) }
        return w
    }
}

/// BLAKE2b (RFC 7693), unkeyed, 1–64 byte output.
enum Blake2b {
    private static let iv: [UInt64] = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ]
    private static let sigma: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
        [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
        [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
        [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
        [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
        [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
        [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
        [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
        [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
    ]

    static func hash(_ input: [UInt8], length: Int) -> [UInt8] {
        precondition((1...64).contains(length))
        var h = iv
        h[0] ^= 0x0101_0000 ^ UInt64(length)

        var offset = 0
        var counter: UInt64 = 0
        repeat {
            let remaining = input.count - offset
            let isLast = remaining <= 128
            let take = min(128, remaining)
            var block = [UInt8](repeating: 0, count: 128)
            if take > 0 { block.replaceSubrange(0..<take, with: input[offset..<(offset + take)]) }
            counter += UInt64(take)
            compress(&h, block, counter: counter, last: isLast)
            offset += take
            if isLast { break }
        } while true

        var out: [UInt8] = []
        for w in h { for s in stride(from: 0, to: 64, by: 8) { out.append(UInt8(truncatingIfNeeded: w >> UInt64(s))) } }
        return Array(out.prefix(length))
    }

    private static func compress(_ h: inout [UInt64], _ block: [UInt8], counter: UInt64, last: Bool) {
        var m = [UInt64](repeating: 0, count: 16)
        for i in 0..<16 {
            var w: UInt64 = 0
            for k in 0..<8 { w |= UInt64(block[i * 8 + k]) << UInt64(k * 8) }
            m[i] = w
        }
        var v = h + iv
        v[12] ^= counter
        if last { v[14] = ~v[14] }

        func g(_ a: Int, _ b: Int, _ c: Int, _ d: Int, _ x: UInt64, _ y: UInt64) {
            func rotr(_ x: UInt64, _ n: UInt64) -> UInt64 { (x >> n) | (x << (64 - n)) }
            v[a] = v[a] &+ v[b] &+ x; v[d] = rotr(v[d] ^ v[a], 32)
            v[c] = v[c] &+ v[d];      v[b] = rotr(v[b] ^ v[c], 24)
            v[a] = v[a] &+ v[b] &+ y; v[d] = rotr(v[d] ^ v[a], 16)
            v[c] = v[c] &+ v[d];      v[b] = rotr(v[b] ^ v[c], 63)
        }
        for r in 0..<12 {
            let s = sigma[r % 10]
            g(0, 4, 8, 12, m[s[0]], m[s[1]]);   g(1, 5, 9, 13, m[s[2]], m[s[3]])
            g(2, 6, 10, 14, m[s[4]], m[s[5]]);  g(3, 7, 11, 15, m[s[6]], m[s[7]])
            g(0, 5, 10, 15, m[s[8]], m[s[9]]);  g(1, 6, 11, 12, m[s[10]], m[s[11]])
            g(2, 7, 8, 13, m[s[12]], m[s[13]]); g(3, 4, 9, 14, m[s[14]], m[s[15]])
        }
        for i in 0..<8 { h[i] ^= v[i] ^ v[i + 8] }
    }
}

/// Test hooks (Argon2 and Blake2b are internal).
public func Argon2_idHex(password: [UInt8], salt: [UInt8], secret: [UInt8], ad: [UInt8],
                         t: Int, m: Int, p: Int, length: Int) -> String {
    (Argon2.id(password: password, salt: salt, iterations: t, memoryKiB: m, parallelism: p, length: length,
               secret: secret, associatedData: ad) ?? []).map { String(format: "%02x", $0) }.joined()
}

public func Blake2b_hex(_ input: String, length: Int = 64) -> String {
    Blake2b.hash(Array(input.utf8), length: length).map { String(format: "%02x", $0) }.joined()
}
