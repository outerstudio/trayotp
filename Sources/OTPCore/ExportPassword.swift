import Foundation

/// Checks the master password before exports, deletes and changes, in place of Touch ID. It stays in the
/// vault even when the vault key is wrapped by the same password (unlock with password).
///
/// The verifier is a random value wrapped with the password (see `MasterPassword`): opening it proves
/// the password is right, and nothing derived from the password is stored.
public enum ExportPassword {
    public static let minLength = 8

    public static func makeVerifier(password: String, n: Int = MasterPassword.defaultN) throws -> Data {
        try MasterPassword.wrap(TwoFAS.randomBytes(32), password: password, n: n)
    }

    public static func verify(_ verifier: Data, password: String) -> Bool {
        (try? MasterPassword.unwrap(verifier, password: password)) != nil
    }
}
