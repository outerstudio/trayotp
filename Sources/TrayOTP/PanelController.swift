import AppKit
import SwiftUI

/// Opens and closes the panel: the MenuBarExtra window under the tray icon or, with the icon hidden,
/// a floating copy of it near the top of the screen.
@MainActor
final class PanelController {
    static let shared = PanelController()

    /// Set at launch; the floating panel shows the same state as the menu bar one.
    var state: AppState?
    private var floating: FloatingPanel?
    private var reopenPending = false

    private var usesMenuBar: Bool { state?.showsMenuBarIcon ?? true }

    private var menuBarWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && String(describing: type(of: $0)).contains("MenuBarExtra") }
    }

    var isOpen: Bool { window != nil }

    /// The visible panel window, menu bar or floating.
    var window: NSWindow? { menuBarWindow ?? floating.flatMap { $0.isVisible ? $0 : nil } }

    func toggle() {
        if isOpen { close() } else { open() }
    }

    func open() {
        NSApp.activate(ignoringOtherApps: true)
        if usesMenuBar {
            // Never both panels on screen.
            floating?.orderOut(nil)
            if menuBarWindow == nil { Self.statusButton()?.performClick(nil) }
        } else if let floating, floating.isVisible {
            menuBarWindow?.orderOut(nil)
            floating.makeKeyAndOrderFront(nil)
        } else {
            menuBarWindow?.orderOut(nil)
            showFloating()
        }
        // Opened from code, the window may not post didBecomeKey (or posts it before its views are ready),
        // so make sure it's key and ask the list to focus search once it's on screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.focus()
            self.state?.focusRequest += 1
        }
    }

    func close() {
        if menuBarWindow != nil { Self.statusButton()?.performClick(nil) }
        floating?.orderOut(nil)
        // Give the focus back to the previous app. Staying active would leave the panel window key,
        // so the next open posts no didBecomeKey and skips panelDidOpen (and Lock Every Time).
        NSApp.hide(nil)
    }

    /// Makes the open panel the key window again, e.g. after the Touch ID dialog took the focus.
    func focus() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
    }

    /// Shows the panel again after one of our own windows took its place (a dialog, the color sampler,
    /// the camera). That time counts as use, so the panel doesn't lock on the way back.
    func reopen() {
        state?.touch()
        open()
    }

    /// Reopens the panel once no modal dialog is up. Dialogs often follow each other (confirm, then a
    /// password) without a run loop turn in between, so the panel doesn't flash between them.
    func reopenWhenIdle(after delay: TimeInterval = 0.1) {
        guard !reopenPending else { return }
        reopenPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.reopenIfIdle() }
    }

    private func reopenIfIdle() {
        guard NSApp.modalWindow == nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.reopenIfIdle() }
            return
        }
        reopenPending = false
        reopen()
    }

    /// Moves an open panel to the menu bar or the floating window after the icon was shown or hidden.
    /// The delay lets MenuBarExtra put its status item in place first.
    func menuBarIconChanged() {
        let wasOpen = isOpen
        hide()
        // Back in the menu bar, drop the floating panel (PanelView also blanks the other mode's window).
        if usesMenuBar {
            floating?.close()
            floating = nil
        }
        if wasOpen { reopenWhenIdle(after: 0.3) }
    }

    /// Hides the panel without going through the status item, e.g. before a modal dialog.
    func hide() {
        menuBarWindow?.orderOut(nil)
        floating?.orderOut(nil)
    }

    private func showFloating() {
        guard let state else { return }
        let panel = floating ?? FloatingPanel(content: PanelView(inMenuBar: false).environment(state))
        floating = panel
        panel.show()
    }

    /// The MenuBarExtra panel has no public open/close API, so click its status item button.
    private static func statusButton() -> NSStatusBarButton? {
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBarWindow") {
            if let button = window.contentView.flatMap(statusButton(in:)) { return button }
        }
        return nil
    }

    private static func statusButton(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        for sub in view.subviews {
            if let found = statusButton(in: sub) { return found }
        }
        return nil
    }
}

/// Borderless panel that looks like the menu bar one. Closes on Esc (in PanelView) or a click in another app.
final class FloatingPanel: NSPanel {
    private var clickMonitor: Any?
    /// Top edge to keep while the content resizes (adding a token, folding a group).
    private var top: CGFloat?

    init(content: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        // The mask shapes the window shadow too; a layer corner radius alone leaves a square shadow edge.
        effect.maskImage = Self.roundedMask(radius: 12)
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        contentView = effect
    }

    override var canBecomeKey: Bool { true }

    /// A stretchable rounded rectangle: only the corners keep their size.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    /// Centered horizontally, a little below the menu bar of the screen with the mouse.
    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            top = nil
            if let size = contentView?.fittingSize { setContentSize(size) }
            let size = frame.size
            top = visible.maxY - 80
            setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: (top ?? 0) - size.height))
        }
        makeKeyAndOrderFront(nil)
        invalidateShadow()
        clickMonitor = clickMonitor ?? NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.orderOut(nil)
        }
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        if let top { rect.origin.y = top - rect.height }
        super.setFrame(rect, display: flag)
    }
}
