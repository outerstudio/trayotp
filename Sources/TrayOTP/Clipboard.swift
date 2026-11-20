import AppKit
import CoreImage

@MainActor
enum Clipboard {
    /// Marks the entry as sensitive so clipboard managers (Maccy, Raycast...) skip it.
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static var ourChangeCount: Int?

    static func copy(_ text: String, clearAfter seconds: Double? = 30) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        pb.setString("", forType: concealed)
        let change = pb.changeCount
        ourChangeCount = change
        guard let seconds else { return }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if pb.changeCount == change { pb.clearContents() }
        }
    }

    /// Clears the clipboard only if it still holds a code we copied.
    static func clearIfOurs() {
        let pb = NSPasteboard.general
        if let ourChangeCount, pb.changeCount == ourChangeCount { pb.clearContents() }
    }

    static func readImage() -> NSImage? {
        (NSPasteboard.general.readObjects(forClasses: [NSImage.self]) as? [NSImage])?.first
    }

    /// Text on the clipboard, or the content of a QR code in a copied image.
    static func readOTPInput() -> String? {
        let pb = NSPasteboard.general
        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let image = readImage() {
            // "otpauth" also matches Google Authenticator's otpauth-migration:// transfer codes.
            let messages = QRReader.messages(in: image)
            return messages.first { $0.lowercased().hasPrefix("otpauth") } ?? messages.first
        }
        return nil
    }
}

enum QRReader {
    static func messages(in image: NSImage) -> [String] {
        guard let tiff = image.tiffRepresentation, let ci = CIImage(data: tiff) else { return [] }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return detector?.features(in: ci).compactMap { ($0 as? CIQRCodeFeature)?.messageString } ?? []
    }
}
