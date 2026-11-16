import Foundation

/// An Aegis-compatible icon pack: a ZIP with `pack.json` at its root plus SVG/PNG/JPEG files.
/// Format: https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md
public struct IconPack: Codable, Sendable {
    public struct Icon: Codable, Hashable, Sendable {
        public var name: String?
        /// Path relative to the pack root, e.g. "icons/1_Primary/Google.svg".
        public var filename: String
        public var category: String?
        public var issuer: [String]

        public var displayName: String {
            name ?? issuer.first ?? (filename as NSString).lastPathComponent
        }

        public init(name: String? = nil, filename: String, category: String? = nil, issuer: [String]) {
            self.name = name
            self.filename = filename
            self.category = category
            self.issuer = issuer
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            filename = try c.decode(String.self, forKey: .filename)
            category = try c.decodeIfPresent(String.self, forKey: .category)
            issuer = try c.decodeIfPresent([String].self, forKey: .issuer) ?? []
        }
    }

    public var uuid: String
    public var name: String
    public var version: Int
    public var icons: [Icon]

    private var exact: [String: Icon] = [:]
    /// Keys usable for partial matching, longest first so "googlecloud" wins over "google".
    private var partialKeys: [(key: String, icon: Icon)] = []

    private enum CodingKeys: String, CodingKey { case uuid, name, version, icons }

    public init(uuid: String, name: String, version: Int, icons: [Icon]) {
        self.uuid = uuid
        self.name = name
        self.version = version
        self.icons = icons
        buildIndex()
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(String.self, forKey: .uuid)
        name = try c.decode(String.self, forKey: .name)
        version = try c.decode(Int.self, forKey: .version)
        icons = try c.decode([Icon].self, forKey: .icons)
        buildIndex()
    }

    public static func decode(_ data: Data) throws -> IconPack {
        try JSONDecoder().decode(IconPack.self, from: data)
    }

    private mutating func buildIndex() {
        exact = [:]
        for icon in icons {
            for key in (icon.issuer + [icon.name ?? ""]).map(Self.matchKey) where !key.isEmpty {
                if exact[key] == nil { exact[key] = icon }
            }
        }
        partialKeys = exact.filter { $0.key.count >= 4 }
            .map { (key: $0.key, icon: $0.value) }
            .sorted { $0.key.count > $1.key.count || ($0.key.count == $1.key.count && $0.key < $1.key) }
    }

    /// Finds the icon for a token: exact issuer/name match first, then the longest pack issuer
    /// starting at a word boundary ("Google Workspace", "accounts.google.com" → Google,
    /// but "Gmail" does not match "Mail").
    public func bestMatch(name: String, issuer: String?) -> Icon? {
        let raws = [issuer ?? "", name]
        for key in raws.map(Self.matchKey) where !key.isEmpty {
            if let icon = exact[key] { return icon }
        }
        for raw in raws {
            let words = raw.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            for i in words.indices {
                let tail = words[i...].joined()
                if let hit = partialKeys.first(where: { tail.hasPrefix($0.key) }) { return hit.icon }
            }
        }
        return nil
    }

    /// Icons whose name or issuer contains the query, best matches first.
    public func search(_ query: String) -> [Icon] {
        let q = Self.matchKey(query)
        guard !q.isEmpty else { return icons }
        return icons
            .compactMap { icon -> (Icon, Int)? in
                let keys = (icon.issuer + [icon.name ?? ""]).map(Self.matchKey)
                if keys.contains(q) { return (icon, 0) }
                if keys.contains(where: { $0.hasPrefix(q) }) { return (icon, 1) }
                if keys.contains(where: { $0.contains(q) }) { return (icon, 2) }
                return nil
            }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.displayName < $1.0.displayName }
            .map(\.0)
    }

    /// "GitHub", "git-hub" and "Git Hub" all become "github".
    public static func matchKey(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
