import AppKit
import CoreImage

/// Shows a series of QR codes one at a time, e.g. Google Authenticator transfer codes for its
/// Transfer accounts → Import accounts screen. The codes hold secrets, so the window closes when
/// TrayOTP locks and is excluded from screenshots and screen sharing.
@MainActor
final class QRCodeWindow: NSObject, NSWindowDelegate {
    private static var current: QRCodeWindow?

    private let codes: [String]
    private var index = 0
    private let window: NSWindow
    private let imageView = NSImageView()
    private let counter = NSTextField(labelWithString: "")
    private let previous = NSButton(title: String(localized: "Previous"), target: nil, action: nil)
    private let next = NSButton(title: String(localized: "Next"), target: nil, action: nil)

    /// `copyableLink` adds a field with the link below the code and a button that copies it.
    static func show(title: String, instructions: String, codes: [String], copyableLink: String? = nil) {
        current?.window.close()
        let w = QRCodeWindow(title: title, instructions: instructions, codes: codes, copyableLink: copyableLink)
        current = w
        NSApp.activate(ignoringOtherApps: true)
        w.window.makeKeyAndOrderFront(nil)
    }

    static func closeAll() { current?.window.close() }

    private let link: String?
    private let toast = NSView()
    private var toastTask: Task<Void, Never>?

    private init(title: String, instructions: String, codes: [String], copyableLink: String?) {
        self.codes = codes
        link = copyableLink
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = title
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.sharingType = .none
        window.delegate = self

        let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
        let text = NSTextField(wrappingLabelWithString: instructions)
        text.frame = NSRect(x: 20, y: 470, width: 380, height: 70)
        text.font = .systemFont(ofSize: 12)
        imageView.frame = NSRect(x: 30, y: 100, width: 360, height: 360)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        counter.frame = NSRect(x: 20, y: 66, width: 380, height: 20)
        counter.alignment = .center
        counter.font = .systemFont(ofSize: 13, weight: .medium)

        previous.target = self
        previous.action = #selector(showPrevious)
        next.target = self
        next.action = #selector(showNext)
        let done = NSButton(title: String(localized: "Done"), target: self, action: #selector(finish))
        done.keyEquivalent = "\u{1b}"
        for (button, x) in [(previous, 20.0), (next, 130.0), (done, 300.0)] {
            button.bezelStyle = .rounded
            button.frame = NSRect(x: x, y: 20, width: 100, height: 32)
            content.addSubview(button)
        }
        next.keyEquivalent = "\r"
        for view in [text, imageView, counter] as [NSView] { content.addSubview(view) }
        if let link {
            let field = NSTextField(labelWithString: link)
            field.usesSingleLineMode = true
            field.maximumNumberOfLines = 1
            field.lineBreakMode = .byTruncatingMiddle
            field.toolTip = link
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.frame = NSRect(x: 20, y: 66, width: 270, height: 18)
            let copy = NSButton(title: String(localized: "Copy Link"), target: self, action: #selector(copyLink))
            copy.bezelStyle = .rounded
            copy.frame = NSRect(x: 300, y: 62, width: 100, height: 28)
            content.addSubview(field)
            content.addSubview(copy)

            let label = NSTextField(labelWithString: String(localized: "Link copied"))
            label.alignment = .center
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .white
            // A label draws at the top of its frame, so size it to its text and center that in the pill.
            let size = label.fittingSize
            toast.frame = NSRect(x: 135, y: 108, width: 150, height: 28)
            label.frame = NSRect(x: 0, y: ((toast.frame.height - size.height) / 2).rounded(), width: toast.frame.width, height: size.height)
            toast.addSubview(label)
            toast.wantsLayer = true
            toast.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
            toast.layer?.cornerRadius = 10
            toast.alphaValue = 0
            content.addSubview(toast)
        }
        window.contentView = content
        window.center()
        update()
    }

    private func update() {
        imageView.image = Self.qrImage(codes[index])
        let (number, total) = (index + 1, codes.count)
        counter.stringValue = total > 1 ? String(localized: "QR code \(number) of \(total)") : ""
        previous.isEnabled = index > 0
        next.isEnabled = index < codes.count - 1
        previous.isHidden = codes.count == 1
        next.isHidden = codes.count == 1
    }

    @objc private func showPrevious() { index = max(index - 1, 0); update() }
    @objc private func showNext() { index = min(index + 1, codes.count - 1); update() }
    @objc private func copyLink() {
        guard let link else { return }
        Clipboard.copy(link)
        toastTask?.cancel()
        toast.animator().alphaValue = 1
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.toast.animator().alphaValue = 0
        }
    }
    @objc private func finish() { window.close() }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            if Self.current?.window === notification.object as? NSWindow { Self.current = nil }
        }
    }

    /// A crisp QR code: scaled by whole pixels, with the quiet zone scanners need.
    private static func qrImage(_ text: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        // Low error correction: fewer, bigger modules. Screens don't get dirty or torn like paper.
        filter.setValue("L", forKey: "inputCorrectionLevel")
        guard let code = filter.outputImage else { return nil }
        let scale = max(1, (720 / code.extent.width).rounded(.down))
        let scaled = code.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let margin = 4 * scale
        let canvas = CIImage(color: .white).cropped(to: scaled.extent.insetBy(dx: -margin, dy: -margin))
        let image = scaled.composited(over: canvas)
        let rep = NSCIImageRep(ciImage: image)
        let out = NSImage(size: rep.size)
        out.addRepresentation(rep)
        return out
    }
}
