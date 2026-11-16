import AppKit
import SwiftUI

@main
struct TrayOTPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(state)
        } label: {
            Image(nsImage: Self.trayIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// A round, slightly larger symbol than the default menu bar size (~13 pt): a lock inside a ring
    /// with a transparent background. Template so macOS tints it for light and dark menu bars.
    private static let trayIcon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        let image = NSImage(systemSymbolName: "lock.circle", accessibilityDescription: "TrayOTP")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = true
        return image
    }()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, even when run as a bare binary (`swift run TrayOTP`).
        // In the .app bundle LSUIElement does the same.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = Self.editMenu()
    }

    /// Menu bar apps have no main menu, so ⌘V etc. do nothing in text fields.
    /// The menu is never shown, but its key equivalents still work.
    private static func editMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let item = NSMenuItem()
        item.submenu = edit
        let main = NSMenu()
        main.addItem(item)
        return main
    }
}
