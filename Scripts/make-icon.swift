// Draws the TrayOTP app icon and writes Support/AppIcon.icns and Support/AppIcon-1024.png.
// Run from the repo root:  make icon
//
// The drawing is Sources/TrayOTP/IconArt.swift, shared with the app (which turns the ring at
// runtime), so this is compiled together with it:
//   swiftc -parse-as-library Scripts/make-icon.swift Sources/TrayOTP/IconArt.swift
import AppKit

@main
struct MakeIcon {
    /// Draws the icon (its ring as shipped, gap at 10:30) at `pixels` × `pixels`.
    static func drawIcon(pixels: Int) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        IconArt.drawAppIcon()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func main() {
        let fm = FileManager.default
        let iconset = URL(fileURLWithPath: fm.temporaryDirectory.path).appendingPathComponent("AppIcon.iconset")
        try? fm.removeItem(at: iconset)
        try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
                let png = drawIcon(pixels: size * scale).representation(using: .png, properties: [:])!
                try! png.write(to: iconset.appendingPathComponent(name))
            }
        }
        try! drawIcon(pixels: 1024).representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: "Support/AppIcon-1024.png"))

        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Support/AppIcon.icns"]
        try! iconutil.run()
        iconutil.waitUntilExit()
        precondition(iconutil.terminationStatus == 0, "iconutil failed")
        print("Wrote Support/AppIcon.icns and Support/AppIcon-1024.png")

        writeCountdownGIF(to: URL(fileURLWithPath: "docs/app-icon.gif"))
        print("Wrote docs/app-icon.gif")
    }

    /// The README icon: the ring drains like a code (sped up: 3 s instead of 30), then sweeps full again
    /// while it turns somewhere new, as on the lock screen. Four rounds end where they began, so the
    /// loop is seamless.
    static func writeCountdownGIF(to url: URL) {
        let pixels = 256, fps = 15.0
        let drain = 3.0, turn = 0.9
        // Each round's direction; the last turn comes back to the first (360 = 0).
        let rotations: [CGFloat] = [0, 140, 250, 35, 360]
        var frames: [(rotation: CGFloat, remaining: CGFloat)] = []
        for round in 0..<rotations.count - 1 {
            let from = rotations[round], to = rotations[round + 1]
            for i in 0..<Int(drain * fps) { frames.append((from, 1 - CGFloat(Double(i) / (drain * fps)))) }
            for i in 0..<Int(turn * fps) {
                // Ease in and out, like IconSpinner: the ring grows back as it swings round.
                let t = Double(i + 1) / (turn * fps)
                let eased = CGFloat(t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2)
                frames.append((from + (to - from) * eased, eased))
            }
        }

        let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, frames.count, nil)!
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
        for frame in frames {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
            IconArt.drawAppIcon(rotation: frame.rotation, remaining: frame.remaining)
            NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination, rep.cgImage!, delay)
        }
        precondition(CGImageDestinationFinalize(destination), "Could not write \(url.path)")
    }
}
