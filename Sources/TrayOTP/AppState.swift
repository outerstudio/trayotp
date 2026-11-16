import AppKit
import CryptoKit
import LocalAuthentication
import OTPCore
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Screen: Equatable { case list, add, iconPicker(Token.ID) }

    private(set) var tokens: [Token] = []
    private(set) var groups: [TokenGroup] = []
    private(set) var isLocked = true
    private(set) var authInProgress = false
    var screen: Screen = .list
    var lockMessage: String?
    var toast: String?
    /// The token whose next code was just copied, so its row can flash the next code.
    private(set) var copiedNext: Token.ID?
    let icons = IconPackStore()

    /// Require Touch ID / password before codes are shown.
    var requireAuth: Bool {
        didSet { UserDefaults.standard.set(requireAuth, forKey: Keys.requireAuth) }
    }
    /// Minutes the vault stays unlocked after last use. 0 = lock every time the panel opens,
    /// `untilSleep` = no timeout (it still locks on sleep and screen lock).
    var graceMinutes: Int {
        didSet { UserDefaults.standard.set(graceMinutes, forKey: Keys.graceMinutes) }
    }
    static let untilSleep = -1

    /// Whether the Ungrouped section is open. Only matters once groups exist.
    var ungroupedExpanded: Bool {
        didSet { UserDefaults.standard.set(ungroupedExpanded, forKey: Keys.ungroupedExpanded) }
    }

    /// The vault key is wrapped with a master password; unlocking needs it instead of Touch ID.
    private(set) var hasMasterPassword: Bool {
        didSet { UserDefaults.standard.set(hasMasterPassword, forKey: Keys.masterPassword) }
    }

    /// Whether the vault ever locks (Touch ID required, or a master password set).
    var needsUnlock: Bool { requireAuth || hasMasterPassword }

    @ObservationIgnored private let store = VaultStore()
    @ObservationIgnored private var key: SymmetricKey?
    @ObservationIgnored private var lastActive: Date?
    @ObservationIgnored private var nextAutoPrompt = Date.distantPast
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var copiedNextTask: Task<Void, Never>?

    private enum Keys {
        static let requireAuth = "requireAuth"
        static let graceMinutes = "graceMinutes"
        static let masterPassword = "masterPassword"
        static let ungroupedExpanded = "ungroupedExpanded"
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.requireAuth: true, Keys.graceMinutes: 2, Keys.ungroupedExpanded: true])
        ungroupedExpanded = defaults.bool(forKey: Keys.ungroupedExpanded)
        requireAuth = defaults.bool(forKey: Keys.requireAuth)
        graceMinutes = defaults.integer(forKey: Keys.graceMinutes)
        // A UI hint only: the Keychain item decides (openVault corrects it).
        hasMasterPassword = defaults.bool(forKey: Keys.masterPassword)
        observeSystemLock()
    }

    // MARK: Lock

    func panelDidOpen() {
        if !isLocked, needsUnlock, graceMinutes != Self.untilSleep, let lastActive,
           Date().timeIntervalSince(lastActive) > max(5, Double(graceMinutes * 60)) {
            lock()
        }
        if isLocked {
            if hasMasterPassword {
                // The lock screen asks for the password.
            } else if !requireAuth {
                openVault()
            } else if !authInProgress, Date() >= nextAutoPrompt {
                Task { await unlock() }
            }
        }
        touch()
    }

    func unlock() async {
        guard isLocked, !authInProgress, !hasMasterPassword else { return }
        guard requireAuth else { openVault(); return }

        authInProgress = true
        lockMessage = nil
        defer {
            authInProgress = false
            // Closing the Touch ID sheet re-focuses the panel; don't prompt again right away.
            nextAutoPrompt = Date().addingTimeInterval(3)
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lockMessage = error?.localizedDescription ?? "Authentication is not available on this Mac."
            return
        }
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                 localizedReason: "show your one-time codes")
            openVault()
        } catch let e as LAError where [.userCancel, .systemCancel, .appCancel].contains(e.code) {
            lockMessage = nil
        } catch {
            lockMessage = error.localizedDescription
        }
    }

    func lock() {
        tokens = []
        groups = []
        key = nil
        isLocked = true
        screen = .list
        Clipboard.clearIfOurs()
    }

    func unlock(password: String) async {
        guard isLocked, !authInProgress, !password.isEmpty else { return }
        authInProgress = true
        lockMessage = nil
        defer { authInProgress = false }
        do {
            guard let blob = try store.keyItem() else { throw VaultError.keyMissing }
            // scrypt takes ~0.5 s; keep it off the main thread.
            let raw = try await Task.detached { try MasterPassword.unwrap(blob, password: password) }.value
            openVault(key: SymmetricKey(data: raw))
        } catch {
            lockMessage = error.localizedDescription
        }
    }

    private func openVault(key given: SymmetricKey? = nil) {
        do {
            let k = try given ?? store.loadOrCreateKey()
            let vault = try store.load(key: k)
            key = k
            tokens = vault.tokens
            groups = vault.groups
            isLocked = false
            lockMessage = nil
            if given == nil { hasMasterPassword = false }
            touch()
        } catch VaultError.passwordRequired {
            hasMasterPassword = true
            lockMessage = nil
        } catch {
            lockMessage = error.localizedDescription
        }
    }

    // MARK: Master password

    func setMasterPassword() {
        let changing = hasMasterPassword
        Task {
            guard await confirmOwner(changing ? "change the master password" : "set a master password") else { return }
            if !changing {
                guard Dialogs.confirm(
                    title: "Set a master password?",
                    message: "TrayOTP will ask for it instead of Touch ID. If you forget it, your tokens cannot be recovered. Export an encrypted backup first.",
                    button: "Continue")
                else { return }
            }
            var info = "At least 8 characters. Not your Mac password: a long passphrase works best."
            while true {
                guard let password = Dialogs.password(title: changing ? "New master password" : "Master password",
                                                      message: info, confirm: true)
                else { return }
                if password.count >= 8 {
                    await rekey(password: password)
                    return
                }
                info = "Too short. Use at least 8 characters."
            }
        }
    }

    func removeMasterPassword() {
        Task {
            guard await confirmOwner("remove the master password"),
                  Dialogs.confirm(title: "Remove the master password?",
                                  message: "The vault key will be protected by the Keychain and Touch ID only.",
                                  button: "Remove")
            else { return }
            await rekey(password: nil)
        }
    }

    /// Switches to a fresh vault key, optionally wrapped with `password`. A new key means a copy of
    /// the old Keychain item (e.g. in a Time Machine backup) can't open the vault from now on.
    private func rekey(password: String?) async {
        guard !isLocked else { return }
        let newKey = SymmetricKey(size: .bits256)
        let raw = newKey.withUnsafeBytes { Data($0) }
        do {
            let item: Data
            if let password {
                item = try await Task.detached { try MasterPassword.wrap(raw, password: password) }.value
            } else {
                item = raw
            }
            try store.rekey(Vault(tokens: tokens, groups: groups), newKey: newKey, keyItem: item)
            key = newKey
            hasMasterPassword = password != nil
            showToast(password == nil ? "Master password removed" : "Master password set")
        } catch {
            Dialogs.error(error, title: "Could not change the master password")
        }
    }

    // MARK: Stay unlocked

    static let gracePresets = [0, 1, 2, 5, 15, 30, 60, untilSleep]

    static func graceLabel(_ minutes: Int) -> String {
        switch minutes {
        case untilSleep: return "Until Mac Sleeps or Locks"
        case 0: return "Lock Every Time"
        case 1: return "1 Minute"
        case 60: return "1 Hour"
        case let m where m % 60 == 0: return "\(m / 60) Hours"
        default: return "\(minutes) Minutes"
        }
    }

    func setCustomGrace() {
        var info = "Minutes to stay unlocked after you last used TrayOTP (1–1440)."
        let current = graceMinutes > 0 ? String(graceMinutes) : ""
        while let text = Dialogs.text(title: "Stay Unlocked", message: info, value: current, button: "Set") {
            if let minutes = Int(text.trimmingCharacters(in: .whitespaces)), (1...1440).contains(minutes) {
                graceMinutes = minutes
                return
            }
            info = "Enter a whole number of minutes from 1 to 1440 (24 hours)."
        }
    }

    private func touch() { lastActive = Date() }

    private func observeSystemLock() {
        // All observers are registered on the main queue.
        let lockIfNeeded: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.needsUnlock else { return }
                self.lock()
            }
        }
        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: lockIfNeeded))
        observers.append(ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main, using: lockIfNeeded))
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main, using: lockIfNeeded))
    }

    // MARK: Tokens

    func copy(_ token: Token, next: Bool = false) {
        let date = next ? Date().addingTimeInterval(Double(token.period)) : Date()
        guard let code = token.code(at: date) else { return }
        Clipboard.copy(code)
        touch()
        showToast(next ? "Copied next \(token.name)" : "Copied \(token.name)")
        if next { flashNext(token.id) }
    }

    private func flashNext(_ id: Token.ID) {
        copiedNext = id
        copiedNextTask?.cancel()
        copiedNextTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            self?.copiedNext = nil
        }
    }

    func add(_ token: Token) {
        tokens.append(token)
        persist()
        screen = .list
        showToast("Added \(token.name)")
    }

    func delete(_ token: Token) {
        guard Dialogs.confirm(title: "Delete “\(token.name)”?",
                              message: "Make sure you can still sign in to this account another way. This cannot be undone.",
                              button: "Delete")
        else { return }
        Task {
            guard await confirmOwner("delete “\(token.name)”") else { return }
            tokens.removeAll { $0.id == token.id }
            persist()
        }
    }

    /// Asks for Touch ID or the Mac password again, even while the vault is unlocked.
    /// Used before actions that expose or destroy secrets, so a passer-by at an unlocked Mac can't.
    private func confirmOwner(_ reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            Dialogs.info(title: "Can't confirm it's you",
                         message: error?.localizedDescription ?? "Touch ID and password authentication are not available.")
            return false
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    func incrementCounter(_ token: Token) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        tokens[i].counter += 1
        persist()
    }

    // MARK: Groups

    @discardableResult
    func newGroup() -> TokenGroup? {
        guard let name = Dialogs.text(title: "New Group", message: "Name for the group.", value: "", button: "Create")?
            .trimmingCharacters(in: .whitespaces), !name.isEmpty
        else { return nil }
        let group = TokenGroup(name: name)
        groups.append(group)
        persist()
        return group
    }

    func renameGroup(_ group: TokenGroup) {
        guard let i = groups.firstIndex(where: { $0.id == group.id }),
              let name = Dialogs.text(title: "Rename Group", message: "", value: group.name, button: "Rename")?
                .trimmingCharacters(in: .whitespaces), !name.isEmpty
        else { return }
        groups[i].name = name
        persist()
    }

    /// Deletes the group only; its tokens become ungrouped.
    func deleteGroup(_ group: TokenGroup) {
        let count = tokens.filter { $0.groupId == group.id }.count
        if count > 0 {
            guard Dialogs.confirm(title: "Delete group “\(group.name)”?",
                                  message: "Its \(count) token\(count == 1 ? "" : "s") will move to Ungrouped. No tokens are deleted.",
                                  button: "Delete Group")
            else { return }
        }
        groups.removeAll { $0.id == group.id }
        for i in tokens.indices where tokens[i].groupId == group.id { tokens[i].groupId = nil }
        persist()
    }

    func moveGroup(_ group: TokenGroup, by offset: Int) {
        guard let i = groups.firstIndex(where: { $0.id == group.id }) else { return }
        let j = i + offset
        guard groups.indices.contains(j) else { return }
        groups.swapAt(i, j)
        persist()
    }

    func toggleExpanded(_ group: TokenGroup) {
        guard let i = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[i].isExpanded.toggle()
        persist()
    }

    func toggleUngrouped() {
        ungroupedExpanded.toggle()
    }

    func move(_ token: Token, to groupId: String?) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        tokens[i].groupId = groupId
        persist()
    }

    // MARK: Drag and drop

    /// Moves a token next to another one, joining the target's group.
    func moveToken(_ id: Token.ID, nextTo targetId: Token.ID, after: Bool) {
        guard id != targetId,
              let from = tokens.firstIndex(where: { $0.id == id }),
              let target = tokens.first(where: { $0.id == targetId })
        else { return }
        var token = tokens.remove(at: from)
        token.groupId = target.groupId
        guard let to = tokens.firstIndex(where: { $0.id == targetId }) else { return }
        tokens.insert(token, at: after ? to + 1 : to)
        persist()
    }

    /// Moves a token to the end of a group (nil = ungrouped) and opens the group.
    func moveToken(_ id: Token.ID, toGroup groupId: String?) {
        guard let from = tokens.firstIndex(where: { $0.id == id }) else { return }
        var token = tokens.remove(at: from)
        token.groupId = groupId
        let lastInGroup = tokens.lastIndex { $0.groupId == groupId }
        tokens.insert(token, at: lastInGroup.map { $0 + 1 } ?? tokens.endIndex)
        if let i = groups.firstIndex(where: { $0.id == groupId }) { groups[i].isExpanded = true }
        if groupId == nil { ungroupedExpanded = true }
        persist()
    }

    func moveGroup(_ id: String, before targetId: String) {
        guard id != targetId, let from = groups.firstIndex(where: { $0.id == id }) else { return }
        let group = groups.remove(at: from)
        let to = groups.firstIndex { $0.id == targetId } ?? groups.endIndex
        groups.insert(group, at: to)
        persist()
    }

    func moveToNewGroup(_ token: Token) {
        guard let group = newGroup() else { return }
        move(token, to: group.id)
    }

    // MARK: Icons

    func setIcon(_ token: Token, from url: URL) {
        guard let png = IconImage.pngData(contentsOf: url) else {
            Dialogs.info(title: "Can't use this image", message: "“\(url.lastPathComponent)” could not be read as an image.")
            return
        }
        setIcon(token, png: png)
    }

    func pasteIcon(_ token: Token) {
        guard let image = Clipboard.readImage(), let png = IconImage.pngData(from: image) else {
            Dialogs.info(title: "No image on the clipboard", message: "Copy an image first, then choose Paste Icon.")
            return
        }
        setIcon(token, png: png)
    }

    func setIcon(_ token: Token, png: Data?) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        tokens[i].icon = png
        persist()
    }

    func choosePackIcon(_ icon: IconPack.Icon, for token: Token) {
        guard let image = icons.image(for: icon), let png = IconImage.pngData(from: image) else { return }
        setIcon(token, png: png)
        screen = .list
    }

    /// Asks for the website, then fetches its favicon from DuckDuckGo. Nothing is fetched otherwise.
    func fetchFavicon(_ token: Token) {
        var input = Favicon.guessDomain(name: token.name, issuer: token.issuer)
        var domain: String?
        while domain == nil {
            guard let typed = Dialogs.text(
                title: "Fetch icon for “\(token.name)”",
                message: "Website of this service. The icon is downloaded from DuckDuckGo, which will see this domain.",
                value: input, button: "Fetch")
            else { return }
            input = typed
            domain = Favicon.normalizeDomain(typed)
            if domain == nil {
                Dialogs.info(title: "Not a website", message: "Enter a domain like “plurk.com”.")
            }
        }
        guard let domain else { return }

        Task {
            for url in Favicon.urls(for: domain) {
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let image = NSImage(data: data),
                      let png = IconImage.faviconPNG(from: image)
                else { continue }
                setIcon(token, png: png)
                showToast("Icon set for \(token.name)")
                return
            }
            Dialogs.info(title: "No icon found for \(domain)",
                         message: "DuckDuckGo has no icon for this site. Check the domain, or use Set Icon from File….")
        }
    }

    func installIconPack() {
        guard let url = Dialogs.openZip() else { return }
        do {
            try icons.install(zip: url)
            let matched = tokens.filter { icons.icon(for: $0) != nil }.count
            Dialogs.info(title: "Installed \(icons.pack?.name ?? "icon pack")",
                         message: "\(icons.pack?.icons.count ?? 0) icons. \(matched) of \(tokens.count) tokens matched automatically. "
                             + "Right-click a token → Choose Icon from Pack… to pick one yourself.")
        } catch {
            Dialogs.error(error, title: "Icon pack not installed")
        }
    }

    /// Matches image file names to token names or issuers, e.g. "github.png" → "GitHub".
    func importIcons(from folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var byKey: [String: URL] = [:]
        for file in files where IconImage.fileTypes.contains(file.pathExtension.lowercased()) {
            byKey[IconImage.matchKey(file.deletingPathExtension().lastPathComponent)] = file
        }

        var matched = 0
        for i in tokens.indices {
            let keys = [tokens[i].name, tokens[i].issuer ?? ""].map(IconImage.matchKey).filter { !$0.isEmpty }
            guard let file = keys.lazy.compactMap({ byKey[$0] }).first,
                  let png = IconImage.pngData(contentsOf: file)
            else { continue }
            tokens[i].icon = png
            matched += 1
        }
        if matched > 0 { persist() }

        let unmatched = tokens.filter { $0.icon == nil }.map(\.name)
        Dialogs.info(
            title: "Set \(matched) icon\(matched == 1 ? "" : "s")",
            message: byKey.isEmpty
                ? "No images found. Supported: \(IconImage.fileTypes.joined(separator: ", "))."
                : unmatched.isEmpty ? "Every token has an icon."
                : "Still without an icon: \(unmatched.joined(separator: ", ")). Name a file after the token, e.g. “github.png”."
        )
    }

    func move(from source: IndexSet, to destination: Int) {
        tokens.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        guard let key else { return }
        do {
            try store.save(Vault(tokens: tokens, groups: groups), key: key)
        } catch {
            Dialogs.error(error, title: "Could not save")
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: 2FAS import / export

    func importBackup() {
        guard let url = Dialogs.openFile() else { return }
        do {
            let data = try Data(contentsOf: url)
            let app = Importer.detect(data)?.rawValue ?? "the app"
            var password: String?
            if Importer.needsPassword(data) {
                guard let p = Dialogs.password(title: "Backup password",
                                               message: "Enter the password that was set when “\(url.lastPathComponent)” was exported from \(app). This is not your Mac or Keychain password.")
                else { return }
                password = p
            }
            let (format, backup) = try Importer.decode(data, password: password)
            let existing = Set(tokens.map(Self.identity))
            var fresh = backup.tokens.filter { !existing.contains(Self.identity($0)) }
            // Aegis icons arrive as JPEG/PNG/SVG; store them like any other icon.
            for i in fresh.indices {
                fresh[i].icon = fresh[i].icon.flatMap(IconImage.pngData(imported:))
            }
            tokens += Self.mergeGroups(backup.groups, into: &groups, tokens: fresh)
            persist()

            let duplicates = backup.tokens.count - fresh.count
            var notes: [String] = []
            if duplicates > 0 { notes.append("\(duplicates) already existed and were skipped.") }
            if !backup.skipped.isEmpty {
                notes.append("Not imported:\n" + backup.skipped.map { "• \($0)" }.joined(separator: "\n"))
            }
            Dialogs.info(title: "Imported \(fresh.count) token\(fresh.count == 1 ? "" : "s") from \(format.rawValue)",
                         message: notes.joined(separator: "\n\n"))
        } catch {
            Dialogs.error(error, title: "Import failed")
        }
    }

    func exportBackup(as format: BackupFormat, encrypted: Bool) {
        Task {
            guard await confirmOwner("export all your secrets to \(format.rawValue)") else { return }
            exportConfirmed(as: format, encrypted: encrypted)
        }
    }

    private func exportConfirmed(as format: BackupFormat, encrypted: Bool) {
        var password: String?
        if encrypted {
            guard let p = Dialogs.password(title: "Set a backup password",
                                           message: "Choose a new password for this backup file. \(format.rawValue) will ask for it when importing. It is not your Mac or Keychain password.",
                                           confirm: true)
            else { return }
            password = p
        } else {
            guard Dialogs.confirm(title: "Export without encryption?",
                                  message: "Anyone who gets this file can generate your codes. Delete it once you have imported it into \(format.rawValue).",
                                  button: "Export")
            else { return }
        }

        let day = Date().formatted(.iso8601.year().month().day())
        let (name, ext): (String, String) = switch format {
        case .twoFAS: ("TrayOTP-\(day)", "2fas")
        case .aegis: ("aegis-export-TrayOTP-\(day)", "json")
        case .ente, .linkList: ("ente-auth-codes-TrayOTP-\(day)", "txt")
        }
        guard let url = Dialogs.saveFile(name: "\(name).\(ext)", fileExtension: ext, title: "Export to \(format.rawValue)") else { return }
        do {
            let data = try Exporter.encode(.init(tokens: tokens, groups: groups), as: format, password: password)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            Dialogs.info(title: "Exported \(tokens.count) tokens to \(format.rawValue)", message: url.path)
        } catch {
            Dialogs.error(error, title: "Export failed")
        }
    }

    /// Adds imported groups, reusing an existing group with the same name, and points the
    /// imported tokens at the resulting ids.
    private static func mergeGroups(_ incoming: [TokenGroup], into groups: inout [TokenGroup], tokens: [Token]) -> [Token] {
        var remap: [String: String] = [:]
        for g in incoming {
            if let same = groups.first(where: { $0.id == g.id || $0.name.localizedCaseInsensitiveCompare(g.name) == .orderedSame }) {
                remap[g.id] = same.id
            } else {
                groups.append(g)
                remap[g.id] = g.id
            }
        }
        return tokens.map { t in
            var t = t
            t.groupId = t.groupId.flatMap { remap[$0] }
            return t
        }
    }

    private static func identity(_ t: Token) -> String { "\(t.secret)|\(t.account ?? "")" }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                Dialogs.error(error, title: "Launch at login")
            }
        }
    }
}
