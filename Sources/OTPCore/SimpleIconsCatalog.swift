import Foundation

public struct SimpleIconsCatalog: Sendable {
    public struct Icon: Decodable, Identifiable, Sendable {
        fileprivate struct Aliases: Decodable, Sendable {
            let aka: [String]?
        }

        public struct License: Decodable, Sendable {
            public let type: String
            public let url: URL?

            public var link: URL? {
                url ?? URL(string: "https://spdx.org/licenses/\(type).html")
            }
        }

        public var id: String { slug }
        public let title: String
        public let slug: String
        public let source: URL?
        public let guidelines: URL?
        public let license: License?
        fileprivate let aliases: Aliases?

        public var downloadURL: URL {
            SimpleIconsCatalog.packageURL.appendingPathComponent("icons").appendingPathComponent(slug + ".svg")
        }
    }

    public struct Suggestion: Identifiable, Sendable {
        public let icon: Icon
        public let tokenIDs: [Token.ID]
        public var id: String { icon.slug }
    }

    // Keep the metadata and downloaded artwork on the same upstream release.
    public static let version = "16.38.1"
    private static let packageURL = URL(string: "https://cdn.jsdelivr.net/npm/simple-icons@\(version)/")!
    public static let catalogURL = packageURL.appendingPathComponent("data").appendingPathComponent("simple-icons.json")
    public static let disclaimerURL = URL(string: "https://github.com/simple-icons/simple-icons/blob/develop/DISCLAIMER.md")!

    private let bySlug: [String: Icon]
    private let searchIndex: [(icon: Icon, keys: [String])]
    private let slugsByName: [String: Set<String>]
    private let slugsByDomain: [String: Set<String>]

    public init(data: Data) throws {
        let icons = try JSONDecoder().decode([Icon].self, from: data)
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_".utf8)
        guard !icons.isEmpty, Set(icons.map(\.slug)).count == icons.count,
              icons.allSatisfy({ !$0.slug.isEmpty && $0.slug.utf8.allSatisfy(allowed.contains) })
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid Simple Icons catalog"))
        }
        bySlug = Dictionary(uniqueKeysWithValues: icons.map { ($0.slug, $0) })
        let index = icons.map { icon in
            (icon, ([icon.title, icon.slug] + (icon.aliases?.aka ?? [])).map(IconPack.matchKey))
        }
        searchIndex = index
        var names: [String: Set<String>] = [:]
        // Service login domains that differ from the artwork source.
        var domains: [String: Set<String>] = ["google.com": ["google"], "sr.ht": ["sourcehut"]]
        for (icon, keys) in index {
            for key in keys where !key.isEmpty {
                names[key, default: []].insert(icon.slug)
            }
            for url in [icon.source, icon.guidelines] {
                guard let host = url?.host?.lowercased() else { continue }
                let labels = host.split(separator: ".")
                // A catalog source may be hosted on another service. Only index a domain
                // when a hostname label identifies the icon itself (e.g. google.com).
                guard let brand = labels.dropLast().lastIndex(where: { keys.contains(IconPack.matchKey(String($0))) })
                else { continue }
                let domain = labels[brand...].joined(separator: ".")
                domains[domain, default: []].insert(icon.slug)
            }
        }
        slugsByName = names
        slugsByDomain = domains
    }

    /// Prefer the issuer from the backup, then the display name. Skip ambiguous matches.
    public func suggestedIcon(name: String, issuer: String?) -> Icon? {
        if let issuer, let icon = match(issuer) { return icon }
        return match(name)
    }

    private func match(_ value: String) -> Icon? {
        if let slugs = slugsByName[IconPack.matchKey(value)] {
            return slugs.count == 1 ? slugs.first.flatMap { bySlug[$0] } : nil
        }
        guard !value.contains("@"), let domain = Favicon.normalizeDomain(value) else { return nil }
        let labels = domain.split(separator: ".")
        for index in labels.indices.dropLast() {
            let suffix = labels[index...].joined(separator: ".")
            if let slugs = slugsByDomain[suffix] {
                return slugs.count == 1 ? slugs.first.flatMap { bySlug[$0] } : nil
            }
        }
        return nil
    }

    /// Groups tokens by logo so an import can ask once for each distinct download.
    public func suggestions(for tokens: [Token]) -> [Suggestion] {
        var tokenIDsBySlug: [String: [Token.ID]] = [:]
        for token in tokens where token.icon == nil {
            if let icon = suggestedIcon(name: token.name, issuer: token.issuer) {
                tokenIDsBySlug[icon.slug, default: []].append(token.id)
            }
        }
        return tokenIDsBySlug.compactMap { slug, ids in
            bySlug[slug].map { Suggestion(icon: $0, tokenIDs: ids) }
        }.sorted { $0.icon.title.localizedStandardCompare($1.icon.title) == .orderedAscending }
    }

    public func search(_ query: String, limit: Int) -> [Icon] {
        let key = IconPack.matchKey(query)
        guard !key.isEmpty, limit > 0 else { return [] }
        var exact: [Icon] = [], prefix: [Icon] = [], partial: [Icon] = []
        for (icon, keys) in searchIndex {
            if keys.contains(key) {
                exact.append(icon)
            } else if keys.contains(where: { $0.hasPrefix(key) }) {
                prefix.append(icon)
            } else if keys.contains(where: { $0.contains(key) }) {
                partial.append(icon)
            }
        }
        return Array((exact + prefix + partial).prefix(limit))
    }
}
