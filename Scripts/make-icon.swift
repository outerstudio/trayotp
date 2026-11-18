// Draws the TrayOTP app icon and writes Support/AppIcon.icns.
// Run from the repo root:  swift Scripts/make-icon.swift   (or: make icon)
//
// The lock is drawn by hand: SF Symbols may not be used in app icons.
import AppKit

let accentTop = NSColor(red: 1.00, green: 0.47, blue: 0.33, alpha: 1)
let accentBottom = NSColor(red: 0.91, green: 0.29, blue: 0.19, alpha: 1)
let tileTop = NSColor(red: 0.20, green: 0.21, blue: 0.24, alpha: 1)
let tileBottom = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)

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
    NSGradient(starting: tileTop, ending: tileBottom)!.draw(in: tilePath, angle: -90)

    // Orange lock on the dark tile: shackle + body.
    accentTop.set()
    let shackle = NSBezierPath()
    shackle.lineWidth = 52
    shackle.lineCapStyle = .round
    shackle.move(to: NSPoint(x: 432, y: 560))
    shackle.line(to: NSPoint(x: 432, y: 630))
    shackle.appendArc(withCenter: NSPoint(x: 512, y: 630), radius: 80, startAngle: 180, endAngle: 0, clockwise: true)
    shackle.line(to: NSPoint(x: 592, y: 560))
    shackle.stroke()

    let body = NSBezierPath(roundedRect: NSRect(x: 362, y: 330, width: 300, height: 240), xRadius: 44, yRadius: 44)
    NSGradient(starting: accentTop, ending: accentBottom)!.draw(in: body, angle: -90)

    // Keyhole in the tile colour.
    tileBottom.setFill()
    NSBezierPath(ovalIn: NSRect(x: 512 - 30, y: 448, width: 60, height: 60)).fill()
    NSBezierPath(roundedRect: NSRect(x: 512 - 14, y: 392, width: 28, height: 80), xRadius: 14, yRadius: 14).fill()

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
