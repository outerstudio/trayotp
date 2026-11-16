import CryptoKit
import Foundation

/// Wraps the vault key with a key derived from a master password, so the Keychain item alone
/// is not enough to open the vault.
///
/// wrappingKey = scrypt(password, salt, N, r, p) → AES-256-GCM(vaultKey). Stored as JSON.
public enum MasterPassword {
    public enum Error: Swift.Error, Equatable, LocalizedError {
        case wrongPassword
        case invalidData

        public var errorDescription: String? {
            switch self {
            case .wrongPassword: return "Wrong master password."
            case .invalidData: return "The stored vault key is damaged."
            }
        }
    }

    struct Wrapped: Codable {
        var version = 1
        var salt: Data
        var n: Int
        var r: Int
        var p: Int
        /// AES-GCM combined: nonce + ciphertext + tag.
        var sealed: Data
    }

    /// 2^17 × r=8 ≈ 128 MB and ~0.5 s per guess on Apple silicon: 4× Aegis's default.
    public static let defaultN = 1 << 17

    public static func wrap(_ key: Data, password: String, n: Int = defaultN) throws -> Data {
        let salt = TwoFAS.randomBytes(32)
        guard let derived = CryptoUtil.scrypt(password: Array(password.utf8), salt: Array(salt), n: n, r: 8, p: 1, length: 32),
              let sealed = try AES.GCM.seal(key, using: SymmetricKey(data: derived)).combined
        else { throw Error.invalidData }
        return try JSONEncoder().encode(Wrapped(salt: salt, n: n, r: 8, p: 1, sealed: sealed))
    }

    public static func unwrap(_ blob: Data, password: String) throws -> Data {
        guard let w = try? JSONDecoder().decode(Wrapped.self, from: blob), w.version == 1,
              let derived = CryptoUtil.scrypt(password: Array(password.utf8), salt: Array(w.salt), n: w.n, r: w.r, p: w.p, length: 32),
              let box = try? AES.GCM.SealedBox(combined: w.sealed)
        else { throw Error.invalidData }
        guard let key = try? AES.GCM.open(box, using: SymmetricKey(data: derived)) else { throw Error.wrongPassword }
        return key
    }

    /// A raw vault key is exactly 32 bytes; anything else that parses is a wrapped key.
    public static func isWrapped(_ blob: Data) -> Bool {
        blob.count != 32 && (try? JSONDecoder().decode(Wrapped.self, from: blob)) != nil
    }
}
