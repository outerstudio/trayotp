import Foundation

public enum BackupFormat: String, Sendable {
    case twoFAS = "2FAS"
    case aegis = "Aegis"
    case ente = "Ente Auth"
    case googleAuthenticator = "Google Authenticator"
    case bitwarden = "Bitwarden"
    case proton = "Proton Authenticator"
    case stratum = "Stratum"
    case andOTP = "andOTP"
    case freeOTPPlus = "FreeOTP+"
    case raivo = "Raivo OTP"
    case passwordCSV = "a password manager CSV"
    case linkList = "otpauth links"
}

public enum Exporter {
    public static func encode(_ backup: TwoFAS.Backup, as format: BackupFormat, password: String? = nil) throws -> Data {
        switch format {
        case .twoFAS: return try TwoFAS.encode(backup, password: password)
        case .aegis: return try Aegis.encode(backup, password: password)
        case .ente: return Ente.encode(backup)
        case .bitwarden: return try Bitwarden.encode(backup)
        case .linkList: return Data(backup.tokens.map { OTPAuthURI.make($0) + "\n" }.joined().utf8)
        default: throw ImportError.unsupported("TrayOTP can't export to \(format.rawValue).")
        }
    }

    /// Whether the format can be password-protected by TrayOTP.
    public static func supportsEncryption(_ format: BackupFormat) -> Bool {
        format == .twoFAS || format == .aegis
    }

    /// Tokens the format can't hold, which `encode` leaves out.
    public static func unsupported(_ tokens: [Token], in format: BackupFormat) -> [Token] {
        switch format {
        case .bitwarden: return tokens.filter { !Bitwarden.canExport($0) }
        case .googleAuthenticator: return tokens.filter { !GoogleAuthenticator.canExport($0) }
        default: return []
        }
    }
}

/// Detects the backup format of a file and imports it.
public enum Importer {
    public static func detect(_ data: Data) -> BackupFormat? {
        if Aegis.isVault(data) { return .aegis }
        if Ente.isEncryptedExport(data) { return .ente }
        if let root = try? JSONDecoder().decode(JSONValue.self, from: data),
           root["services"] != nil || root["servicesEncrypted"] != nil {
            return .twoFAS
        }
        if ProtonAuthenticator.isExport(data) { return .proton }
        if Stratum.isBackup(data) { return .stratum }
        if FreeOTPPlus.isExport(data) { return .freeOTPPlus }
        if Bitwarden.isExport(data) { return .bitwarden }
        if Raivo.isExport(data) { return .raivo }
        if AndOTP.isPlain(data) { return .andOTP }
        if GoogleAuthenticator.isExport(data) { return .googleAuthenticator }
        if PasswordCSV.isExport(data) { return .passwordCSV }
        if Ente.isLinkList(data) { return Ente.isEnte(data) ? .ente : .linkList }
        // andOTP's encrypted backups have no header: try them last.
        if AndOTP.mayBeEncrypted(data) { return .andOTP }
        return nil
    }

    public static func needsPassword(_ data: Data) -> Bool {
        switch detect(data) {
        case .twoFAS: return TwoFAS.isEncrypted(data)
        case .aegis: return Aegis.isEncrypted(data)
        case .proton: return ProtonAuthenticator.isEncrypted(data)
        case .stratum: return Stratum.isEncrypted(data)
        case .raivo: return Raivo.isEncrypted(data)
        case .andOTP: return !AndOTP.isPlain(data)
        default: return false
        }
    }

    public static func decode(_ data: Data, password: String? = nil) throws -> (BackupFormat, TwoFAS.Backup) {
        guard let format = detect(data) else { throw ImportError.invalidFile }
        let backup: TwoFAS.Backup = switch format {
        case .twoFAS: try TwoFAS.decode(data, password: password)
        case .aegis: try Aegis.decode(data, password: password)
        case .ente, .linkList: try Ente.decode(data)
        case .googleAuthenticator: try GoogleAuthenticator.decode(data)
        case .bitwarden: try Bitwarden.decode(data)
        case .proton: try ProtonAuthenticator.decode(data, password: password)
        case .stratum: try Stratum.decode(data, password: password)
        case .andOTP: try AndOTP.decode(data, password: password)
        case .freeOTPPlus: try FreeOTPPlus.decode(data)
        case .raivo: try Raivo.decode(data, password: password)
        case .passwordCSV: try PasswordCSV.decode(data)
        }
        return (format, backup)
    }
}
