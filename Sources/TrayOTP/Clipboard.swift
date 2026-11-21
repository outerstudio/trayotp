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

    static func readImage(from pasteboard: NSPasteboard = .general) -> NSImage? {
        (pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage])?.first
    }

    /// Prefer authenticator links when a copied image also carries text.
    static func readOTPInput(from pasteboard: NSPasteboard = .general) -> String? {
        let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, isOTPLink(text) { return text }

        let messages = readImage(from: pasteboard).map(QRReader.messages(in:)) ?? []
        if let link = messages.first(where: isOTPLink) { return link }
        if let text, !text.isEmpty { return text }
        return messages.first
    }

    private static func isOTPLink(_ text: String) -> Bool {
        let lowercased = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased.hasPrefix("otpauth://") || lowercased.hasPrefix("otpauth-migration://")
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
