import AppKit
import OTPCore
import SwiftUI

extension HexColor {
    init?(_ color: NSColor) {
        guard let c = color.usingColorSpace(.sRGB) else { return nil }
        func byte(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
        self.init(red: byte(c.redComponent), green: byte(c.greenComponent), blue: byte(c.blueComponent))
    }
}

/// An image waiting to become a token's icon, and how it's laid out. Kept in AppState so it survives
/// the panel closing, e.g. when the color sampler's click lands outside it.
struct IconDraft {
    var image: NSImage
    var layout: IconLayout
    /// What the reset button goes back to.
    let initial: IconLayout

    init(image: NSImage, layout: IconLayout = IconLayout(scale: 1)) {
        self.image = image
        self.layout = layout
        initial = layout
    }
}

/// How an image sits in its icon circle.
struct IconLayout: Equatable {
    /// Size relative to the circle: 1 fits it exactly, larger values crop it.
    var scale: Double
    /// Shift from the center, as a fraction of the circle's width (right and down are positive).
    var offset = CGSize.zero
    var background: HexColor?

    @MainActor func png(_ image: NSImage) -> Data? {
        IconImage.compose(image, scale: scale, offset: offset,
                          background: background.map { NSColor(srgbRed: CGFloat($0.red) / 255, green: CGFloat($0.green) / 255,
                                                                 blue: CGFloat($0.blue) / 255, alpha: 1) })
    }
}

/// Preview of a new icon next to the current one, with zoom, position and background controls.
/// Shared by every way of setting an icon (website, pack, file, clipboard).
@MainActor
struct IconAdjuster: View {
    @Environment(AppState.self) private var state
    let token: Token
    let draft: IconDraft

    @State private var dragStart: CGSize?
    @State private var colorText = ""

    private static let previewSide: CGFloat = 96

    /// Neutral tones, then the row badge colors.
    private static let palette: [HexColor] = [
        "#FFFFFF", "#D9D9D9", "#8E8E93", "#3A3A3C", "#000000", "#F2E6D0",
        "#EE4245", "#FF9500", "#FFCC00", "#34C759", "#30C7BF", "#5AADFA",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#1C3D5A",
    ].compactMap(HexColor.init(parsing:))

    private var image: NSImage { draft.image }
    /// The icon the row shows now: a chosen icon wins over the icon pack's automatic match.
    private var currentIcon: NSImage? { token.icon.flatMap(IconImage.image(for:)) ?? state.icons.image(for: token) }
    private var initial: IconLayout { draft.initial }
    private var layout: IconLayout {
        get { draft.layout }
        nonmutating set { state.iconDraft?.layout = newValue }
    }
    private var layoutBinding: Binding<IconLayout> {
        Binding(get: { state.iconDraft?.layout ?? draft.layout }, set: { state.iconDraft?.layout = $0 })
    }

    var body: some View {
        let color = Theme.color(for: token, icon: currentIcon)
        let png = layout.png(image)

        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(spacing: 4) {
                        ServiceAvatar(name: token.name, color: color, image: currentIcon)
                        Text("Current").font(.caption2).foregroundStyle(.secondary)
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    VStack(spacing: 4) {
                        ServiceAvatar(name: token.name, color: color, image: png.flatMap(IconImage.image(for:)))
                        Text("New").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    largePreview(png)
                }

                HStack(spacing: 8) {
                    Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                    Slider(value: layoutBinding.scale, in: 0.3...2)
                        .controlSize(.small)
                    Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                    Button("\(Int((layout.scale * 100).rounded()))%") {
                        layout.scale = initial.scale
                        layout.offset = .zero
                    }
                    .buttonStyle(.plain)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .help("Reset zoom and position")
                }

                backgroundPicker
            }
            .padding(12)
        }
        .onAppear { colorText = layout.background?.hex ?? "" }
        // A color set from outside the field (swatch, sampler) shows in it, without rewriting what's being typed.
        .onChange(of: layout.background) {
            if HexColor(parsing: colorText) != layout.background { colorText = layout.background?.hex ?? "" }
        }
    }

