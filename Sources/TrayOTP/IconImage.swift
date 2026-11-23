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

    /// An icon as the rows show it: the bare image centered in a square, or, with a background
    /// color, inside a circle of that color.
    /// `scale` is the image's size relative to the square: 1 fits it exactly, larger values crop it.
    /// `offset` moves it from the center, as a fraction of the square's width (right and down are positive).
    static func compose(_ image: NSImage, scale: CGFloat, offset: CGSize = .zero, background: NSColor?) -> Data? {
        let source = image.size
        guard source.width > 0, source.height > 0 else { return nil }
        let side = CGFloat(pixelSize)
        let fit = side * scale / max(source.width, source.height)
        let size = NSSize(width: source.width * fit, height: source.height * fit)
        let composed = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            if let background {
                let circle = NSBezierPath(ovalIn: rect)
                background.setFill()
                circle.fill()
                circle.addClip()
            }
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

    /// Monochrome logos can be valid, so only test visibility when loading one.
    static func hasVisiblePixels(_ image: NSImage) -> Bool {
        colorStats(image).opaque > 0
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

    /// Main colors by image, holding the image so its identifier can't be reused.
    private static var mainColors: [ObjectIdentifier: (image: NSImage, color: NSColor?)] = [:]

    /// The icon's most common saturated hue, brightened to read on the dark panel. Nil for
    /// black, white or gray logos, which fall back to the name's color.
    static func mainColor(_ image: NSImage) -> NSColor? {
        if let hit = mainColors[ObjectIdentifier(image)] { return hit.color }
        let side = 32
        var color: NSColor?
        if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
            NSGraphicsContext.restoreGraphicsState()

            // 24 hue buckets, each pixel weighted by its saturation; the heaviest bucket wins.
            var weight = [Double](repeating: 0, count: 24), opaque = 0.0
            var sums = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: 24)
            for y in 0..<side {
                for x in 0..<side {
                    guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.5 else { continue }
                    opaque += 1
                    guard c.saturationComponent > 0.25, c.brightnessComponent > 0.2 else { continue }
                    let i = min(Int(c.hueComponent * 24), 23)
                    let w = c.saturationComponent
                    weight[i] += w
                    sums[i].r += c.redComponent * w
                    sums[i].g += c.greenComponent * w
                    sums[i].b += c.blueComponent * w
                }
            }
            // Ignore a few colored pixels from anti-aliasing or a tiny accent.
            if let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > opaque * 0.05 {
                let w = weight[best]
                let average = NSColor(deviceRed: sums[best].r / w, green: sums[best].g / w, blue: sums[best].b / w, alpha: 1)
                color = NSColor(deviceHue: average.hueComponent, saturation: max(average.saturationComponent, 0.45),
                                brightness: max(average.brightnessComponent, 0.75), alpha: 1)
            }
        }
        if mainColors.count > 200 { mainColors.removeAll() }
        mainColors[ObjectIdentifier(image)] = (image, color)
        return color
    }

    /// Makes a pack icon drawn as a logo on a full-size background circle (like Aegis Simple Icons)
    /// flat, like 2FAS: the circle is removed, a one-color logo takes the circle's brand color
    /// (lightened, or white, when too dark for the panel), and the image is cropped to the logo.
    /// Nil if the SVG has no background circle or nothing visible is left.
    static func flattenedSVG(_ svg: String) -> NSImage? {
        let svg = SVGPathFixer.normalize(svg: svg)
        guard let circle = svg.range(of: "<circle"),
              let end = svg[circle.upperBound...].firstIndex(of: ">"),
              let box = viewBox(svg)
        else { return nil }
        let tag = String(svg[circle.lowerBound...end])
        // Only a circle that fills the canvas is a background; smaller ones are part of the logo.
        guard let cx = number("cx", in: tag), let cy = number("cy", in: tag), let r = number("r", in: tag),
              abs(cx - box.midX) < box.width * 0.05, abs(cy - box.midY) < box.height * 0.05,
              r >= min(box.width, box.height) * 0.45
        else { return nil }
        let brand = fillColor(tag)
        var fixed = tag
            .replacingOccurrences(of: #"fill\s*=\s*"[^"]*""#, with: "fill=\"none\"", options: .regularExpression)
            .replacingOccurrences(of: #"fill\s*:\s*[^;"]+"#, with: "fill:none", options: .regularExpression)
        if fixed == tag { fixed = "<circle fill=\"none\"" + tag.dropFirst("<circle".count) }
        guard let logo = NSImage(data: Data(svg.replacingCharacters(in: circle.lowerBound...end, with: fixed).utf8)),
              logo.size.width > 0, logo.size.height > 0
        else { return nil }

        let side = 160
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        logo.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        let stats = colorStats(logo)
        guard stats.opaque > 0 else { return nil }
        // Raw RGBA bytes, premultiplied, rows top-down (like CGImage's).
        guard let pixels = rep.bitmapData else { return nil }
        let row = rep.bytesPerRow
        var bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int) = (side, side, -1, -1)
        var logoColor: NSColor?
        for y in 0..<side {
            for x in 0..<side {
                let p = pixels + y * row + x * 4
                guard p[3] > 5 else { continue }
                bounds = (min(bounds.minX, x), min(bounds.minY, y), max(bounds.maxX, x), max(bounds.maxY, y))
                if logoColor == nil, p[3] > 230 {
                    let a = CGFloat(p[3])
                    logoColor = NSColor(deviceRed: CGFloat(p[0]) / a, green: CGFloat(p[1]) / a, blue: CGFloat(p[2]) / a, alpha: 1)
                }
            }
        }
        guard bounds.maxX >= bounds.minX else { return nil }

        // A one-color logo is repainted; a multicolor one keeps its own colors.
        if stats.flat {
            let readableColor = readable(brand) ?? readable(logoColor) ?? .white
            let target = readableColor.usingColorSpace(.deviceRGB) ?? readableColor
            let rgb = [target.redComponent, target.greenComponent, target.blueComponent]
            for y in bounds.minY...bounds.maxY {
                for x in bounds.minX...bounds.maxX {
                    let p = pixels + y * row + x * 4
                    for i in 0..<3 { p[i] = UInt8((rgb[i] * CGFloat(p[3])).rounded()) }
                }
            }
        }
        let crop = CGRect(x: bounds.minX, y: bounds.minY,
                          width: bounds.maxX - bounds.minX + 1, height: bounds.maxY - bounds.minY + 1)
        guard let cropped = rep.cgImage?.cropping(to: crop) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: crop.width / 2, height: crop.height / 2))
    }

    /// The color as it reads on the dark panel: dark saturated colors are lightened toward white,
    /// dark grays and black give nil.
    private static func readable(_ color: NSColor?) -> NSColor? {
        guard var color = color?.usingColorSpace(.sRGB) else { return nil }
        func luminance(_ c: NSColor) -> CGFloat {
            func linear(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
        }
        if luminance(color) >= 0.1 { return color }
        guard color.saturationComponent > 0.25 else { return nil }
        for _ in 0..<6 where luminance(color) < 0.1 {
            color = color.blended(withFraction: 0.15, of: .white) ?? color
        }
        return color
    }

    /// The SVG's viewBox, or its width and height.
    private static func viewBox(_ svg: String) -> CGRect? {
        guard let open = svg.range(of: "<svg"), let end = svg[open.upperBound...].firstIndex(of: ">") else { return nil }
        let tag = String(svg[open.lowerBound...end])
        if let range = tag.range(of: #"viewBox\s*=\s*"[^"]*""#, options: .regularExpression) {
            let values = tag[range].drop { $0 != "\"" }.dropFirst().dropLast()
                .split { $0 == " " || $0 == "," }.compactMap { Double($0) }
            if values.count == 4, values[2] > 0, values[3] > 0 { return CGRect(x: values[0], y: values[1], width: values[2], height: values[3]) }
        }
        guard let w = number("width", in: tag), let h = number("height", in: tag), w > 0, h > 0 else { return nil }
        return CGRect(x: 0, y: 0, width: w, height: h)
    }

    /// A numeric attribute such as `r="12"` (units like "px" are ignored).
    private static func number(_ name: String, in tag: String) -> CGFloat? {
        guard let range = tag.range(of: #"(^|\s)\#(name)\s*=\s*"[-0-9.]+"#, options: .regularExpression) else { return nil }
        return Double(tag[range].drop { $0 != "\"" }.dropFirst()).map { CGFloat($0) }
    }

    /// The fill of an SVG tag, from a `fill` attribute or style: `#rgb`, `#rrggbb`, white or black.
    private static func fillColor(_ tag: String) -> NSColor? {
        guard let range = tag.range(of: #"fill\s*[=:]\s*"?[#a-zA-Z0-9]+"#, options: .regularExpression) else { return nil }
        var value = String(tag[range].drop { $0 != "=" && $0 != ":" }.dropFirst())
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" ")).lowercased()
        switch value {
        case "white": return .white
        case "black": return .black
        default: break
        }
        guard value.hasPrefix("#") else { return nil }
        value.removeFirst()
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
                       blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
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
