import AppKit
import UniformTypeIdentifiers

/// Modal AppKit dialogs. A menu bar app must activate itself first or they open behind other windows.
@MainActor
enum Dialogs {
    /// Closes the tray panel and brings the app forward so the dialog gets keyboard focus.
    /// An open panel comes back once the dialogs are done.
    private static func prepare() {
        if PanelController.shared.isOpen { PanelController.shared.reopenWhenIdle() }
        PanelController.shared.hide()
        NSApp.activate(ignoringOtherApps: true)
    }

    static func openFile() -> URL? {
        prepare()
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import backup")
        panel.message = String(localized: "An export from 2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator, Stratum, andOTP, FreeOTP+, Raivo OTP or a password manager (CSV), or a screenshot of a Google Authenticator transfer QR code")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Any file: andOTP and Stratum backups have no standard extension. The format is detected from the content.
        panel.allowedContentTypes = [.data]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openImage() -> URL? {
        prepare()
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose an icon")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openZip() -> URL? {
        prepare()
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose an Aegis icon pack")
        panel.message = String(localized: "A .zip with pack.json, e.g. aegis-icons.zip from github.com/aegis-icons/aegis-icons/releases")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openFolder() -> URL? {
        prepare()
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose a folder of icons")
        panel.message = String(localized: "Images named after your tokens, e.g. github.png, google.svg")
        panel.prompt = String(localized: "Import Icons")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func saveFile(name: String, fileExtension: String, title: String) -> URL? {
        prepare()
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension)].compactMap { $0 }
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Asks for a password; with `confirm` the user types it twice.
    static func password(title: String, message: String, confirm: Bool = false) -> String? {
        prepare()
        var info = message
        while true {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = info
            alert.addButton(withTitle: String(localized: "OK"))
            alert.addButton(withTitle: String(localized: "Cancel"))

            // Plain frames: an NSStackView ignores them and collapses the fields to zero width.
            let width: CGFloat = 260, height: CGFloat = 24, gap: CGFloat = 8
            let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: confirm ? height * 2 + gap : height))
            let first = NSSecureTextField(frame: NSRect(x: 0, y: container.frame.height - height, width: width, height: height))
            first.placeholderString = confirm ? String(localized: "New backup password") : String(localized: "Backup password")
            let second = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: width, height: height))
            second.placeholderString = String(localized: "Confirm password")
            container.addSubview(first)
            if confirm {
                container.addSubview(second)
                first.nextKeyView = second
            }
            alert.accessoryView = container
            alert.layout()
            alert.window.initialFirstResponder = first

            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            let value = first.stringValue
            if value.isEmpty {
                info = String(localized: "The password cannot be empty.")
            } else if confirm && value != second.stringValue {
                info = String(localized: "The passwords do not match.")
            } else {
                return value
            }
        }
    }

    /// Several labeled text fields, top to bottom. Returns their values, or nil on Cancel.
    static func fields(title: String, message: String, fields: [(label: String, value: String)], button: String) -> [String]? {
        prepare()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: String(localized: "Cancel"))

        // Plain frames, like `password`: an NSStackView would collapse the fields.
        let width: CGFloat = 260, labelHeight: CGFloat = 16, fieldHeight: CGFloat = 24, gap: CGFloat = 8
        let rowHeight = labelHeight + 2 + fieldHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width,
                                             height: CGFloat(fields.count) * rowHeight + CGFloat(fields.count - 1) * gap))
        var textFields: [NSTextField] = []
        for (i, f) in fields.enumerated() {
            let top = container.frame.height - CGFloat(i) * (rowHeight + gap)
            let label = NSTextField(labelWithString: f.label)
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            label.frame = NSRect(x: 0, y: top - labelHeight, width: width, height: labelHeight)
            let field = NSTextField(frame: NSRect(x: 0, y: top - rowHeight, width: width, height: fieldHeight))
            field.stringValue = f.value
            container.addSubview(label)
            container.addSubview(field)
            textFields.last?.nextKeyView = field
            textFields.append(field)
        }
        alert.accessoryView = container
        alert.layout()
        alert.window.initialFirstResponder = textFields.first
        return alert.runModal() == .alertFirstButtonReturn ? textFields.map(\.stringValue) : nil
    }

    /// One-line text prompt. Returns nil on Cancel.
    static func text(title: String, message: String, value: String, button: String) -> String? {
        prepare()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: String(localized: "Cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = value
        alert.accessoryView = field
        alert.layout()
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    /// Records a key combination. Returns nil on Cancel; `.some(nil)` means "Clear".
    static func shortcut(current: Shortcut?) -> Shortcut?? {
        prepare()
        let alert = NSAlert()
        alert.messageText = String(localized: "Global Shortcut")
        alert.informativeText = String(localized: "Press the keys that open TrayOTP from anywhere. Include ⌘, ⌃ or ⌥.")
        alert.addButton(withTitle: String(localized: "Set"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        if current != nil { alert.addButton(withTitle: String(localized: "Clear")) }
        let set = alert.buttons[0]
        let recorder = ShortcutRecorder(current: current) { set.isEnabled = true }
        set.isEnabled = current != nil
        alert.accessoryView = recorder
        alert.layout()
        alert.window.initialFirstResponder = recorder
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .some(recorder.shortcut)
        case .alertThirdButtonReturn: return .some(nil)
        default: return nil
        }
    }

    static func confirm(title: String, message: String, button: String) -> Bool {
        prepare()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func info(title: String, message: String) {
        prepare()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    static func error(_ error: Error, title: String) {
        prepare()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
