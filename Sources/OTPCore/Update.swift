import Foundation

/// A dotted version like "0.2.0" or "v1.4". Pre-release suffixes ("-beta.1") are ignored.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let parts: [Int]

    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let core = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let numbers = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(nil) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }
}

/// The parts of a GitHub release (`GET /repos/{owner}/{repo}/releases/latest`) that updating needs.
public struct Release: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let url: URL

        private enum CodingKeys: String, CodingKey { case name, url = "browser_download_url" }
    }

    public let tag: String
    public let pageURL: URL
    public let notes: String?
    public let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tag = "tag_name", pageURL = "html_url", notes = "body", assets
    }

    public var version: AppVersion? { AppVersion(tag) }

    /// The app zip (`TrayOTP-v0.2.0.zip`).
    public var zip: Asset? { assets.first { $0.name.hasSuffix(".zip") } }

    /// Its `.sha256` companion, as published by the release workflow.
    public var checksum: Asset? {
        guard let zip else { return nil }
        return assets.first { $0.name == zip.name + ".sha256" }
    }

    /// The first 64-hex-digit token of `shasum -a 256` output ("<hash>  <file>").
    public static func parseChecksum(_ text: String) -> String? {
        guard let first = text.split(whereSeparator: \.isWhitespace).first,
              first.count == 64, first.allSatisfy(\.isHexDigit) else { return nil }
        return first.lowercased()
    }
}
