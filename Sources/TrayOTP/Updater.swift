import AppKit
import CryptoKit
import OTPCore

/// Checks GitHub Releases for a newer build and installs it in place.
///
/// There is no Sparkle and no Developer ID: the zip is fetched over HTTPS, checked against the release's
/// `.sha256`, must carry the same bundle ID and a valid signature, and is swapped in by a small shell
/// script once this process has quit. Downloads made by URLSession carry no quarantine flag, so the
/// new copy does not hit Gatekeeper again.
@MainActor
@Observable
final class Updater {
    private(set) var available: Release?
    private(set) var isBusy = false

    var checksAutomatically: Bool {
        didSet { UserDefaults.standard.set(checksAutomatically, forKey: Keys.auto) }
    }

    /// Which releases are offered. Until one is chosen, the channel of the running build, so a
    /// beta build keeps getting betas.
    var channel: UpdateChannel {
        didSet {
            guard channel != oldValue else { return }
            UserDefaults.standard.set(channel.rawValue, forKey: Keys.channel)
            // An update found on the old channel may not belong to the new one.
            available = nil
            if checksAutomatically { Task { _ = try? await check() } }
        }
    }

    private enum Keys {
        static let auto = "checkUpdatesAutomatically"
        static let channel = "updateChannel"
        static let lastCheck = "lastUpdateCheck"
    }

