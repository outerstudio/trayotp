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

    private(set) var tokens: [Token] = [] { didSet { updateMenuBarRing() } }
    private(set) var groups: [TokenGroup] = []
    private(set) var isLocked = true { didSet { updateMenuBarRing() } }
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
    /// The row to shake after a copy that leaves the panel open; `shakeCount` changes on every request.
    private(set) var shakenRow: Token.ID?
    private(set) var shakeCount = 0
    /// The shake is for the row's next-code area (a next code was copied) rather than the whole row.
    private(set) var shakesNext = false
    let icons = IconPackStore()
    let updater = Updater()
    let iconSpinner = IconSpinner()
    let menuBarRing = MenuBarRing()

    /// Minutes the vault stays unlocked after last use. 0 = lock every time the panel opens,
    /// `untilSleep` = no timeout (it still locks on sleep and screen lock),
    /// `untilLocked` = no timeout and no lock on sleep: only the Lock button (or quitting) locks it.
    var graceMinutes: Int {
        didSet {
            UserDefaults.standard.set(graceMinutes, forKey: Keys.graceMinutes)
            updateMenuBarRing()
        }
    }
    static let untilSleep = -1
    static let untilLocked = -2

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
    /// Clear a copied code from the clipboard after 30 seconds, if the clipboard still holds it.
    var clearsClipboard: Bool {
        didSet { UserDefaults.standard.set(clearsClipboard, forKey: Keys.clearsClipboard) }
    }
    /// When codes are masked: `hover` and `click` hide every code until revealed that way.
    enum CodeHiding: String, CaseIterable {
        case never, hover, click
    }
    var codeHiding: CodeHiding {
        didSet {
            UserDefaults.standard.set(codeHiding.rawValue, forKey: Keys.codeHiding)
            hideAllCodes()
        }
    }
    /// Keeps the panel out of screen sharing, screenshots and recordings.
    var hidesFromScreenSharing: Bool {
        didSet { UserDefaults.standard.set(hidesFromScreenSharing, forKey: Keys.hidesFromScreenSharing) }
    }
    /// Tokens whose masked code is showing after a click or copy; they hide again after `revealSeconds`.
    private(set) var revealed: Set<UUID> = []
    @ObservationIgnored private var revealTasks: [UUID: Task<Void, Never>] = [:]
    private static let revealSeconds = 10.0

    /// Whether the token's code is masked unless revealed.
    func hidesCode(_ token: Token) -> Bool { codeHiding != .never || token.hidesCode == true }

    func reveal(_ token: Token) {
        revealed.insert(token.id)
        revealTasks[token.id]?.cancel()
        revealTasks[token.id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.revealSeconds))
            guard !Task.isCancelled else { return }
            self?.revealed.remove(token.id)
            self?.revealTasks[token.id] = nil
        }
    }

    func hideAllCodes() {
        revealTasks.values.forEach { $0.cancel() }
        revealTasks = [:]
        revealed = []
    }

    func setHidesCode(_ token: Token, _ hides: Bool) {
        guard let i = tokens.firstIndex(where: { $0.id == token.id }) else { return }
        tokens[i].hidesCode = hides ? true : nil
        persist()
    }

    static func codeHidingLabel(_ mode: CodeHiding) -> String {
        switch mode {
        case .never: String(localized: "Never")
        case .hover: String(localized: "Until Hover")
        case .click: String(localized: "Until Click")
        }
    }

    /// Days before the app suggests a fresh backup; 0 turns the reminder off.
    var backupReminderDays: Int {
        didSet { UserDefaults.standard.set(backupReminderDays, forKey: Keys.backupReminderDays) }
    }
    /// The folder **Back Up Now** writes to, chosen once.
    private(set) var backupFolder: URL? {
        didSet { UserDefaults.standard.set(backupFolder?.path, forKey: Keys.backupFolder) }
    }
    private(set) var lastBackup: Date? {
        didSet { UserDefaults.standard.set(lastBackup, forKey: Keys.lastBackup) }
    }
    /// Pure black panel background instead of the translucent material: OLED pixels switch off.
    var deepBlack: Bool {
        didSet { UserDefaults.standard.set(deepBlack, forKey: Keys.deepBlack) }
    }
    /// When the menu bar icon's ring stops counting down with the codes.
    var menuBarCountdown: MenuBarCountdown {
        didSet {
            UserDefaults.standard.set(menuBarCountdown.rawValue, forKey: Keys.menuBarCountdown)
            updateMenuBarRing()
        }
    }

    /// The vault key is wrapped with a master password; unlocking needs it instead of Touch ID.
    private(set) var hasMasterPassword: Bool {
        didSet { UserDefaults.standard.set(hasMasterPassword, forKey: Keys.masterPassword) }
    }

    /// Proves the master password (see `ExportPassword`); nil until one is set.
    private(set) var exportVerifier: Data?
    /// The user chose to go without a master password, after typing the confirmation phrase.
    private(set) var exportPasswordSkipped: Bool {
        didSet { UserDefaults.standard.set(exportPasswordSkipped, forKey: Keys.exportPasswordSkipped) }
    }
    /// Days between asking for the password again, so it isn't forgotten. 0 = never.
    var passwordReminderDays: Int {
        didSet { UserDefaults.standard.set(passwordReminderDays, forKey: Keys.passwordReminderDays) }
    }

    /// Whether a password, the master or the export one, stands in front of exports and deletes.
    var hasPasswordGate: Bool { hasMasterPassword || exportVerifier != nil }

    @ObservationIgnored private let store = VaultStore()
    @ObservationIgnored private var key: SymmetricKey?
    @ObservationIgnored private var lastActive: Date?
    /// Whether the panel was closed since it last became key. Our own windows (the color sampler, the
    /// file dialog) take the focus without closing it; getting it back isn't a new open.
    @ObservationIgnored private var panelWasClosed = true
    @ObservationIgnored private var nextAutoPrompt = Date.distantPast
    @ObservationIgnored private var passwordPromptActive = false
    @ObservationIgnored private var reminderSnoozedUntil = Date.distantPast
    @ObservationIgnored private var backupSnoozedUntil = Date.distantPast
    /// When each `Grace` ends; every use pushes its end back (a debounce).
    @ObservationIgnored private var graceUntil: [Grace: Date] = [:]
    @ObservationIgnored private var switchToAlert = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var copiedNextTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?

    private enum Keys {
        static let requireAuth = "requireAuth"  // legacy: migrated into graceMinutes
        static let graceMinutes = "graceMinutes"
        static let masterPassword = "masterPassword"
        static let exportPasswordSkipped = "exportPasswordSkipped"
        static let passwordReminderDays = "passwordReminderDays"
        static let lastPasswordCheck = "lastPasswordCheck"
        static let ungroupedExpanded = "ungroupedExpanded"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let closesAfterCopy = "closesAfterCopy"
        static let clearsClipboard = "clearsClipboard"
        static let codeHiding = "codeHiding"
        static let hidesFromScreenSharing = "hidesFromScreenSharing"
        static let backupReminderDays = "backupReminderDays"
        static let backupFolder = "backupFolder"
        static let lastBackup = "lastBackup"
        static let backupReminderSince = "backupReminderSince"
        static let deepBlack = "deepBlack"
        static let menuBarCountdown = "menuBarCountdown"
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.graceMinutes: 2, Keys.ungroupedExpanded: true,
                                     Keys.showsMenuBarIcon: true, Keys.clearsClipboard: true, Keys.backupReminderDays: 30, Keys.passwordReminderDays: 30])
        ungroupedExpanded = defaults.bool(forKey: Keys.ungroupedExpanded)
        // The Require Unlock switch became the Until I Lock It option of Stay Unlocked.
        if defaults.object(forKey: Keys.requireAuth) as? Bool == false {
            defaults.set(Self.untilLocked, forKey: Keys.graceMinutes)
        }
        defaults.removeObject(forKey: Keys.requireAuth)
        graceMinutes = defaults.integer(forKey: Keys.graceMinutes)
        // A UI hint only: the Keychain item decides (openVault corrects it).
        hasMasterPassword = defaults.bool(forKey: Keys.masterPassword)
        exportPasswordSkipped = defaults.bool(forKey: Keys.exportPasswordSkipped)
        passwordReminderDays = defaults.integer(forKey: Keys.passwordReminderDays)
        showsMenuBarIcon = defaults.bool(forKey: Keys.showsMenuBarIcon)
        closesAfterCopy = defaults.bool(forKey: Keys.closesAfterCopy)
        clearsClipboard = defaults.bool(forKey: Keys.clearsClipboard)
        codeHiding = defaults.string(forKey: Keys.codeHiding).flatMap(CodeHiding.init(rawValue:)) ?? .never
        hidesFromScreenSharing = defaults.bool(forKey: Keys.hidesFromScreenSharing)
        backupReminderDays = defaults.integer(forKey: Keys.backupReminderDays)
        backupFolder = defaults.string(forKey: Keys.backupFolder).map { URL(fileURLWithPath: $0, isDirectory: true) }
        lastBackup = defaults.object(forKey: Keys.lastBackup) as? Date
        deepBlack = defaults.bool(forKey: Keys.deepBlack)
        menuBarCountdown = defaults.string(forKey: Keys.menuBarCountdown).flatMap(MenuBarCountdown.init(rawValue:))
            ?? .untilGraceEnds
        shortcut = Shortcut.load()
        if !GlobalHotKey.shared.register(shortcut) { shortcut = nil }
        // The shortcut is gone (or taken by another app): don't leave TrayOTP with no way in.
        if shortcut == nil { showsMenuBarIcon = true }
        observeSystemLock()
        updater.checkIfDue()
    }

    // MARK: Lock

    func panelDidOpen() {
        if panelWasClosed, !isLocked, graceMinutes >= 0, let lastActive,
           Date().timeIntervalSince(lastActive) > max(5, Double(graceMinutes * 60)) {
            lock()
        }
        panelWasClosed = false
        refreshLaunchAtLogin()
        updateMenuBarRing()
        if isLocked {
            if hasMasterPassword {
                // The lock screen asks for the password.
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
        exportVerifier = nil
        graceUntil = [:]
        isLocked = true
        screen = .list
        Clipboard.clearIfOurs()
        QRCodeWindow.closeAll()
        hideAllCodes()
        iconDraft = nil
        // Now and then the icon's ring turns somewhere new, as a small surprise.
        iconSpinner.maybeTurn(chance: 0.25)
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
            lastPasswordCheck = Date()
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
            exportVerifier = vault.exportVerifier
            isLocked = false
            lockMessage = nil
            if given == nil { hasMasterPassword = false }
            touch()
            checkPasswordPrompts()
        } catch VaultError.passwordRequired {
            hasMasterPassword = true
            lockMessage = nil
        } catch {
            lockMessage = error.localizedDescription
        }
    }

    // MARK: Master password

    /// Sets the first master password. It gates exports and deletes; Touch ID still unlocks the vault.
    func setMasterPassword() {
        Task { _ = await chooseMasterPassword() }
    }

    func changeMasterPassword() {
        Task {
            guard await authorize(String(localized: "change the master password")) != nil else { return }
            _ = await chooseMasterPassword(title: String(localized: "New master password"))
        }
    }

    func removeMasterPassword() {
        Task {
            guard await authorize(String(localized: "remove the master password")) != nil, confirmSkip() else { return }
            let old = exportVerifier
            exportVerifier = nil
            if hasMasterPassword {
                guard await rekey(password: nil) else { exportVerifier = old; return }
            } else {
                persist()
            }
            showToast(String(localized: "Master password removed"))
        }
    }

    /// Switches between unlocking with Touch ID and typing the master password. With the password, the
    /// vault key is wrapped with it too, so the Keychain item alone can't open the vault.
    func setUnlocksWithPassword(_ on: Bool) {
        Task {
            guard let password = await authorize(on ? String(localized: "unlock with the master password instead of Touch ID")
                                                    : String(localized: "unlock with Touch ID again"))?.password
            else { return }
            if on {
                guard Dialogs.confirm(
                    title: String(localized: "Unlock with your master password?"),
                    message: String(localized: "TrayOTP will ask for it instead of Touch ID. If you forget it, your tokens cannot be recovered. Export an encrypted backup first."),
                    button: String(localized: "Continue"))
                else { return }
            } else if exportVerifier == nil {
                // Keep the password in front of exports once the vault key no longer depends on it.
                do {
                    exportVerifier = try await Task.detached { try ExportPassword.makeVerifier(password: password) }.value
                } catch {
                    Dialogs.error(error, title: String(localized: "Could not change the master password"))
                    return
                }
            }
            await rekey(password: on ? password : nil)
        }
    }

    /// Switches to a fresh vault key, optionally wrapped with `password`. A new key means a copy of
    /// the old Keychain item (e.g. in a Time Machine backup) can't open the vault from now on.
    /// False if it failed (the error is shown) or the vault locked meanwhile: nothing changed.
    @discardableResult
    private func rekey(password: String?) async -> Bool {
        guard !isLocked else { return false }
        let newKey = SymmetricKey(size: .bits256)
        let raw = newKey.withUnsafeBytes { Data($0) }
        do {
            let item: Data
            if let password {
                item = try await Task.detached { try MasterPassword.wrap(raw, password: password) }.value
            } else {
                item = raw
            }
            try store.rekey(Vault(tokens: tokens, groups: groups, exportVerifier: exportVerifier), newKey: newKey, keyItem: item)
            key = newKey
            hasMasterPassword = password != nil
            return true
        } catch {
            Dialogs.error(error, title: String(localized: "Could not change the master password"))
            return false
        }
    }

    /// What `authorize` learned: the password the user typed, or nil when Touch ID or the Mac password was used.
    struct Authorization { var password: String? }

    /// Actions that skip the password prompt for a while after it was last passed, in seconds:
    /// deleting for 2 minutes, showing token QR codes for 3.
    private enum Grace: TimeInterval {
        case delete = 120, qr = 180
    }

    private func extendGrace(_ grace: Grace) {
        graceUntil[grace] = Date().addingTimeInterval(grace.rawValue)
    }

    @ObservationIgnored private var lastPasswordCheck: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastPasswordCheck) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastPasswordCheck) }
    }

    /// The verifier, or for a vault from before it, the wrapped vault key. Both open with the password.
    private func gateVerifier() -> Data? {
        if let exportVerifier { return exportVerifier }
        return hasMasterPassword ? try? store.keyItem() : nil
    }

    private var gateName: String { String(localized: "master password") }

    private nonisolated static func check(_ verifier: Data, password: String) async -> Bool {
        // scrypt takes ~0.5 s; keep it off the main thread.
        await Task.detached { ExportPassword.verify(verifier, password: password) }.value
    }

    /// Asks for the password before an action that exposes or destroys secrets. A Touch ID prompt
    /// would let someone use a sleeper's finger, so the password is typed. Without one (the user
    /// skipped it), it falls back to `confirmOwner`. `grace` skips the prompt for a while after
    /// the last time it was passed, for deleting or showing several tokens in a row.
    private func authorize(_ reason: String, grace: Grace? = nil) async -> Authorization? {
        if let grace, let until = graceUntil[grace], Date() < until {
            extendGrace(grace)
            return Authorization(password: nil)
        }
        guard let verifier = gateVerifier() else {
            return await confirmOwner(reason) ? Authorization(password: nil) : nil
        }
        var info = String(localized: "Enter your \(gateName) to \(reason).")
        while true {
            guard let typed = Dialogs.password(title: String(localized: "Enter your \(gateName)"), message: info,
                                               placeholder: String(localized: "Password"))
            else { return nil }
            if await Self.check(verifier, password: typed) {
                lastPasswordCheck = Date()
                if let grace { extendGrace(grace) }
                return Authorization(password: typed)
            }
            info = String(localized: "Wrong password. If you forgot it, ⋯ → Master Password → Forgot Password… erases your tokens so you can start again from a backup.")
        }
    }

    // MARK: Master password prompts

    private var needsPasswordSetup: Bool {
        !isLocked && !tokens.isEmpty && !hasPasswordGate && !exportPasswordSkipped
    }

    /// Runs after the vault opens and after tokens are added: asks for a password if there is none,
    /// or reminds the user of it now and then. Safe to call repeatedly.
    func checkPasswordPrompts() {
        Task {
            if needsPasswordSetup {
                await promptPasswordSetup()
            } else {
                await remindPassword()
                await remindBackup()
            }
        }
    }

    /// Blocks until the user sets a password or skips it with the confirmation phrase.
    private func promptPasswordSetup() async {
        guard !passwordPromptActive else { return }
        passwordPromptActive = true
        defer { passwordPromptActive = false }
        while needsPasswordSetup {
            let pick = Dialogs.choice(
                title: String(localized: "Set a master password"),
                message: String(localized: "Exporting, deleting and changing tokens will ask for it, so nobody at your Mac can take all your secrets, even with your fingerprint while you sleep."),
                buttons: [String(localized: "Set Password…"), String(localized: "Skip")])
            if pick == 0 {
                if await chooseMasterPassword() { return }
            } else if confirmSkip() {
                return
            }
        }
    }

    private func confirmSkip() -> Bool {
        let phrase = String(localized: "I understand the risk")
        guard Dialogs.typedConfirmation(
            title: String(localized: "Go without a master password?"),
            message: String(localized: "Anyone with access to this Mac, even using your fingerprint while you sleep, can export all your tokens. Type “\(phrase)” to continue."),
            phrase: phrase, button: String(localized: "Skip"))
        else { return false }
        exportPasswordSkipped = true
        return true
    }

    /// Asks for a new master password twice and stores it. False if cancelled.
    private func chooseMasterPassword(title: String = String(localized: "Master password")) async -> Bool {
        // The warning stays on screen with the field, so the setup screen before it can stay short.
        let warning = String(localized: "If you forget it, the only way to reset it is to erase all your tokens. Make sure you can get back into each account another way: its backup codes, or an encrypted backup of your tokens.")
        var info = String(localized: "At least 8 characters. Not your Mac password: a long passphrase works best.") + "\n\n" + warning
        while true {
            guard let password = Dialogs.password(title: title, message: info, confirm: true,
                                                  placeholder: String(localized: "New password"))
            else { return false }
            guard password.count >= ExportPassword.minLength else {
                info = String(localized: "Too short. Use at least 8 characters.") + "\n\n" + warning
                continue
            }
            do {
                let verifier = try await Task.detached { try ExportPassword.makeVerifier(password: password) }.value
                let old = exportVerifier
                exportVerifier = verifier
                // With the vault key wrapped by the old password, it takes the new one too.
                if hasMasterPassword {
                    guard await rekey(password: password) else { exportVerifier = old; return false }
                } else {
                    persist()
                }
                exportPasswordSkipped = false
                lastPasswordCheck = Date()
                showToast(String(localized: "Master password set"))
                return true
            } catch {
                Dialogs.error(error, title: String(localized: "Could not set the master password"))
                return false
            }
        }
    }

    /// Asks for the password again when `passwordReminderDays` have passed since it was last typed.
    private func remindPassword() async {
        guard !isLocked, !passwordPromptActive, passwordReminderDays > 0, let verifier = gateVerifier(),
              Date() >= reminderSnoozedUntil
        else { return }
        guard let last = lastPasswordCheck else { lastPasswordCheck = Date(); return }
        let days = passwordReminderDays
        guard Date().timeIntervalSince(last) > Double(days) * 86400 else { return }

        passwordPromptActive = true
        defer { passwordPromptActive = false }
        var info = String(localized: "It has been more than \(days) days. Type your \(gateName) so you don't forget it. Cancel to be asked again tomorrow.")
        while true {
            guard let typed = Dialogs.password(title: String(localized: "Remember your \(gateName)?"), message: info,
                                               placeholder: String(localized: "Password"))
            else {
                reminderSnoozedUntil = Date().addingTimeInterval(86400)
                return
            }
            if await Self.check(verifier, password: typed) {
                lastPasswordCheck = Date()
                showToast(String(localized: "Password confirmed"))
                return
            }
            info = String(localized: "Wrong password. If you forgot it, cancel, then use ⋯ → Master Password → Forgot Password… to erase your tokens and start again from a backup.")
        }
    }

    /// The only way back in without the password: erase every token. Touch ID is enough, because this
    /// destroys secrets instead of exposing them.
    func forgotMasterPassword() {
        Task {
            let phrase = String(localized: "Erase all tokens")
            guard exportVerifier != nil, !hasMasterPassword,
                  Dialogs.confirm(title: String(localized: "Forgot the master password?"),
                                  message: String(localized: "It cannot be recovered. You can erase all your tokens and set a new password, then import them again from a backup or sign in to each account to add its token."),
                                  button: String(localized: "Continue")),
                  Dialogs.typedConfirmation(title: String(localized: "Erase all tokens?"),
                                            message: String(localized: "This cannot be undone. Type “\(phrase)” to continue."),
                                            phrase: phrase, button: String(localized: "Erase")),
                  await confirmOwner(String(localized: "erase all your tokens"))
            else { return }
            tokens = []
            groups = []
            exportVerifier = nil
            exportPasswordSkipped = false
            persist()
            showToast(String(localized: "All tokens erased"))
        }
    }

    // MARK: Password reminder setting

    static let reminderPresets = [0, 7, 30, 90]

    static func reminderLabel(_ days: Int) -> String {
        days == 0 ? String(localized: "Never") : String(localized: "\(days) days")
    }

    func setCustomReminder() {
        guard let text = Dialogs.text(title: String(localized: "Password Reminder"),
                                      message: String(localized: "Days between asking for your password again, so you don't forget it. 0 turns it off."),
                                      value: String(passwordReminderDays), button: String(localized: "Set")),
              let days = Int(text.trimmingCharacters(in: .whitespaces)), (0...3650).contains(days)
        else { return }
        passwordReminderDays = days
    }

    // MARK: Stay unlocked

    static let gracePresets = [0, 1, 2, 5, 15, 30, 60, untilSleep, untilLocked]

    static func graceLabel(_ minutes: Int) -> String {
        switch minutes {
        case untilSleep: return String(localized: "Until Mac Sleeps or Locks")
        case untilLocked: return String(localized: "Until I Lock It")
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
    func touch() {
        lastActive = Date()
        updateMenuBarRing()
    }

    /// The panel went off screen or the app went to the background: Stay Unlocked counts from now.
    private func panelDidClose() {
        if !panelWasClosed { touch() }
        panelWasClosed = true
        hideAllCodes()
        updateMenuBarRing()
    }

    // MARK: Menu bar countdown

    /// Starts, re-times or stops the menu bar countdown. It follows the most common TOTP period
    /// (30 s, normally) while the vault is unlocked; with `.untilGraceEnds` it also stops when
    /// Stay Unlocked runs out after the panel closes, since the vault only locks for real on the
    /// next open, and the countdown shouldn't wake the Mac for hours after codes stopped showing.
    private func updateMenuBarRing() {
        let periods = tokens.filter { $0.kind != .hotp }.map(\.period)
        let period = Dictionary(grouping: periods, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        guard menuBarCountdown != .off, !isLocked, let period else {
            menuBarRing.follow(period: nil, until: nil)
            return
        }
        var end: Date?
        if menuBarCountdown == .untilGraceEnds, panelWasClosed, graceMinutes >= 0,
           let lastActive {
            end = lastActive.addingTimeInterval(max(5, Double(graceMinutes * 60)))
        }
        menuBarRing.follow(period: TimeInterval(period), until: end)
    }

    private func observeSystemLock() {
        // All observers are registered on the main queue.
        let lockIfNeeded: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.graceMinutes != Self.untilLocked else { return }
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
        Clipboard.copy(code, clearAfter: clearsClipboard ? 30 : nil)
        // One click copies and shows the code, so a hidden one can be checked.
        if hidesCode(token) { reveal(token) }
        touch()
        if closesAfterCopy {
            // Shake the row first so the copy is visible, then close.
            shakeRow(token.id, next: next)
            closeTask?.cancel()
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.7))
                guard !Task.isCancelled, self?.closesAfterCopy == true else { return }
                PanelController.shared.close()
            }
            return
        }
        showToast(next ? String(localized: "Copied next \(token.name)") : String(localized: "Copied \(token.name)"))
        if next { flashNext(token.id) }
        shakeRow(token.id, next: next)
    }

    private func shakeRow(_ id: Token.ID, next: Bool) {
        shakenRow = id
        shakesNext = next
        shakeCount += 1
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
        checkPasswordPrompts()
    }

    func delete(_ token: Token) {
        guard Dialogs.confirm(title: String(localized: "Delete “\(token.name)”?"),
                              message: String(localized: "Make sure you can still sign in to this account another way. This cannot be undone."),
                              button: String(localized: "Delete"))
        else { return }
        Task {
            guard await authorize(String(localized: "delete “\(token.name)”"), grace: .delete) != nil else { return }
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
            try store.save(Vault(tokens: tokens, groups: groups, exportVerifier: exportVerifier), key: key)
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
            checkPasswordPrompts()
        } catch {
            Dialogs.error(error, title: String(localized: "Import failed"))
        }
    }

    func exportBackup(as format: BackupFormat, encrypted: Bool) {
        Task {
            guard let auth = await authorize(String(localized: "export all your secrets to \(format.displayName)")) else { return }
            exportConfirmed(as: format, encrypted: encrypted, typedPassword: auth.password)
        }
    }

    /// Shows one token as a QR code (a standard otpauth:// link) for another authenticator app to scan.
    func showQRCode(_ token: Token) {
        Task {
            guard await authorize(String(localized: "show “\(token.name)” as a QR code"), grace: .qr) != nil,
                  tokens.contains(where: { $0.id == token.id })
            else { return }
            let link = OTPAuthURI.make(token)
            var instructions = String(localized: "In your other authenticator app, add an account by scanning this QR code. Anyone who sees it can copy this account.")
            if token.kind == .steam {
                instructions += " " + String(localized: "Many authenticator apps don't support Steam codes and will show wrong ones.")
            }
            QRCodeWindow.show(title: String(localized: "QR Code for “\(token.name)”"), instructions: instructions,
                              codes: [link], copyableLink: link)
        }
    }

    /// Shows Google Authenticator transfer QR codes, to scan with its Transfer accounts → Import accounts.
    func exportToGoogle() {
        Task {
            guard await authorize(String(localized: "show all your secrets as QR codes for Google Authenticator")) != nil else { return }
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

    /// The password an encrypted backup file is locked with: the master password just typed, or a new one.
    /// Nil when the user cancels.
    private func backupPassword(for format: BackupFormat, typedPassword: String?) -> String? {
        let different = { Dialogs.password(title: String(localized: "Set a backup password"),
                                           message: String(localized: "Choose a new password for this backup file. \(format.displayName) will ask for it when importing. It is not your Mac or Keychain password."),
                                           confirm: true) }
        guard let typedPassword else { return different() }
        switch Dialogs.choice(title: String(localized: "Encrypt the backup"),
                              message: String(localized: "The file will be encrypted with your master password. \(format.displayName) will ask for it when importing."),
                              buttons: [String(localized: "Use Master Password"), String(localized: "Use a Different Password…"), String(localized: "Cancel")]) {
        case 0: return typedPassword
        case 1: return different()
        default: return nil
        }
    }

    // MARK: Backup

    func chooseBackupFolder() {
        if let url = Dialogs.chooseBackupFolder(current: backupFolder) { backupFolder = url }
    }

    /// Writes an encrypted Aegis backup into the backup folder (asked for the first time).
    func backUpNow() {
        Task {
            guard !tokens.isEmpty,
                  let auth = await authorize(String(localized: "back up all your secrets")) else { return }
            if backupFolder == nil { chooseBackupFolder() }
            guard let folder = backupFolder, let password = backupPassword(for: .aegis, typedPassword: auth.password) else { return }
            let day = Date().formatted(.iso8601.year().month().day())
            let url = folder.appendingPathComponent("TrayOTP-backup-\(day).json")
            do {
                let data = try Exporter.encode(.init(tokens: tokens, groups: groups), as: .aegis, password: password)
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                lastBackup = Date()
                showToast(String(localized: "Backup saved"))
            } catch {
                Dialogs.error(error, title: String(localized: "Backup failed"))
            }
        }
    }

    /// Suggests a backup when `backupReminderDays` have passed since the last one (or since first seen).
    private func remindBackup() async {
        guard !isLocked, !passwordPromptActive, !tokens.isEmpty, backupReminderDays > 0,
              Date() >= backupSnoozedUntil
        else { return }
        let defaults = UserDefaults.standard
        guard let last = lastBackup ?? defaults.object(forKey: Keys.backupReminderSince) as? Date else {
            defaults.set(Date(), forKey: Keys.backupReminderSince)
            return
        }
        let days = Int(Date().timeIntervalSince(last) / 86400)
        guard days >= backupReminderDays else { return }
        passwordPromptActive = true
        defer { passwordPromptActive = false }
        let state = lastBackup == nil ? String(localized: "You have not backed up your tokens yet.")
                                      : String(localized: "Your last backup is \(days) days old.")
        if Dialogs.confirm(title: String(localized: "Back up your tokens?"),
                           message: state + " " + String(localized: "Cancel to be reminded again tomorrow."),
                           button: String(localized: "Back Up Now")) {
            backUpNow()
        } else {
            backupSnoozedUntil = Date().addingTimeInterval(86400)
        }
    }

    private func exportConfirmed(as format: BackupFormat, encrypted: Bool, typedPassword: String?) {
        var password: String?
        if encrypted {
            guard let chosen = backupPassword(for: format, typedPassword: typedPassword) else { return }
            password = chosen
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

    /// Stored so SwiftUI re-renders; `SMAppService.status` can settle after `register()`, so it is re-read
    /// after a change and whenever the panel opens.
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Dialogs.error(error, title: String(localized: "Launch at login"))
        }
        refreshLaunchAtLogin()
    }
}
