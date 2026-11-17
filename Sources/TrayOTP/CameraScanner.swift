import AppKit
import AVFoundation
import Vision

/// Reads one QR code with the Mac's camera, in a small preview window. The camera runs only while the
/// window is open. Used for codes that can't be screenshotted, like Google Authenticator's transfer screen.
@MainActor
final class CameraScanner: NSObject, NSWindowDelegate {
    enum ScanError: LocalizedError {
        case denied
        case noCamera

        var errorDescription: String? {
            switch self {
            case .denied:
                return "TrayOTP isn't allowed to use the camera. Turn it on in System Settings → Privacy & Security → Camera, then try again."
            case .noCamera:
                return "No camera found. Connect one, or use your iPhone as a webcam (Continuity Camera)."
            }
        }
    }

    private static var current: CameraScanner?

    private let session = AVCaptureSession()
    private let reader = FrameReader()
    private var window: NSWindow?
    private var continuation: CheckedContinuation<String?, Never>?

    /// The text of the first QR code seen, or nil if the window was closed first.
    static func scan() async throws -> String? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { throw ScanError.denied }
        default: throw ScanError.denied
        }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw ScanError.noCamera }

        current?.finish(nil)
        let scanner = CameraScanner()
        current = scanner
        return await withCheckedContinuation { continuation in
            scanner.continuation = continuation
            scanner.start(input: input)
        }
    }

    private func start(input: AVCaptureDeviceInput) {
        session.sessionPreset = .high
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(reader, queue: reader.queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        reader.onFound = { [weak self] text in
            Task { @MainActor in self?.finish(text) }
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 390))
        view.wantsLayer = true
        view.layer = preview

        let hint = NSTextField(labelWithString: "Hold the QR code up to the camera, about 20–30 cm away.")
        hint.font = .systemFont(ofSize: 12, weight: .medium)
        hint.textColor = .white
        hint.backgroundColor = NSColor.black.withAlphaComponent(0.55)
        hint.drawsBackground = true
        hint.alignment = .center
        hint.frame = NSRect(x: 0, y: 0, width: 520, height: 26)
        hint.autoresizingMask = [.width]
        view.addSubview(hint)

        let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Scan QR Code"
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        let session = session
        reader.queue.async { session.startRunning() }
    }

    private func finish(_ text: String?) {
        guard let continuation else { return }
        self.continuation = nil
        let session = session, reader = reader
        reader.queue.async {
            reader.onFound = nil
            session.stopRunning()
        }
        window?.delegate = nil
        window?.close()
        window = nil
        if Self.current === self { Self.current = nil }
        continuation.resume(returning: text)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in self.finish(nil) }
    }
}

/// Looks for a QR code in camera frames, a few times per second, off the main thread.
private final class FrameReader: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.outerstudio.trayotp.camera")
    /// Read and written on `queue` only, apart from setup before the session starts.
    var onFound: ((String) -> Void)?
    private var lastCheck = Date.distantPast

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard onFound != nil, Date().timeIntervalSince(lastCheck) > 0.2,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        lastCheck = Date()
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try? VNImageRequestHandler(cvPixelBuffer: pixels, options: [:]).perform([request])
        let texts = (request.results ?? []).compactMap(\.payloadStringValue)
        // Prefer otpauth:// and otpauth-migration:// codes over other QR codes in view.
        guard let text = texts.first(where: { $0.lowercased().hasPrefix("otpauth") }) ?? texts.first else { return }
        let found = onFound
        onFound = nil
        found?(text)
    }
}
