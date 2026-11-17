import AppKit
import OTPCore

enum IconPackError: Error, LocalizedError {
    case unzipFailed
    case missingManifest
    case noIcons

    var errorDescription: String? {
        switch self {
        case .unzipFailed: return String(localized: "The file could not be unzipped.")
        case .missingManifest: return String(localized: "This ZIP has no pack.json, so it is not an Aegis icon pack.")
        case .noIcons: return String(localized: "The icon pack contains no usable icons.")
        }
    }
}

/// The installed Aegis icon pack. Icons are public artwork, so they are stored unencrypted.
@MainActor
@Observable
final class IconPackStore {
    private(set) var pack: IconPack?

    @ObservationIgnored private var images: [String: NSImage] = [:]
    /// Icons that render as one flat color (e.g. Simple Icons' white-on-white Sony).
    @ObservationIgnored private var blank: Set<String> = []
    @ObservationIgnored private var matches: [String: IconPack.Icon?] = [:]

    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrayOTP/IconPack", isDirectory: true)
    }

    init() {
        pack = try? Self.readManifest(in: directory)
    }

    // MARK: Install / remove

    func install(zip: URL) throws {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("trayotp-iconpack-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }

        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, staging.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw IconPackError.unzipFailed }

        guard let root = Self.packRoot(in: staging) else { throw IconPackError.missingManifest }
        let manifest = try Self.readManifest(in: root)
        guard manifest.icons.contains(where: { Self.file($0, in: root) != nil }) else { throw IconPackError.noIcons }

        try fm.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: directory.path) { try fm.removeItem(at: directory) }
        try fm.moveItem(at: root, to: directory)

        images = [:]
        blank = []
        matches = [:]
        pack = manifest
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
        images = [:]
        blank = []
        matches = [:]
        pack = nil
    }

    // MARK: Lookup

    /// The pack icon matching this token, if any.
    func icon(for token: Token) -> IconPack.Icon? {
        guard let pack else { return nil }
        let key = "\(token.name)|\(token.issuer ?? "")"
        if let cached = matches[key] { return cached }
        let found = pack.bestMatch(name: token.name, issuer: token.issuer)
        matches[key] = found
        return found
    }

    func image(for token: Token) -> NSImage? {
        icon(for: token).flatMap(image(for:))
    }

    /// Nil for missing or unreadable (blank) icons, so callers fall back to initials.
    func image(for icon: IconPack.Icon) -> NSImage? {
        if let hit = images[icon.filename] { return hit }
        guard !blank.contains(icon.filename),
              let url = Self.file(icon, in: directory), let image = IconImage.load(url)
        else { return nil }
        var result = image
        if IconImage.isBlank(image) {
            guard url.pathExtension.lowercased() == "svg",
                  let svg = try? String(contentsOf: url, encoding: .utf8),
                  let repaired = IconImage.repairedSVG(svg)
            else {
                blank.insert(icon.filename)
                return nil
            }
            result = repaired
        }
        images[icon.filename] = result
        return result
    }

    // MARK: Helpers

    private static func readManifest(in root: URL) throws -> IconPack {
        let url = root.appendingPathComponent("pack.json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw IconPackError.missingManifest }
        return try IconPack.decode(Data(contentsOf: url))
    }

    /// pack.json should be at the root, but accept a ZIP that wraps everything in one folder.
    private static func packRoot(in dir: URL) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent("pack.json").path) { return dir }
        let children = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return children.first { fm.fileExists(atPath: $0.appendingPathComponent("pack.json").path) }
    }

    /// Resolves an icon's file, refusing paths that escape the pack folder.
    private static func file(_ icon: IconPack.Icon, in root: URL) -> URL? {
        let base = root.standardizedFileURL.path + "/"
        let url = root.appendingPathComponent(icon.filename).standardizedFileURL
        guard url.path.hasPrefix(base), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
