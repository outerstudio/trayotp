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
    private(set) var automaticUpdate: Release?
    private var manualUpdate: Release?
    var available: Release? { manualUpdate ?? automaticUpdate }
    private(set) var isBusy = false
    /// True only while an update downloads and installs, not during a mere check.
    private(set) var isInstalling = false

    enum CheckResult: Equatable {
        case upToDate
        case failed(String)
    }
    /// What the last check found; nil before a check, during a check, or when a newer version exists.
    private(set) var checkResult: CheckResult?
    private(set) var lastChecked: Date? = UserDefaults.standard.object(forKey: Keys.lastCheck) as? Date

    var checksAutomatically: Bool {
        didSet {
            guard checksAutomatically != oldValue else { return }
            UserDefaults.standard.set(checksAutomatically, forKey: Keys.auto)
            startAutomaticChecks()
        }
    }

    /// Which releases are offered. Until one is chosen, the channel of the running build, so a
    /// beta build keeps getting betas.
    var channel: UpdateChannel {
        didSet {
            guard channel != oldValue else { return }
            UserDefaults.standard.set(channel.rawValue, forKey: Keys.channel)
            // An update found on the old channel may not belong to the new one.
            automaticUpdate = nil
            manualUpdate = nil
            checkResult = nil
            startAutomaticChecks()
        }
    }

    @ObservationIgnored private var automaticCheckTimer: Timer?
    @ObservationIgnored private var skippedVersions = Set(UserDefaults.standard.stringArray(forKey: Keys.skippedVersions) ?? [])

    private enum Keys {
        static let auto = "checkUpdatesAutomatically"
        static let channel = "updateChannel"
        static let lastCheck = "lastUpdateCheck"
        static let skippedVersions = "skippedUpdateVersions"
    }

    /// Newest first. /releases/latest skips pre-releases, so the beta and alpha channels need the list.
    private static let releasesURL = URL(string: "https://api.github.com/repos/outerstudio/trayotp/releases?per_page=30")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let retryInterval: TimeInterval = 60 * 60

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

    /// Check at launch or after a settings change, then keep checking while the app runs.
    func startAutomaticChecks() {
        scheduleAutomaticCheck(after: 0)
    }

    private func scheduleAutomaticCheck(after delay: TimeInterval) {
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
        guard checksAutomatically, currentVersion != nil else { return }
        automaticCheckTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.checksAutomatically else { return }
                if self.isBusy {
                    self.scheduleAutomaticCheck(after: Self.retryInterval)
                } else {
                    await self.checkForUpdates(automatically: true)
                }
            }
        }
    }

    /// An explicit request from the Updates window can offer a skipped release.
    func checkNow() async {
        await checkForUpdates(automatically: false)
    }

    private func checkForUpdates(automatically: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        checkResult = nil
        do {
            let release = try await newestRelease()
            if automatically {
                automaticUpdate = release.flatMap { skippedVersions.contains($0.tag) ? nil : $0 }
                if manualUpdate?.tag != release?.tag { manualUpdate = nil }
            } else {
                manualUpdate = release
                if automaticUpdate?.tag != release?.tag { automaticUpdate = nil }
            }
            if release == nil { checkResult = .upToDate }
            scheduleAutomaticCheck(after: Self.checkInterval)
        } catch {
            checkResult = .failed(error.localizedDescription)
            scheduleAutomaticCheck(after: Self.retryInterval)
        }
    }

    private func newestRelease() async throws -> Release? {
        var request = URLRequest(url: Self.releasesURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TrayOTP", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError(String(localized: "GitHub answered with status \(status).")) }

        // No releases yet is an empty list.
        let releases = try JSONDecoder().decode([Release].self, from: data)
        let now = Date()
        UserDefaults.standard.set(now, forKey: Keys.lastCheck)
        lastChecked = now

        guard let current = currentVersion else { return nil }
        return channel.newest(of: releases, after: current)
    }

    func skipAutomaticUpdate() {
        guard !isBusy, let release = automaticUpdate else { return }
        skippedVersions.insert(release.tag)
        UserDefaults.standard.set(skippedVersions.sorted(), forKey: Keys.skippedVersions)
        automaticUpdate = nil
    }

    // MARK: Install

    /// Menu action for "Update to vX…" once a check found a release.
    func offerAvailable() async {
        if !isBusy, let release = available { await offer(release) }
    }

    func offerAutomaticUpdate() async {
        if !isBusy, let release = automaticUpdate { await offer(release) }
    }

    private func offer(_ release: Release) async {
        let message = String(localized: "TrayOTP \(release.version?.description ?? release.tag) is available; you have \(currentVersion?.description ?? "?").")
        guard canInstall, release.zip != nil, release.checksum != nil else {
            if Dialogs.confirm(title: String(localized: "Update available"), message: message,
                               button: String(localized: "Open Release Page"), releaseNotes: release.pageURL) {
                NSWorkspace.shared.open(release.pageURL)
            }
            return
        }
        guard Dialogs.confirm(title: String(localized: "Update available"),
                              message: message + "\n\n" + String(localized: "TrayOTP will quit and reopen."),
                              button: String(localized: "Install and Relaunch"), releaseNotes: release.pageURL)
        else { return }
        isBusy = true
        isInstalling = true
        defer { isBusy = false; isInstalling = false }
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
