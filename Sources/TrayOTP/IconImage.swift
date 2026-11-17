import AppKit
import OTPCore

/// Converts user-supplied images into small PNG icons and caches decoded images for the rows.
@MainActor
enum IconImage {
    static let pixelSize = 128
    static let fileTypes = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "webp", "svg", "pdf", "icns"]

    static func pngData(contentsOf url: URL) -> Data? {
        load(url).flatMap(pngData(from:))
    }

    /// Re-encodes icon bytes from another app's backup (JPEG, PNG or SVG) as our PNG.
    static func pngData(imported data: Data) -> Data? {
        let head = String(decoding: data.prefix(512), as: UTF8.self)
        if head.contains("<svg") {
            let svg = SVGPathFixer.normalize(svg: String(decoding: data, as: UTF8.self))
            return NSImage(data: Data(svg.utf8)).flatMap(pngData(from:))
        }
        return NSImage(data: data).flatMap(pngData(from:))
    }

    /// Loads an image file. SVGs are normalized first, because CoreSVG mis-draws minified path data.
    static func load(_ url: URL) -> NSImage? {
        guard url.pathExtension.lowercased() == "svg" else { return NSImage(contentsOf: url) }
        guard let svg = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return NSImage(data: Data(SVGPathFixer.normalize(svg: svg).utf8))
    }

    /// Scales the image to fit a square of `pixelSize` (keeping transparency) and encodes it as PNG.
    static func pngData(from image: NSImage) -> Data? {
        let source = image.size
        guard source.width > 0, source.height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }

        let side = CGFloat(pixelSize)
        rep.size = NSSize(width: side, height: side)
        let scale = min(side / source.width, side / source.height)
        let size = NSSize(width: source.width * scale, height: source.height * scale)
        let rect = NSRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    /// An icon as the rows show it: the image centered in a circle, on an optional background color.
    /// `scale` is the image's size relative to the circle: 1 fits it exactly, larger values crop it.
    /// `offset` moves it from the center, as a fraction of the circle's width (right and down are positive).
    static func compose(_ image: NSImage, scale: CGFloat, offset: CGSize = .zero, background: NSColor?) -> Data? {
        let source = image.size
        guard source.width > 0, source.height > 0 else { return nil }
        let side = CGFloat(pixelSize)
        let fit = side * scale / max(source.width, source.height)
        let size = NSSize(width: source.width * fit, height: source.height * fit)
        let composed = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect)
            if let background {
                background.setFill()
                circle.fill()
            }
            circle.addClip()
            NSGraphicsContext.current?.imageInterpolation = .high
            // Drawing is bottom-up, so a downward offset lowers y.
            let target = NSRect(x: (side - size.width) / 2 + offset.width * side,
                                y: (side - size.height) / 2 - offset.height * side,
                                width: size.width, height: size.height)
            image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        return pngData(from: composed)
    }

    /// True when the image is effectively one flat color, e.g. a white logo on a white circle.
    /// Such icons are unreadable, so the row shows initials instead.
    static func isBlank(_ image: NSImage) -> Bool {
        let stats = colorStats(image)
        return stats.opaque == 0 || stats.flat
    }

    /// Number of opaque pixels in a 32×32 render, and whether they are all about the same color.
    private static func colorStats(_ image: NSImage) -> (opaque: Int, flat: Bool) {
        let side = 32
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return (1, false) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        // Per-channel range, so a white logo on yellow (similar brightness, different color) still counts.
        var low = [1.0, 1.0, 1.0], high = [0.0, 0.0, 0.0], opaque = 0
        for y in 0..<side {
            for x in 0..<side {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.5 else { continue }
                for (i, v) in [c.redComponent, c.greenComponent, c.blueComponent].enumerated() {
                    low[i] = min(low[i], v)
                    high[i] = max(high[i], v)
                }
                opaque += 1
            }
        }
        return (opaque, (0..<3).allSatisfy { high[$0] - low[$0] < 0.1 })
    }

    /// Repairs a blank SVG icon by making its background circle transparent, e.g. Simple Icons'
    /// Sony (white logo on a white circle): the logo then sits on the panel's dark background.
    /// Returns nil if nothing visible is left.
    static func repairedSVG(_ svg: String) -> NSImage? {
        let svg = SVGPathFixer.normalize(svg: svg)
        guard let circle = svg.range(of: "<circle"),
              let end = svg[circle.upperBound...].firstIndex(of: ">")
        else { return nil }
        let tag = String(svg[circle.lowerBound...end])
        var fixed = tag
            .replacingOccurrences(of: #"fill\s*=\s*"[^"]*""#, with: "fill=\"none\"", options: .regularExpression)
            .replacingOccurrences(of: #"fill\s*:\s*[^;"]+"#, with: "fill:none", options: .regularExpression)
        if fixed == tag { fixed = "<circle fill=\"none\"" + tag.dropFirst("<circle".count) }

        // The remaining logo is one color by design, so only require that something is visible.
        guard let image = NSImage(data: Data(svg.replacingCharacters(in: circle.lowerBound...end, with: fixed).utf8)),
              colorStats(image).opaque > 0
        else { return nil }
        return image
    }

    /// Rows redraw every second, so decoded images are cached by their data.
    private static var cache: [Data: NSImage] = [:]

    static func image(for data: Data) -> NSImage? {
        if let hit = cache[data] { return hit }
        guard let image = NSImage(data: data) else { return nil }
        if cache.count > 200 { cache.removeAll() }
        cache[data] = image
        return image
    }

    /// "GitHub", "git-hub.png" and "Git Hub" all become "github".
    static func matchKey(_ name: String) -> String {
        IconPack.matchKey(name)
    }
}
