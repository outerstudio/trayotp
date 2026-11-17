import Foundation

/// Import of password manager CSV exports that have a one-time password column:
/// Apple Passwords (`OTPAuth`), 1Password (`OTPAuth`), Bitwarden and Bitwarden Authenticator (`login_totp`),
/// KeePassXC (`TOTP`). Rows without a code are passwords without 2FA and are ignored.
public enum PasswordCSV {
    static let otpColumns = ["otpauth", "login_totp", "totp", "otp"]
    static let nameColumns = ["title", "name"]
    static let accountColumns = ["username", "login_username"]
    static let groupColumns = ["folder", "group"]

    public static func isExport(_ data: Data) -> Bool { header(data) != nil }

    /// The header row, if it has an OTP column.
    static func header(_ data: Data) -> [String]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let firstLine = text.prefix { !$0.isNewline }
        guard firstLine.contains(","), let header = rows(String(firstLine)).first?.map(normalized),
              header.contains(where: otpColumns.contains)
        else { return nil }
        return header
    }

    public static func decode(_ data: Data) throws -> TwoFAS.Backup {
        guard let text = String(data: data, encoding: .utf8), header(data) != nil else { throw ImportError.invalidFile }
        var rows = rows(text)
        let header = rows.removeFirst().map(normalized)
        func column(_ names: [String]) -> Int? {
            for name in names { if let i = header.firstIndex(of: name) { return i } }
            return nil
        }
        guard let otp = column(otpColumns) else { throw ImportError.invalidFile }
        let nameCol = column(nameColumns), accountCol = column(accountColumns), groupCol = column(groupColumns)

        var groups = GroupCollector()
        var tokens: [Token] = []
        var skipped: [String] = []
        for row in rows {
            func value(_ i: Int?) -> String? {
                guard let i, i < row.count else { return nil }
                let v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
                return v.isEmpty ? nil : v
            }
            guard let field = value(otp) else { continue }
            let name = value(nameCol)
            do {
                var token = try OTPField.parse(field, name: name)
                if let name { token.name = name }
                if token.account == nil { token.account = value(accountCol) }
                // KeePassXC writes the group path ("Root/Work"); use the last part, but not the root itself.
                let group = value(groupCol)?.split(separator: "/").last.map(String.init)
                token.groupId = groups.id(for: group == "Root" ? nil : group)
                tokens.append(token)
            } catch {
                skipped.append("\(name ?? "Unnamed") (\(error.localizedDescription))")
            }
        }
        return TwoFAS.Backup(tokens: tokens, groups: groups.groups, skipped: skipped)
    }

    private static func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{FEFF}"))).lowercased()
    }

    /// RFC 4180: quoted fields may contain commas, line breaks and doubled quotes.
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = text.unicodeScalars.makeIterator()
        var pending = chars.next()
        while let c = pending {
            pending = chars.next()
            if quoted {
                if c == "\"" {
                    if pending == "\"" { field.unicodeScalars.append(c); pending = chars.next() } else { quoted = false }
                } else {
                    field.unicodeScalars.append(c)
                }
            } else if c == "\"" {
                quoted = true
            } else if c == "," {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" {
                if c == "\r", pending == "\n" { pending = chars.next() }
                row.append(field); field = ""
                if row != [""] { rows.append(row) }
                row = []
            } else {
                field.unicodeScalars.append(c)
            }
        }
        row.append(field)
        if row != [""] { rows.append(row) }
        return rows
    }
}
