import AppKit

/// The TrayOTP icon, a lock inside a TOTP countdown ring, drawn in code so the ring can point
/// anywhere: the app turns it now and then (see `IconSpinner`). Also used by Scripts/make-icon.swift
/// for Support/AppIcon.icns, which is drawn with `rotation` 0 (the gap at 10:30).
///
/// Drawn by hand: SF Symbols may not be used in app icons. Self-contained (AppKit only), so the
/// icon script can compile it on its own.
enum IconArt {
    // Flat colours only: no gradients, shadows or highlights.
    static let accent = NSColor(red: 0.96, green: 0.38, blue: 0.25, alpha: 1)
    static let tileColor = NSColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1)
    static let trackColor = NSColor(red: 0.21, green: 0.22, blue: 0.25, alpha: 1)

    /// Draws the app icon into the current graphics context, in a 1024×1024 space (y up).
    /// `rotation`: degrees clockwise from the shipped icon. `remaining`: how much of the ring is lit,
    /// from 12 o'clock (before rotation) clockwise; the shipped icon shows three quarters.
    static func drawAppIcon(rotation: CGFloat = 0, remaining: CGFloat = 0.75) {
        // macOS icon grid: 824 pt rounded square centred on the 1024 canvas. Flat: no shadow, no backdrop.
        let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
        tileColor.setFill()
        NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).fill()

        // Countdown ring: a faint full track, then the time left as an orange arc.
        let center = NSPoint(x: 512, y: 512), radius: CGFloat = 268, ringWidth: CGFloat = 60
        let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        track.lineWidth = ringWidth
        trackColor.setStroke()
        track.stroke()

        let lit = min(max(remaining, 0), 1)
        if lit > 0.001 {
            let arc = NSBezierPath()
            let start = 90 - rotation
            arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start - 360 * lit, clockwise: true)
            arc.lineWidth = ringWidth
            arc.lineCapStyle = .round
            accent.setStroke()
            arc.stroke()
        }

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
    }

    /// The app icon as an image of any size, e.g. for `NSApp.applicationIconImage`.
    static func appIcon(rotation: CGFloat, remaining: CGFloat = 0.75, size: CGFloat = 512) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.cgContext.scaleBy(x: rect.width / 1024, y: rect.height / 1024)
            drawAppIcon(rotation: rotation, remaining: remaining)
            return true
        }
    }

    /// The menu bar icon: the same ring and lock as a template image, which macOS tints for light
    /// and dark menu bars. A little larger than the default symbol size (~13 pt), like the icons next to it.
    /// `remaining` is how much of the ring is lit (it counts down with the codes, see `MenuBarRing`).
    static func menuBarIcon(rotation: CGFloat, remaining: CGFloat = 0.75) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let center = NSPoint(x: side / 2, y: side / 2), radius: CGFloat = 7.5
            let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
            track.lineWidth = 1.7
            // Template images keep only alpha: the faint track reads as a dimmer ring.
            NSColor.black.withAlphaComponent(0.3).setStroke()
            track.stroke()

            let lit = min(max(remaining, 0), 1)
            if lit > 0.001 {
                let arc = NSBezierPath()
                let start = 90 - rotation
                arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: start - 360 * lit, clockwise: true)
                arc.lineWidth = 1.7
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }

            // Lock: shackle + body, with the keyhole cut out.
            NSColor.black.set()
            let shackle = NSBezierPath()
            shackle.lineWidth = 1.3
            shackle.move(to: NSPoint(x: 7.0, y: 8.6))
            shackle.line(to: NSPoint(x: 7.0, y: 10.4))
            shackle.appendArc(withCenter: NSPoint(x: 9, y: 10.4), radius: 2.0, startAngle: 180, endAngle: 0, clockwise: true)
            shackle.line(to: NSPoint(x: 11.0, y: 8.6))
            shackle.stroke()
            NSBezierPath(roundedRect: NSRect(x: 5.6, y: 4.7, width: 6.8, height: 4.6), xRadius: 1.1, yRadius: 1.1).fill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: 8.25, y: 6.3, width: 1.5, height: 1.5)).fill()
            NSBezierPath(rect: NSRect(x: 8.6, y: 5.5, width: 0.8, height: 1.3)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "TrayOTP"
        return image
    }
}
