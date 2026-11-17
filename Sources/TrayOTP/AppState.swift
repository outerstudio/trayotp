import AppKit
import CryptoKit
import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import OTPCore
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Screen: Equatable { case list, add, iconPicker(Token.ID), favicon(Token.ID), iconEditor(Token.ID) }

    private(set) var tokens: [Token] = []
    private(set) var groups: [TokenGroup] = []
    private(set) var isLocked = true
    private(set) var authInProgress = false
    /// The Touch ID prompt inside the lock screen, while it waits for a finger.
    private(set) var touchIDView: LAAuthenticationView?
    var screen: Screen = .list
    /// The token whose icon screen is open, to select it again back in the list.
    var listReturn: Token.ID?
    /// The image shown in the icon editor screen.
    var iconDraft: IconDraft?
    /// Text read by the camera, for the Add screen to pick up.
    var scannedInput: String?
    /// Bumped after the panel is opened from code; the token list focuses search.
    var focusRequest = 0
    var lockMessage: String?
    var toast: String?
    /// The token whose next code was just copied, so its row can flash the next code.
    private(set) var copiedNext: Token.ID?
    let icons = IconPackStore()
    let updater = Updater()

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

    /// System-wide hotkey that opens the panel. nil = none.
    private(set) var shortcut: Shortcut?

    /// Off: no tray icon; the global shortcut (or opening the app again) shows a floating panel.
    var showsMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showsMenuBarIcon, forKey: Keys.showsMenuBarIcon)
            if showsMenuBarIcon != oldValue { PanelController.shared.menuBarIconChanged() }
        }
    }

    /// Close the panel after a code is copied, giving the focus back to the previous app to paste it.
    var closesAfterCopy: Bool {
        didSet { UserDefaults.standard.set(closesAfterCopy, forKey: Keys.closesAfterCopy) }
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
    /// Whether the panel was closed since it last became key. Our own windows (the color sampler, the
    /// file dialog) take the focus without closing it; getting it back isn't a new open.
    @ObservationIgnored private var panelWasClosed = true
    @ObservationIgnored private var nextAutoPrompt = Date.distantPast
    @ObservationIgnored private var switchToAlert = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var copiedNextTask: Task<Void, Never>?

    private enum Keys {
        static let requireAuth = "requireAuth"
        static let graceMinutes = "graceMinutes"
        static let masterPassword = "masterPassword"
        static let ungroupedExpanded = "ungroupedExpanded"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let closesAfterCopy = "closesAfterCopy"
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.requireAuth: true, Keys.graceMinutes: 2, Keys.ungroupedExpanded: true,
                                     Keys.showsMenuBarIcon: true])
        ungroupedExpanded = defaults.bool(forKey: Keys.ungroupedExpanded)
        requireAuth = defaults.bool(forKey: Keys.requireAuth)
        graceMinutes = defaults.integer(forKey: Keys.graceMinutes)
        // A UI hint only: the Keychain item decides (openVault corrects it).
        hasMasterPassword = defaults.bool(forKey: Keys.masterPassword)
        showsMenuBarIcon = defaults.bool(forKey: Keys.showsMenuBarIcon)
        closesAfterCopy = defaults.bool(forKey: Keys.closesAfterCopy)
        shortcut = Shortcut.load()
        if !GlobalHotKey.shared.register(shortcut) { shortcut = nil }
        // The shortcut is gone (or taken by another app): don't leave TrayOTP with no way in.
        if shortcut == nil { showsMenuBarIcon = true }
        observeSystemLock()
        updater.checkIfDue()
    }

    // MARK: Lock

    func panelDidOpen() {
        if panelWasClosed, !isLocked, needsUnlock, graceMinutes != Self.untilSleep, let lastActive,
           Date().timeIntervalSince(lastActive) > max(5, Double(graceMinutes * 60)) {
            lock()
        }
        panelWasClosed = false
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

    /// A hidden window keeps the inline Touch ID prompt but stops drawing it: cancel it, the next open starts a new one.
    func panelDidHide() {
        panelDidClose()
        guard let touchIDView else { return }
        switchToAlert = false
        touchIDView.context.invalidate()
    }

    /// Unlocks with Touch ID inside the lock screen when the panel is open and Touch ID is available.
    /// The system's alert (Touch ID or the Mac password) opens on a screen of its choosing, on a
    /// multi-screen Mac often not the panel's, so it's only used without Touch ID or with `alert`.
    func unlock(alert: Bool = false) async {
        guard isLocked, !hasMasterPassword else { return }
        guard requireAuth else { openVault(); return }
        if authInProgress {
            // "Use Password…" while the inline prompt waits: cancel it, and its unlock call opens the alert.
            if alert, let touchIDView {
                switchToAlert = true
                touchIDView.context.invalidate()
            }
            return
        }

        authInProgress = true
        lockMessage = nil
        defer { authInProgress = false }

        let reason = String(localized: "show your one-time codes")
        let inline = LAContext()
        if !alert, PanelController.shared.isOpen,
           inline.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            // The view must be paired with the context before evaluating, and on screen to show anything.
            let view = LAAuthenticationView(context: inline, controlSize: .regular)
            touchIDView = view
            defer { touchIDView = nil }
            for _ in 0..<40 where !(view.window?.isVisible == true && view.window?.isKeyWindow == true) {
                try? await Task.sleep(for: .milliseconds(25))
            }
            do {
                _ = try await inline.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                openVault()
                // Touch ID can leave the panel without keyboard focus; take it back for the search field.
                PanelController.shared.focus()
                return
            } catch let e as LAError where [.userCancel, .systemCancel, .appCancel].contains(e.code) {
                lockMessage = nil
                guard switchToAlert else { return }
            } catch {
                lockMessage = error.localizedDescription
                return
            }
        }
        switchToAlert = false

        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use Password")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lockMessage = error?.localizedDescription ?? String(localized: "Authentication is not available on this Mac.")
            return
        }
        // Closing the alert re-focuses the panel; don't prompt again right away.
        defer { nextAutoPrompt = Date().addingTimeInterval(3) }
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            openVault()
            PanelController.shared.focus()
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
        QRCodeWindow.closeAll()
        iconDraft = nil
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
            PanelController.shared.focus()
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
            guard await confirmOwner(changing ? String(localized: "change the master password") : String(localized: "set a master password")) else { return }
            if !changing {
                guard Dialogs.confirm(
                    title: String(localized: "Set a master password?"),
                    message: String(localized: "TrayOTP will ask for it instead of Touch ID. If you forget it, your tokens cannot be recovered. Export an encrypted backup first."),
                    button: String(localized: "Continue"))
                else { return }
            }
            var info = String(localized: "At least 8 characters. Not your Mac password: a long passphrase works best.")
            while true {
                guard let password = Dialogs.password(title: changing ? String(localized: "New master password") : String(localized: "Master password"),
                                                      message: info, confirm: true)
                else { return }
                if password.count >= 8 {
                    await rekey(password: password)
                    return
                }
                info = String(localized: "Too short. Use at least 8 characters.")
            }
        }
    }

    func removeMasterPassword() {
        Task {
            guard await confirmOwner(String(localized: "remove the master password")),
                  Dialogs.confirm(title: String(localized: "Remove the master password?"),
                                  message: String(localized: "The vault key will be protected by the Keychain and Touch ID only."),
                                  button: String(localized: "Remove"))
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
            showToast(password == nil ? String(localized: "Master password removed") : String(localized: "Master password set"))
        } catch {
            Dialogs.error(error, title: String(localized: "Could not change the master password"))
        }
    }

    // MARK: Stay unlocked

    static let gracePresets = [0, 1, 2, 5, 15, 30, 60, untilSleep]

    static func graceLabel(_ minutes: Int) -> String {
        switch minutes {
        case untilSleep: return String(localized: "Until Mac Sleeps or Locks")
        case 0: return String(localized: "Lock Every Time")
        case 1: return String(localized: "1 Minute")
        case 60: return String(localized: "1 Hour")
        case let m where m % 60 == 0: return String(localized: "\(m / 60) Hours")
        default: return String(localized: "\(minutes) Minutes")
        }
    }

    func setCustomGrace() {
        var info = String(localized: "Minutes to stay unlocked after you last used TrayOTP (1–1440).")
        let current = graceMinutes > 0 ? String(graceMinutes) : ""
        while let text = Dialogs.text(title: String(localized: "Stay Unlocked"), message: info, value: current,
                                         button: String(localized: "Set")) {
            if let minutes = Int(text.trimmingCharacters(in: .whitespaces)), (1...1440).contains(minutes) {
                graceMinutes = minutes
                return
            }
            info = String(localized: "Enter a whole number of minutes from 1 to 1440 (24 hours).")
        }
    }

    func editShortcut() {
        guard let choice = Dialogs.shortcut(current: shortcut) else { return }
        if let conflict = choice?.conflict {
            Dialogs.info(title: String(localized: "Shortcut unavailable"), message: conflict)
            return
        }
        guard GlobalHotKey.shared.register(choice) else {
            GlobalHotKey.shared.register(shortcut)
            Dialogs.info(title: String(localized: "Shortcut unavailable"),
                         message: String(localized: "\(choice?.display ?? "") is already used by macOS or another app. Try a different one."))
            return
        }
        shortcut = choice
        Shortcut.save(choice)
        // Without the icon the shortcut was the main way in: bring the icon back.
        if choice == nil { showsMenuBarIcon = true }
    }

    func hideMenuBarIcon() {
        if shortcut == nil {
            guard Dialogs.confirm(title: String(localized: "Set a shortcut first"),
                                  message: String(localized: "Without the menu bar icon, a global shortcut opens TrayOTP."),
                                  button: String(localized: "Set Shortcut…"))
            else { return }
            editShortcut()
            guard shortcut != nil else { return }
        }
        // Explain first, then hide: removing the icon closes its window, and an alert that opens
        // meanwhile doesn't get keyboard focus (Return wouldn't press OK).
        Dialogs.info(title: String(localized: "Hiding the menu bar icon"),
                     message: String(localized: "Press \(shortcut?.display ?? "") to open TrayOTP, or open the app again from Finder or Launchpad. Show Menu Bar Icon in the ⋯ menu brings the icon back."))
        showsMenuBarIcon = false
    }

    /// Marks the vault as in use now; the Stay Unlocked timeout counts from the last call.
    func touch() { lastActive = Date() }

    /// The panel went off screen or the app went to the background: Stay Unlocked counts from now.
    private func panelDidClose() {
        if !panelWasClosed { touch() }
        panelWasClosed = true
    }

    private func observeSystemLock() {
        // All observers are registered on the main queue.
        let lockIfNeeded: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.needsUnlock else { return }
                self.lock()
            }
        }
        // Clicking another app closes the menu bar panel; the window may not report going off screen.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.panelDidClose() } })
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
        if closesAfterCopy {
            PanelController.shared.close()
            return
        }
        showToast(next ? String(localized: "Copied next \(token.name)") : String(localized: "Copied \(token.name)"))
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
        var token = token
        Self.stampIfLookalike(&token, existing: tokens)
        tokens.append(token)
        persist()
        screen = .list
        showToast(String(localized: "Added \(token.name)"))
    }

    func delete(_ token: Token) {
        guard Dialogs.confirm(title: String(localized: "Delete “\(token.name)”?"),
                              message: String(localized: "Make sure you can still sign in to this account another way. This cannot be undone."),
                              button: String(localized: "Delete"))
        else { return }
        Task {
            guard await confirmOwner(String(localized: "delete “\(token.name)”")) else { return }
            tokens.removeAll { $0.id == token.id }
            persist()
        }
    }

    /// Asks for Touch ID or the Mac password again, even while the vault is unlocked.
    /// Used before actions that expose or destroy secrets, so a passer-by at an unlocked Mac can't.
    private func confirmOwner(_ reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use Password")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            Dialogs.info(title: String(localized: "Can't confirm it's you"),
                         message: error?.localizedDescription ?? String(localized: "Touch ID and password authentication are not available."))
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
        guard let name = Dialogs.text(title: String(localized: "New Group"), message: String(localized: "Name for the group."),
                                     value: "", button: String(localized: "Create"))?
            .trimmingCharacters(in: .whitespaces), !name.isEmpty
        else { return nil }
        let group = TokenGroup(name: name)
        groups.append(group)
        persist()
        return group
    }

    /// Edits the service and account names. The secret, and so the code, stays the same.
    func edit(_ token: Token) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }),
              let values = Dialogs.fields(title: String(localized: "Edit “\(token.name)”"),
                                          message: String(localized: "The code stays the same."),
                                          fields: [(String(localized: "Service"), token.name),
                                                   (String(localized: "Account"), token.account ?? "")],
                                          button: String(localized: "Save"))?
                .map({ $0.trimmingCharacters(in: .whitespaces) })
        else { return }
        let (name, account) = (values[0], values[1])
        guard !name.isEmpty else { return }
        // The issuer usually repeats the service name; keep them in step so exports carry the new name.
        if tokens[i].issuer == tokens[i].name { tokens[i].issuer = name }
        tokens[i].name = name
        tokens[i].account = account.isEmpty ? nil : account
        persist()
    }

    func renameGroup(_ group: TokenGroup) {
        guard let i = groups.firstIndex(where: { $0.id == group.id }),
              let name = Dialogs.text(title: String(localized: "Rename Group"), message: "", value: group.name,
                                      button: String(localized: "Rename"))?
                .trimmingCharacters(in: .whitespaces), !name.isEmpty
        else { return }
        groups[i].name = name
        persist()
    }

    /// Deletes the group only; its tokens become ungrouped.
    func deleteGroup(_ group: TokenGroup) {
        let count = tokens.filter { $0.groupId == group.id }.count
        if count > 0 {
            guard Dialogs.confirm(title: String(localized: "Delete group “\(group.name)”?"),
                                  message: count == 1
                                      ? String(localized: "Its token will move to Ungrouped. No tokens are deleted.")
                                      : String(localized: "Its \(count) tokens will move to Ungrouped. No tokens are deleted."),
                                  button: String(localized: "Delete Group"))
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

    /// Opens the icon editor on an image, to adjust zoom and background before using it.
    func editIcon(_ token: Token, image: NSImage) {
        iconDraft = IconDraft(image: image)
        listReturn = token.id
        screen = .iconEditor(token.id)
    }

    /// Asks for an image file, then opens the icon editor. The file dialog closes the panel; Dialogs reopens it.
    func chooseIconFile(_ token: Token) {
        let url = Dialogs.openImage()
        listReturn = token.id
        if let url {
            if let image = IconImage.load(url), image.size.width > 0 {
                editIcon(token, image: image)
            } else {
                Dialogs.info(title: String(localized: "Can't use this image"),
                             message: String(localized: "“\(url.lastPathComponent)” could not be read as an image."))
            }
        }
    }

    func pasteIcon(_ token: Token) {
        guard let image = Clipboard.readImage(), image.size.width > 0 else {
            Dialogs.info(title: String(localized: "No image on the clipboard"),
                         message: String(localized: "Copy an image first, then choose Paste Icon."))
            return
        }
        editIcon(token, image: image)
    }

    func setIcon(_ token: Token, png: Data?) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        tokens[i].icon = png
        persist()
    }

    func choosePackIcon(_ icon: IconPack.Icon, for token: Token) {
        guard let image = icons.image(for: icon) else { return }
        editIcon(token, image: image)
    }

    /// Downloads a site's favicon, trying the domain with and without "www.". Nil if there is none.
    static func downloadFavicon(domain: String) async -> NSImage? {
        for url in Favicon.urls(for: domain) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = NSImage(data: data), image.size.width > 0
            else { continue }
            return image
        }
        return nil
    }

    func useIcon(_ png: Data, for token: Token) {
        setIcon(token, png: png)
        screen = .list
        showToast(String(localized: "Icon set for \(token.name)"))
    }

    func installIconPack() {
        guard let url = Dialogs.openZip() else { return }
        do {
            try icons.install(zip: url)
            let matched = tokens.filter { icons.icon(for: $0) != nil }.count
            let iconCount = icons.pack?.icons.count ?? 0, tokenCount = tokens.count
            Dialogs.info(title: String(localized: "Installed \(icons.pack?.name ?? "")"),
                         message: String(localized: "\(iconCount) icons. \(matched) of \(tokenCount) tokens matched automatically. Right-click a token → Choose Icon from Pack… to pick one yourself."))
        } catch {
            Dialogs.error(error, title: String(localized: "Icon pack not installed"))
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
            title: matched == 1 ? String(localized: "Set 1 icon") : String(localized: "Set \(matched) icons"),
            message: byKey.isEmpty
                ? String(localized: "No images found. Supported: \(IconImage.fileTypes.joined(separator: ", ")).")
                : unmatched.isEmpty ? String(localized: "Every token has an icon.")
                : String(localized: "Still without an icon: \(unmatched.joined(separator: ", ")). Name a file after the token, e.g. “github.png”.")
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
            Dialogs.error(error, title: String(localized: "Could not save"))
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

    // MARK: Import / export

    func importBackup() {
        guard let url = Dialogs.openFile() else { return }
        do {
            var data = try Data(contentsOf: url)
            // A photo or screenshot of a QR code, e.g. Google Authenticator's transfer code taken with another phone.
            if let image = NSImage(data: data) {
                let messages = QRReader.messages(in: image)
                guard !messages.isEmpty else { throw ImportError.unsupported(String(localized: "No QR code found in “\(url.lastPathComponent)”.")) }
                data = Data(messages.joined(separator: "\n").utf8)
            }
            importBackup(data, name: "“\(url.lastPathComponent)”")
        } catch {
            Dialogs.error(error, title: String(localized: "Import failed"))
        }
    }

    /// Reads a QR code with the camera. Google Authenticator transfer codes are imported right away;
    /// anything else goes to the Add screen, as if it had been pasted.
    func scanWithCamera() {
        PanelController.shared.hide()
        Task {
            do {
                guard let text = try await CameraScanner.scan() else {
                    PanelController.shared.reopen()
                    return
                }
                if GoogleAuthenticator.isMigrationLink(text) {
                    importBackup(Data(text.utf8), name: String(localized: "the scanned QR code"))
                    screen = .list
                } else {
                    scannedInput = text
                    screen = .add
                }
                PanelController.shared.reopen()
            } catch {
                Dialogs.error(error, title: String(localized: "Can't use the camera"))
            }
        }
    }

    /// Imports pasted text, e.g. Google Authenticator `otpauth-migration://` links.
    func importText(_ text: String) {
        importBackup(Data(text.utf8), name: String(localized: "the pasted link"))
        screen = .list
    }

    private func importBackup(_ data: Data, name: String) {
        do {
            let app = Importer.detect(data)?.displayName ?? String(localized: "the app")
            var password: String?
            if Importer.needsPassword(data) {
                guard let p = Dialogs.password(title: String(localized: "Backup password"),
                                               message: String(localized: "Enter the password that was set when \(name) was exported from \(app). This is not your Mac or Keychain password."))
                else { return }
                password = p
            }
            let (format, backup) = try Importer.decode(data, password: password)

            // Skip tokens we already have, and repeats within the file (same secret and account).
            var seen = Set(tokens.map(Self.identity))
            var fresh = backup.tokens.filter { seen.insert(Self.identity($0)).inserted }
            // Aegis icons arrive as JPEG/PNG/SVG; store them like any other icon.
            for i in fresh.indices {
                fresh[i].icon = fresh[i].icon.flatMap(IconImage.pngData(imported:))
            }
            // Same name and account as a token we have, but a different secret: keep both, tell them apart
            // by the time the new one was added, and say so.
            let existing = tokens
            var lookalikes: [Token] = []
            for i in fresh.indices {
                if Self.stampIfLookalike(&fresh[i], existing: existing) { lookalikes.append(fresh[i]) }
            }
            tokens += Self.mergeGroups(backup.groups, into: &groups, tokens: fresh)
            persist()

            let duplicates = backup.tokens.count - fresh.count
            var notes: [String] = []
            if duplicates > 0 { notes.append(String(localized: "\(duplicates) already existed and were skipped.")) }
            if !lookalikes.isEmpty {
                notes.append(String(localized: "Same name and account as a token you already have, but a different secret. Both are kept; the new one is marked with the time it was added. Delete the old one once the new one works:") + "\n"
                             + lookalikes.map { "• \($0.name)\($0.account.map { ": \($0)" } ?? "")" }.joined(separator: "\n"))
            }
            if !backup.skipped.isEmpty {
                notes.append(String(localized: "Not imported:") + "\n" + backup.skipped.map { "• \($0)" }.joined(separator: "\n"))
            }
            let count = fresh.count, source = format.displayName
            Dialogs.info(title: count == 1 ? String(localized: "Imported 1 token from \(source)")
                                           : String(localized: "Imported \(count) tokens from \(source)"),
                         message: notes.joined(separator: "\n\n"))
        } catch {
            Dialogs.error(error, title: String(localized: "Import failed"))
        }
    }

    func exportBackup(as format: BackupFormat, encrypted: Bool) {
        Task {
            guard await confirmOwner(String(localized: "export all your secrets to \(format.displayName)")) else { return }
            exportConfirmed(as: format, encrypted: encrypted)
        }
    }

    /// Shows Google Authenticator transfer QR codes, to scan with its Transfer accounts → Import accounts.
    func exportToGoogle() {
        Task {
            guard await confirmOwner(String(localized: "show all your secrets as QR codes for Google Authenticator")) else { return }
            let codes = GoogleAuthenticator.encode(.init(tokens: tokens, groups: groups))
            let left = Exporter.unsupported(tokens, in: .googleAuthenticator)
            if !left.isEmpty {
                let names = left.map(\.name).joined(separator: ", ")
                guard !codes.isEmpty else {
                    Dialogs.info(title: String(localized: "Nothing to export to Google Authenticator"),
                                 message: String(localized: "Google Authenticator only takes 30-second codes with 6 or 8 digits, and no Steam codes. None of your tokens fit: \(names)"))
                    return
                }
                let leftCount = left.count
                guard Dialogs.confirm(title: leftCount == 1 ? String(localized: "1 token will be left out")
                                                            : String(localized: "\(leftCount) tokens will be left out"),
                                      message: String(localized: "Google Authenticator only takes 30-second codes with 6 or 8 digits, and no Steam codes. Left out: \(names)"),
                                      button: String(localized: "Continue"))
                else { return }
            }
            let count = tokens.count - left.count, codeCount = codes.count
            QRCodeWindow.show(
                title: String(localized: "Export to Google Authenticator"),
                instructions: codeCount > 1
                    ? String(localized: "In Google Authenticator, open ⋮ → Transfer accounts → Import accounts and scan each QR code in turn (\(count) accounts in \(codeCount) codes). Anyone who sees these codes can copy your accounts.")
                    : count == 1
                    ? String(localized: "In Google Authenticator, open ⋮ → Transfer accounts → Import accounts and scan this QR code (1 account). Anyone who sees these codes can copy your accounts.")
                    : String(localized: "In Google Authenticator, open ⋮ → Transfer accounts → Import accounts and scan this QR code (\(count) accounts). Anyone who sees these codes can copy your accounts."),
                codes: codes)
        }
    }

    private func exportConfirmed(as format: BackupFormat, encrypted: Bool) {
        var password: String?
        if encrypted {
            guard let p = Dialogs.password(title: String(localized: "Set a backup password"),
                                           message: String(localized: "Choose a new password for this backup file. \(format.displayName) will ask for it when importing. It is not your Mac or Keychain password."),
                                           confirm: true)
            else { return }
            password = p
        } else {
            guard Dialogs.confirm(title: String(localized: "Export without encryption?"),
                                  message: String(localized: "Anyone who gets this file can generate your codes. Delete it once you have imported it into \(format.displayName)."),
                                  button: String(localized: "Export"))
            else { return }
        }

        let day = Date().formatted(.iso8601.year().month().day())
        let (name, ext): (String, String) = switch format {
        case .twoFAS: ("TrayOTP-\(day)", "2fas")
        case .aegis: ("aegis-export-TrayOTP-\(day)", "json")
        case .ente: ("ente-auth-codes-TrayOTP-\(day)", "txt")
        case .bitwarden: ("bitwarden_export_TrayOTP-\(day)", "json")
        default: ("otpauth-links-TrayOTP-\(day)", "txt")
        }
        guard let url = Dialogs.saveFile(name: "\(name).\(ext)", fileExtension: ext, title: String(localized: "Export to \(format.displayName)")) else { return }
        do {
            let data = try Exporter.encode(.init(tokens: tokens, groups: groups), as: format, password: password)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            let left = Exporter.unsupported(tokens, in: format)
            let names = left.map(\.name).joined(separator: ", "), count = tokens.count - left.count
            let note = left.isEmpty ? "" : "\n\n" + String(localized: "Left out (\(format.displayName) doesn't support counter-based HOTP codes): \(names)")
            Dialogs.info(title: count == 1 ? String(localized: "Exported 1 token to \(format.displayName)")
                                           : String(localized: "Exported \(count) tokens to \(format.displayName)"),
                         message: url.path + note)
        } catch {
            Dialogs.error(error, title: String(localized: "Export failed"))
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

    /// If a token with the same name and account but another secret exists, appends the time added
    /// ("GitHub 2026-11-17 23:40") so the two can be told apart. Returns whether it did.
    @discardableResult
    private static func stampIfLookalike(_ token: inout Token, existing: [Token], now: Date = Date()) -> Bool {
        let key = { (t: Token) in "\(t.name)|\(t.account ?? "")".lowercased() }
        guard existing.contains(where: { key($0) == key(token) && $0.secret != token.secret }) else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        // Keep the service in the issuer, so icon matching still finds it.
        if token.issuer == nil { token.issuer = token.name }
        token.name += " " + formatter.string(from: now)
        return true
    }

    // MARK: Language

    /// The translations in Support/Localizations, plus English.
    static let languages = ["en", "de", "es", "fr", "it", "ja", "ko", "pt-BR", "zh-Hans", "zh-Hant"]

    /// The language chosen in the ⋯ menu, or nil to follow the system (English if it isn't translated).
    /// Stored as this app's AppleLanguages, which Foundation reads at launch.
    var language: String? {
        get {
            let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            return (domain?["AppleLanguages"] as? [String])?.first
        }
        set {
            if let newValue {
                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
            if Dialogs.confirm(title: String(localized: "Restart TrayOTP?"),
                               message: String(localized: "The new language is used after TrayOTP restarts."),
                               button: String(localized: "Restart Now")) {
                relaunch()
            }
        }
    }

    /// The language's name in that language, e.g. "Deutsch".
    static func languageName(_ code: String) -> String {
        Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }

    /// Quits and reopens the app once this process has exited.
    private func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; open \"$2\"", "sh",
                             String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                Dialogs.error(error, title: String(localized: "Launch at login"))
            }
        }
    }
}