    /// Newest first. /releases/latest skips pre-releases, so the beta and alpha channels need the list.
    private static let releasesURL = URL(string: "https://api.github.com/repos/outerstudio/trayotp/releases?per_page=30")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private struct UpdateError: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }

    init() {
        UserDefaults.standard.register(defaults: [Keys.auto: true])
        checksAutomatically = UserDefaults.standard.bool(forKey: Keys.auto)
        channel = UserDefaults.standard.string(forKey: Keys.channel).flatMap(UpdateChannel.init(rawValue:))
            ?? Self.bundleVersion.map(UpdateChannel.init) ?? .stable
    }

    var currentVersion: AppVersion? { Self.bundleVersion }

    private static var bundleVersion: AppVersion? {
        AppVersion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    }

    /// Only a real .app can replace itself (not `swift run`).
    private var canInstall: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    // MARK: Check

    /// Quiet check at launch, at most once a day.
    func checkIfDue() {
        guard checksAutomatically, currentVersion != nil else { return }
        let last = UserDefaults.standard.object(forKey: Keys.lastCheck) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > Self.checkInterval else { return }
        Task { _ = try? await check() }
    }

    /// Menu action: checks, then offers the update or says there is none.
    func checkInteractively() async {
        guard !isBusy else { return }
        do {
            if let release = try await check() {
                await offer(release)
            } else {
                Dialogs.info(title: String(localized: "TrayOTP is up to date"),
                             message: String(localized: "You have the latest version (\(currentVersion?.description ?? "?"))."))
            }
        } catch {
            Dialogs.error(error, title: String(localized: "Could not check for updates"))
        }
    }

    /// Returns the newer release, if any, and remembers it in `available`.
    private func check() async throws -> Release? {
        isBusy = true
        defer { isBusy = false }
        var request = URLRequest(url: Self.releasesURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TrayOTP", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError(String(localized: "GitHub answered with status \(status).")) }
        UserDefaults.standard.set(Date(), forKey: Keys.lastCheck)

        // No releases yet is an empty list.
        let releases = try JSONDecoder().decode([Release].self, from: data)
        guard let current = currentVersion, let release = channel.newest(of: releases, after: current) else {
            available = nil
            return nil
        }
        available = release
        return release
    }

    // MARK: Install

    /// Menu action for "Update to vX…" once a check found a release.
    func offerAvailable() async {
        if let release = available { await offer(release) }
    }

    private func offer(_ release: Release) async {
        let message = String(localized: "TrayOTP \(release.version?.description ?? release.tag) is available; you have \(currentVersion?.description ?? "?").")
        // HTML comments (left by release templates) are hidden on GitHub, so drop them here too.
        let notes = (release.notes ?? "")
            .replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let details = notes.isEmpty ? nil : Self.render(notes: notes)
        guard canInstall, release.zip != nil, release.checksum != nil else {
            if Dialogs.confirm(title: String(localized: "Update available"), message: message,
                               button: String(localized: "Open Release Page"), details: details) {
                NSWorkspace.shared.open(release.pageURL)
            }
            return
        }
        guard Dialogs.confirm(title: String(localized: "Update available"),
                              message: message + "\n\n" + String(localized: "TrayOTP will quit and reopen."),
                              button: String(localized: "Install and Relaunch"), details: details)
        else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let staged = try await download(release)
            try launchSwap(staged: staged)
            NSApp.terminate(nil)
        } catch {
            Dialogs.error(error, title: String(localized: "Update failed"))
        }
    }

    /// GitHub release notes (Markdown) as styled text: headings bold, list items as bullets (nested
    /// ones indented, wrapped lines hanging under the text), inline `**bold**`, `*italic*`,
    /// `~~strikethrough~~`, `code`, `[links](…)` and images (as a link to the image), and bare URLs
    /// made clickable.
    private static func render(notes: String) -> NSAttributedString {
        let size = NSFont.smallSystemFontSize
        let body = NSFont.systemFont(ofSize: size)
        let out = NSMutableAttributedString()
        let lines = notes.components(separatedBy: .newlines)
        for (index, raw) in lines.enumerated() {
            let indent = raw.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            var line = raw.trimmingCharacters(in: .whitespaces)
            // Like GitHub: 1–6 `#` then a space, so "#12 fixed …" stays a plain line.
            let hashes = line.prefix { $0 == "#" }.count
            let heading = (1...6).contains(hashes) && line.dropFirst(hashes).first == " "
            // Nesting depth from the leading spaces (GitHub nests list items by 2 or more).
            let level = min(indent / 2, 4)
            var marker = ""
            if heading {
                line = String(line.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("* ") || line.hasPrefix("- ") || line.hasPrefix("+ ") {
                marker = level == 0 ? "• " : "◦ "
                line = String(line.dropFirst(2))
            } else if let number = line.range(of: #"^\d+[.)] "#, options: .regularExpression) {
                marker = String(line[number])
                line = String(line[number.upperBound...])
            }
            let parsed = (try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                ?? AttributedString(line)

            let start = out.length
            out.append(NSAttributedString(string: marker, attributes: [.font: body, .foregroundColor: NSColor.labelColor]))
            for run in parsed.runs {
                let intent = run.inlinePresentationIntent ?? []
                var font = intent.contains(.code)
                    ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
                    : NSFont.systemFont(ofSize: size, weight: heading || intent.contains(.stronglyEmphasized) ? .bold : .regular)
                if intent.contains(.emphasized) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
                var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
                if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                var text = String(parsed[run.range].characters)
                if let image = run.imageURL {
                    // Images can't be shown inline: their alt text (or file name) links to the image.
                    // An image without alt text comes back as U+FFFC (object replacement character).
                    text = text.replacingOccurrences(of: "\u{FFFC}", with: "")
                    if text.isEmpty { text = image.lastPathComponent }
                    if let link = Self.safeLink(image) { attributes[.link] = link }
                } else if let link = run.link.flatMap(Self.safeLink) {
                    attributes[.link] = link
                }
                out.append(NSAttributedString(string: text, attributes: attributes))
            }
            if index < lines.count - 1 { out.append(NSAttributedString(string: "\n")) }

            if !marker.isEmpty || level > 0 {
                let paragraph = NSMutableParagraphStyle()
                paragraph.firstLineHeadIndent = CGFloat(level) * 12
                paragraph.headIndent = paragraph.firstLineHeadIndent + (marker as NSString).size(withAttributes: [.font: body]).width
                out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: start, length: out.length - start))
            }
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: out.string, range: NSRange(location: 0, length: out.length)) {
                guard let url = match.url.flatMap(Self.safeLink),
                      out.attribute(.link, at: match.range.location, effectiveRange: nil) == nil else { continue }
                out.addAttribute(.link, value: url, range: match.range)
            }
        }
        return out
    }

    /// Only web links are clickable in release notes, and always over HTTPS: `http` is upgraded,
    /// any other scheme (`file:`, `mailto:`, custom app schemes…) is left as plain text.
    private static func safeLink(_ url: URL) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.host?.isEmpty == false
        else { return nil }
        switch parts.scheme?.lowercased() {
        case "https": break
        case "http": parts.scheme = "https"
        default: return nil
        }
        return parts.url
    }

    /// Downloads, verifies and unpacks the release; returns the new .app inside a fresh temp folder.
    private func download(_ release: Release) async throws -> URL {
        guard let zip = release.zip, let sum = release.checksum else { throw UpdateError(String(localized: "The release has no app archive.")) }
        let (sumData, _) = try await URLSession.shared.data(from: sum.url)
        guard let expected = Release.parseChecksum(String(decoding: sumData, as: UTF8.self)) else {
            throw UpdateError(String(localized: "The release checksum file is malformed."))
        }
        let (file, _) = try await URLSession.shared.download(from: zip.url)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TrayOTP-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let bundleID = Bundle.main.bundleIdentifier
        let minimum = currentVersion
        return try await Task.detached {
            let hash = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
            guard hash == expected else { throw UpdateError(String(localized: "The download is corrupt (checksum mismatch).")) }

            let archive = dir.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: file, to: archive)
            let out = dir.appendingPathComponent("out")
            try Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, out.path])

            let app = out.appendingPathComponent("TrayOTP.app")
            guard let bundle = Bundle(url: app), bundle.bundleIdentifier == bundleID else {
                throw UpdateError(String(localized: "The archive does not contain TrayOTP."))
            }
            let version = AppVersion(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            guard let version, let minimum, version > minimum else { throw UpdateError(String(localized: "The archive is not newer than this version.")) }
            try Self.run("/usr/bin/codesign", ["--verify", "--strict", app.path])
            return app
        }.value
    }

    /// Starts a detached script that waits for this process to exit, swaps the bundle (rolling back on
    /// failure) and reopens the app.
    private func launchSwap(staged: URL) throws {
        let dest = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: dest.deletingLastPathComponent().path) else {
            throw UpdateError(String(localized: "TrayOTP cannot write to \(dest.deletingLastPathComponent().path). Move it to Applications or download the release manually."))
        }
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        old="$3.old"
        rm -rf "$old"
        if mv "$3" "$old" && mv "$2" "$3"; then rm -rf "$old"; else rm -rf "$3"; mv "$old" "$3"; fi
        rm -rf "$(dirname "$(dirname "$2")")"
        open "$3"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), staged.path, dest.path]
        try process.run()
    }

    private nonisolated static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw UpdateError(String(localized: "\(URL(fileURLWithPath: tool).lastPathComponent) failed: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"))
        }
    }
}
