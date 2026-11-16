import Foundation

public enum BackupFormat: String, Sendable {
    case twoFAS = "2FAS"
    case aegis = "Aegis"
    case ente = "Ente Auth"
    case linkList = "otpauth links"
}

public enum Exporter {
    public static func encode(_ backup: TwoFAS.Backup, as format: BackupFormat, password: String? = nil) throws -> Data {
        switch format {
        case .twoFAS: return try TwoFAS.encode(backup, password: password)
        case .aegis: return try Aegis.encode(backup, password: password)
        case .ente, .linkList: return Ente.encode(backup)
        }
    }

    /// Whether the format can be password-protected by TrayOTP.
    public static func supportsEncryption(_ format: BackupFormat) -> Bool {
        format == .twoFAS || format == .aegis
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
        if Ente.isLinkList(data) { return Ente.isEnte(data) ? .ente : .linkList }
        return nil
    }

    public static func needsPassword(_ data: Data) -> Bool {
        switch detect(data) {
        case .twoFAS: return TwoFAS.isEncrypted(data)
        case .aegis: return Aegis.isEncrypted(data)
        default: return false
        }
    }

    public static func decode(_ data: Data, password: String? = nil) throws -> (BackupFormat, TwoFAS.Backup) {
        guard let format = detect(data) else { throw ImportError.invalidFile }
        switch format {
        case .twoFAS: return (format, try TwoFAS.decode(data, password: password))
        case .aegis: return (format, try Aegis.decode(data, password: password))
        case .ente, .linkList: return (format, try Ente.decode(data))
        }
    }
}
