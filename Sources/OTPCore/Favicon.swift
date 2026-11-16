import Foundation

/// Favicons come from DuckDuckGo's icon service, fetched only when the user asks.
/// DuckDuckGo sees each requested domain.
public enum Favicon {
    /// A starting guess for the prompt: the issuer or name if it already looks like a domain,
    /// otherwise the name squashed together plus ".com" ("Air Canada" → "aircanada.com").
    public static func guessDomain(name: String, issuer: String?) -> String {
        for candidate in [issuer ?? "", name] {
            if let domain = normalizeDomain(candidate), candidate.contains(".") { return domain }
        }
        let base = IconPack.matchKey(issuer.flatMap { $0.isEmpty ? nil : $0 } ?? name)
        return base.isEmpty ? "" : "\(base).com"
    }

    /// Accepts "plurk.com", "https://www.plurk.com/login", " GitHub.com/ " → bare lowercase host.
    /// Returns nil if it isn't a plausible domain.
    public static func normalizeDomain(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let host = URLComponents(string: text)?.host, host.contains(".") else { return nil }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard host.allSatisfy(allowed.contains),
              !host.hasPrefix("."), !host.hasSuffix("."), !host.contains(".."),
              host.split(separator: ".").last.map({ $0.count >= 2 && $0.allSatisfy(\.isLetter) }) ?? false
        else { return nil }
        return host
    }

    /// URLs to try in order: the domain itself, then with "www." added or removed
    /// (DuckDuckGo has some icons only under one form, e.g. www.plurk.com).
    public static func urls(for domain: String) -> [URL] {
        let alternate = domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : "www." + domain
        return [domain, alternate].compactMap { URL(string: "https://icons.duckduckgo.com/ip3/\($0).ico") }
    }
}
