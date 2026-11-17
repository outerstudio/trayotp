import Foundation

/// Bitwarden JSON exports, from the Bitwarden password manager or the Bitwarden Authenticator app:
/// `{"encrypted": false, "folders": [{id, name}], "items": [{name, folderId, login: {username, totp}}]}`.
/// `login.totp` is an otpauth:// link, steam://SECRET or a bare secret. Items without one are passwords
/// without 2FA and are ignored. Bitwarden's CSV exports go through `PasswordCSV`.
public enum Bitwarden {
    static func root(_ data: Data) -> JSONValue? {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data),
              root["items"]?.array != nil || root["encrypted"]?.bool == true
        else { return nil }
        return root
    }

    public static func isExport(_ data: Data) -> Bool { root(data) != nil }

    public static func decode(_ data: Data) throws -> TwoFAS.Backup {
        guard let root = root(data) else { throw ImportError.invalidFile }
        if root["encrypted"]?.bool == true {
            throw ImportError.unsupported(
                "Encrypted Bitwarden exports aren't supported. Export again as “.json” (not “.json (Encrypted)”), import that file, then delete it.")
        }
        let folders = (root["folders"]?.array ?? []).compactMap { f -> TokenGroup? in
            guard let id = f["id"]?.string, let name = f["name"]?.string else { return nil }
            return TokenGroup(id: id, name: name)
        }
        var tokens: [Token] = []
        var skipped: [String] = []
        for item in root["items"]?.array ?? [] {
            guard let totp = item["login"]?["totp"]?.string, !totp.isEmpty else { continue }
            let name = item["name"]?.string ?? ""
            do {
                var token = try OTPField.parse(totp, name: name)
                if !name.isEmpty { token.name = name }
                if token.account == nil, let user = item["login"]?["username"]?.string, !user.isEmpty { token.account = user }
                token.groupId = item["folderId"]?.string.flatMap { id in folders.contains { $0.id == id } ? id : nil }
                tokens.append(token)
            } catch {
                skipped.append("\(name.isEmpty ? "Unnamed" : name) (\(error.localizedDescription))")
            }
        }
        let used = Set(tokens.compactMap(\.groupId))
        return TwoFAS.Backup(tokens: tokens, groups: folders.filter { used.contains($0.id) }, skipped: skipped)
    }

    /// Bitwarden Authenticator only reads TOTP and Steam codes, so HOTP tokens are left out.
    public static func canExport(_ token: Token) -> Bool { token.kind != .hotp }

    /// An unencrypted Bitwarden JSON export, readable by Bitwarden Authenticator and the Bitwarden password manager.
    public static func encode(_ backup: TwoFAS.Backup) throws -> Data {
        var folderIds: [String: String] = [:]
        for g in backup.groups { folderIds[g.id] = UUID().uuidString.lowercased() }
        let items: [JSONValue] = backup.tokens.filter(canExport).map { t in
            let totp = t.kind == .steam ? "steam://\(t.secret)" : OTPAuthURI.make(t)
            return .object([
                "id": .string(t.id.uuidString.lowercased()),
                "organizationId": .null,
                "folderId": t.groupId.flatMap { folderIds[$0] }.map(JSONValue.string) ?? .null,
                "type": .number(1),
                "name": .string(t.name),
                "notes": .null,
                "favorite": .bool(false),
                "login": .object([
                    "uris": .null,
                    "username": t.account.map(JSONValue.string) ?? .null,
                    "password": .null,
                    "totp": .string(totp),
                ]),
                "collectionIds": .null,
            ])
        }
        let root = JSONValue.object([
            "encrypted": .bool(false),
            "folders": .array(backup.groups.map { .object(["id": .string(folderIds[$0.id]!), "name": .string($0.name)]) }),
            "items": .array(items),
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(root)
    }
}