    /// Drag the image to move it within the circle.
    private func largePreview(_ png: Data?) -> some View {
        let side = Self.previewSide
        return ZStack {
            Circle().fill(Color.white.opacity(0.08))
            if let png, let large = IconImage.image(for: png) {
                Image(nsImage: large).resizable().interpolation(.high)
            }
        }
        .frame(width: side, height: side)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.15)))
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { drag in
                    let start = dragStart ?? layout.offset
                    dragStart = start
                    layout.offset = CGSize(width: clamp(start.width + drag.translation.width / side),
                                           height: clamp(start.height + drag.translation.height / side))
                }
                .onEnded { _ in dragStart = nil }
        )
        .onHover { inside in
            if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .help("Drag to move the image")
    }

    private func clamp(_ v: Double) -> Double { min(max(v, -1), 1) }

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background").font(.caption).foregroundStyle(.secondary)
            let columns = Array(repeating: GridItem(.fixed(20), spacing: 8), count: 10)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                swatch(nil, help: String(localized: "No background"))
                swatch(rowColor, help: String(localized: "Row color"))
                ForEach(Self.palette, id: \.self) { swatch($0, help: $0.hex) }
            }
            HStack(spacing: 6) {
                TextField("#RRGGBB or 255, 255, 255", text: $colorText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit(applyColorText)
                Button("Paste") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        colorText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        applyColorText()
                    }
                }
                .buttonStyle(PanelButtonStyle())
                .frame(width: 64)
                Button(action: sampleColor) { Image(systemName: "eyedropper") }
                    .buttonStyle(PanelButtonStyle())
                    .frame(width: 34)
                    .help("Pick a color from anywhere on the screen, e.g. the logo itself")
            }
            if !colorText.isEmpty, HexColor(parsing: colorText) == nil {
                Text("Use #RRGGBB, #RGB, rgb(r, g, b) or r, g, b.").font(.caption2).foregroundStyle(.orange)
            }
        }
        .onChange(of: colorText) { if let c = HexColor(parsing: colorText) { layout.background = c } }
    }

    /// macOS's color sampler (the loupe): returns one color the user clicks. Esc cancels.
    private func sampleColor() {
        NSColorSampler().show { picked in
            Task { @MainActor in
                if let color = picked.flatMap(HexColor.init) { state.iconDraft?.layout.background = color }
                // The sampler's click lands outside the panel, which closes it: bring it back.
                PanelController.shared.reopen()
            }
        }
    }

    private func applyColorText() {
        if let c = HexColor(parsing: colorText) { layout.background = c }
    }

    private var rowColor: HexColor? { HexColor(NSColor(Theme.color(for: token, icon: currentIcon))) }

    private func swatch(_ option: HexColor?, help: String) -> some View {
        let selected = option == layout.background
        return Button {
            layout.background = option
            colorText = option?.hex ?? ""
        } label: {
            ZStack {
                if let option {
                    Circle().fill(Color(red: Double(option.red) / 255, green: Double(option.green) / 255, blue: Double(option.blue) / 255))
                } else {
                    // "None": a slashed outline.
                    Circle().strokeBorder(Color.white.opacity(0.35))
                    Rectangle().fill(Color.red.opacity(0.8)).frame(width: 1.5, height: 18).rotationEffect(.degrees(45))
                }
            }
            .frame(width: 18, height: 18)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: selected ? 2 : 1).padding(-3))
            // The whole circle, ring included, takes clicks: "None" is otherwise see-through in the middle.
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// The adjuster as its own screen, for icons from the pack, a file or the clipboard.
@MainActor
struct IconEditorView: View {
    @Environment(AppState.self) private var state
    let token: Token
    let draft: IconDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { state.screen = .list } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Text("Icon for \(token.name)")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }

            IconAdjuster(token: token, draft: draft)

            HStack(spacing: 8) {
                Button("Cancel") { state.screen = .list }
                    .keyboardShortcut(.cancelAction)
                Button("Use Icon") {
                    if let png = draft.layout.png(draft.image) { state.useIcon(png, for: token) }
                }
                .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(PanelButtonStyle())
        }
        .padding(14)
    }
}
