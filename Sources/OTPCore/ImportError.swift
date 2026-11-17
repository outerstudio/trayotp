import Foundation

public enum ImportError: Error, Equatable, LocalizedError {
    case invalidFile
    case passwordRequired
    case wrongPassword
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFile: return "This file is not a backup TrayOTP can read. See “Import and export” in the README for the supported apps."
        case .passwordRequired: return "This backup is encrypted. A password is required."
        case .wrongPassword: return "Wrong backup password. Use the password set when the backup was exported, not your Mac password."
        case .unsupported(let reason): return reason
        }
    }
}
