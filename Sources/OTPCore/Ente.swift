import Foundation

/// Import of Ente Auth exports, and of any plain text file with one otpauth:// link per line.
///
/// Ente adds a `codeDisplay` JSON parameter to each link ({"trashed":false,"tags":["Work"],...});
/// trashed codes are skipped and the first tag becomes the group.
/// Encrypted Ente exports (Argon2id + XChaCha20-Poly1305) are not supported.
public enum Ente {
    public static func isEncryptedExport(_ data: Data) -> Bool {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return false }
        return root["kdfParams"] != nil && root["encryptedData"] != nil
    }

    /// True for text whose non-empty lines are mostly otpauth:// links.
    public static func isLinkList(_ data: Data) -> Bool {
        let lines = links(in: data)
        return !lines.isEmpty
    }

    /// True if the links carry Ente's `codeDisplay` parameter.
    public static func isEnte(_ data: Data) -> Bool {
        links(in: data).contains { $0.contains("codeDisplay=") }
    }

    public static func decode(_ data: Data) throws -> TwoFAS.Backup {
        if isEncryptedExport(data) {
            throw ImportError.unsupported(
                "Encrypted Ente Auth exports aren't supported yet. In Ente Auth, choose Export Codes → Plain text, import that file, then delete it.")
        }
        let lines = links(in: data)
        guard !lines.isEmpty else { throw ImportError.invalidFile }

        var groups: [TokenGroup] = []
        var tokens: [Token] = []
        var skipped: [String] = []
        for line in lines {
            do {
                var token = try OTPAuthURI.parse(line)
                if let display = codeDisplay(line) {
                    if display["trashed"]?.bool == true { continue }
                    if let tag = display["tags"]?.array?.first?.string, !tag.isEmpty {
                        if let g = groups.first(where: { $0.name == tag }) {
                            token.groupId = g.id
                        } else {
                            let g = TokenGroup(name: tag)
                            groups.append(g)
                            token.groupId = g.id
                        }
                    }
                }
                tokens.append(token)
            } catch {
                let preview = line.count > 40 ? line.prefix(40) + "…" : Substring(line)
                skipped.append("\(preview) (\(error.localizedDescription))")
            }
        }
        return TwoFAS.Backup(tokens: tokens, groups: groups, skipped: skipped)
    }

    /// Ente Auth plain-text export: one otpauth:// link per line, groups written as Ente tags.
    public static func encode(_ backup: TwoFAS.Backup) -> Data {
        let names = Dictionary(backup.groups.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let lines = backup.tokens.map { t -> String in
            let display: [String: JSONValue] = [
                "pinned": .bool(false), "trashed": .bool(false),
                "lastUsedAt": .number(0), "tapCount": .number(0),
                "tags": .array(t.groupId.flatMap { names[$0] }.map { [.string($0)] } ?? []),
            ]
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let json = (try? encoder.encode(JSONValue.object(display))).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
            return OTPAuthURI.make(t, steamHost: true, extra: [("codeDisplay", json)])
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    static func links(in data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.lowercased().hasPrefix("otpauth://") }
    }

    private static func codeDisplay(_ link: String) -> JSONValue? {
        guard let raw = URLComponents(string: link)?.queryItems?.first(where: { $0.name == "codeDisplay" })?.value else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))
    }
}
