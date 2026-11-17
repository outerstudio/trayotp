import AppKit
import Carbon.HIToolbox

/// A key plus modifiers, stored in Carbon terms because that is what `RegisterEventHotKey` takes.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String

    /// Needs ⌘, ⌃ or ⌥, so a plain letter can never be swallowed system-wide.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        guard carbon & UInt32(controlKey | optionKey | cmdKey) != 0 else { return nil }

        let code = UInt32(event.keyCode)
        guard let label = Self.keyNames[code] ?? event.charactersIgnoringModifiers?.uppercased(),
              !label.isEmpty else { return nil }
        self.init(keyCode: code, modifiers: carbon, label: label)
    }

    init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    /// e.g. "⌃⌥⌘O", in the order macOS shows them.
    var display: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + label
    }

    /// Why this combination would clash with other shortcuts, or nil if it is free as far as we can tell.
    /// A hotkey registered over one of these still succeeds, so `RegisterEventHotKey` can't catch them.
    var conflict: String? {
        let modifierMask = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let functionKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
                            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12].map(UInt32.init)
        // ⌘ alone is what apps use for Copy, Paste, Quit…; taking one would break it everywhere.
        if modifiers & modifierMask == UInt32(cmdKey), !functionKeys.contains(keyCode) {
            return "\(display) is used by apps (like ⌘C for Copy). Add ⌃, ⌥ or ⇧."
        }
        // Enabled shortcuts from System Settings → Keyboard → Keyboard Shortcuts.
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let hotKeys = unmanaged?.takeRetainedValue() as? [[String: Any]]
        else { return nil }
        let taken = hotKeys.contains { hotKey in
            (hotKey[kHISymbolicHotKeyEnabled] as? Bool) == true
                && (hotKey[kHISymbolicHotKeyCode] as? Int).map(UInt32.init) == keyCode
                && (hotKey[kHISymbolicHotKeyModifiers] as? Int).map { UInt32($0) & modifierMask } == modifiers & modifierMask
        }
        return taken ? "\(display) is a macOS shortcut. Choose another, or turn it off in System Settings → Keyboard → Keyboard Shortcuts." : nil
    }

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦", UInt32(kVK_Escape): "⎋",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘", UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
    ]

    // MARK: Persistence

    private enum Keys {
        static let keyCode = "shortcutKeyCode"
        static let modifiers = "shortcutModifiers"
        static let label = "shortcutLabel"
    }

    static func load() -> Shortcut? {
        let defaults = UserDefaults.standard
        guard let label = defaults.string(forKey: Keys.label), !label.isEmpty,
              defaults.object(forKey: Keys.keyCode) != nil else { return nil }
        return Shortcut(keyCode: UInt32(defaults.integer(forKey: Keys.keyCode)),
                        modifiers: UInt32(defaults.integer(forKey: Keys.modifiers)),
                        label: label)
    }

    static func save(_ shortcut: Shortcut?) {
        let defaults = UserDefaults.standard
        if let shortcut {
            defaults.set(Int(shortcut.keyCode), forKey: Keys.keyCode)
            defaults.set(Int(shortcut.modifiers), forKey: Keys.modifiers)
            defaults.set(shortcut.label, forKey: Keys.label)
        } else {
            for key in [Keys.keyCode, Keys.modifiers, Keys.label] { defaults.removeObject(forKey: key) }
        }
    }
}

/// Registers one system-wide hotkey that opens (or closes) the tray panel.
/// Carbon hotkeys need no Accessibility or Input Monitoring permission.
@MainActor
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    /// Replaces the current hotkey; nil unregisters it. False if another app already owns the combination.
    @discardableResult
    func register(_ shortcut: Shortcut?) -> Bool {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        guard let shortcut else { return true }
        installHandlerOnce()

        let id = EventHotKeyID(signature: OSType(0x5452_4F54), id: 1) // 'TROT'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else { return false }
        hotKeyRef = ref
        return true
    }

    private func installHandlerOnce() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                PanelController.shared.toggle()
            } }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

/// Dialog accessory that captures the next key combination typed into it.
final class ShortcutRecorder: NSView {
    private(set) var shortcut: Shortcut?
    private let field = NSTextField(labelWithString: "")
    private let onChange: () -> Void

    init(current: Shortcut?, onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 32))
        shortcut = current
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        field.alignment = .center
        field.font = .systemFont(ofSize: 15)
        field.frame = NSRect(x: 0, y: 6, width: 260, height: 20)
        addSubview(field)
        refresh()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    private func refresh() {
        field.stringValue = shortcut?.display ?? "Type a shortcut"
        field.textColor = shortcut == nil ? .secondaryLabelColor : .labelColor
    }

    // Combinations with ⌘ arrive here before keyDown; without a modifier Return and Esc still reach the buttons.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let new = Shortcut(event: event) else { return false }
        shortcut = new
        refresh()
        onChange()
        return true
    }

    override func keyDown(with event: NSEvent) {
        if !performKeyEquivalent(with: event) { NSSound.beep() }
    }
}
