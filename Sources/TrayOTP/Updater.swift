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

    private enum Keys {
        static let auto = "checkUpdatesAutomatically"
        static let lastCheck = "lastUpdateCheck"
    }

    private static let latestURL = URL(string: "https://api.github.com/repos/outerstudio/trayotp/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private struct UpdateError: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }

    init() {
        UserDefaults.standard.register(defaults: [Keys.auto: true])
        checksAutomatically = UserDefaults.standard.bool(forKey: Keys.auto)
    }

    var currentVersion: AppVersion? {
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
        var request = URLRequest(url: Self.latestURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TrayOTP", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { available = nil; return nil } // no release published yet
        guard status == 200 else { throw UpdateError(String(localized: "GitHub answered with status \(status).")) }
        UserDefaults.standard.set(Date(), forKey: Keys.lastCheck)

        let release = try JSONDecoder().decode(Release.self, from: data)
        guard let latest = release.version, let current = currentVersion, latest > current else {
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
        var message = String(localized: "TrayOTP \(release.version?.description ?? release.tag) is available; you have \(currentVersion?.description ?? "?").")
        if let notes = release.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            message += "\n\n" + String(notes.prefix(600)) + (notes.count > 600 ? "…" : "")
        }
        guard canInstall, release.zip != nil, release.checksum != nil else {
            if Dialogs.confirm(title: String(localized: "Update available"), message: message, button: String(localized: "Open Release Page")) {
                NSWorkspace.shared.open(release.pageURL)
            }
            return
        }
        guard Dialogs.confirm(title: String(localized: "Update available"),
                              message: message + "\n\n" + String(localized: "TrayOTP will quit and reopen."),
                              button: String(localized: "Install and Relaunch"))
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
