// Draws the TrayOTP app icon and writes Support/AppIcon.icns.
// Run from the repo root:  swift Scripts/make-icon.swift   (or: make icon)
//
// A lock inside a TOTP countdown ring, echoing the lock.circle tray symbol. Everything is
// drawn by hand: SF Symbols may not be used in app icons.
import AppKit

// Flat colours only: no gradients, shadows or highlights.
let accent = NSColor(red: 0.96, green: 0.38, blue: 0.25, alpha: 1)
let tileColor = NSColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1)
let trackColor = NSColor(red: 0.21, green: 0.22, blue: 0.25, alpha: 1)

/// Draws the icon in a 1024×1024 coordinate space (y up), scaled to `pixels`.
func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // macOS icon grid: 824 pt rounded square centred on the 1024 canvas. Flat: no shadow, no backdrop.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    tileColor.setFill()
    tilePath.fill()

    // TOTP countdown ring: a faint full track, then the time left as an orange arc running
    // clockwise from 12 o'clock (three quarters of the period left).
    let center = NSPoint(x: 512, y: 512), radius: CGFloat = 268, ringWidth: CGFloat = 60
    let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    track.lineWidth = ringWidth
    trackColor.setStroke()
    track.stroke()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 270, clockwise: true)
    arc.lineWidth = ringWidth
    arc.lineCapStyle = .round
    accent.setStroke()
    arc.stroke()

    // White lock in the ring: shackle + body, optically centred (the shackle makes it top-heavy).
    NSColor.white.set()
    let shackle = NSBezierPath()
    shackle.lineWidth = 38
    shackle.lineCapStyle = .round
    shackle.move(to: NSPoint(x: 456, y: 500))
    shackle.line(to: NSPoint(x: 456, y: 576))
    shackle.appendArc(withCenter: NSPoint(x: 512, y: 576), radius: 56, startAngle: 180, endAngle: 0, clockwise: true)
    shackle.line(to: NSPoint(x: 568, y: 500))
    shackle.stroke()

    NSBezierPath(roundedRect: NSRect(x: 404, y: 358, width: 216, height: 166), xRadius: 34, yRadius: 34).fill()

    // Keyhole in the tile colour.
    tileColor.setFill()
    NSBezierPath(ovalIn: NSRect(x: 512 - 23, y: 438, width: 46, height: 46)).fill()
    NSBezierPath(roundedRect: NSRect(x: 512 - 11, y: 394, width: 22, height: 62), xRadius: 11, yRadius: 11).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

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
