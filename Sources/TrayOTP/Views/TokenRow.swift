import OTPCore
import SwiftUI

@MainActor
struct TokenRow: View {
    @Environment(AppState.self) private var state
    @Environment(\.panelVisible) private var visible
    let token: Token
    let isSelected: Bool
    @State private var hovering = false

    /// Whether the code shows: not hidden, revealed by a click or copy, or (Until Hover) under the pointer
    /// or the keyboard selection. A token that hides on its own while the global setting is Never reveals by click.
    private var shown: Bool {
        !state.hidesCode(token) || state.revealed.contains(token.id)
            || (state.codeHiding == .hover && (hovering || isSelected))
    }

    var body: some View {
        // A chosen icon wins over the icon pack's automatic match.
        let icon = token.icon.flatMap(IconImage.image(for:)) ?? state.icons.image(for: token)
        let color = Theme.color(for: token, icon: icon)

        HStack(spacing: 12) {
            ServiceAvatar(name: token.name, color: color, image: icon)

            VStack(alignment: .leading, spacing: 0) {
                // Name, code, then account on its own line, so a long account doesn't cut off the name.
                Text(token.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                // Only the code ticks, when it changes. Ticking the whole row would rebuild its
                // context menu and close open submenus.
                TimelineView(CodeSchedule(period: token.period, paused: !visible)) { context in
                    Text(token.code(at: context.date)?.otpGrouped.masked(unless: shown) ?? String(localized: "Invalid secret"))
                        .font(.system(size: 24, weight: .regular).monospacedDigit())
                        .contentTransition(.numericText())
                }
                if let subtitle = token.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)

            if token.kind == .hotp {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .help("Counter-based code. Right-click → Next code.")
            } else {
                // The upcoming code, like Ente Auth.
                NextCode(token: token, color: color, shown: shown)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.rowHeight)
        .background(alignment: .leading) {
            // Colored accent bar like the 2FAS list.
            Rectangle().fill(color).frame(width: 3)
        }
        .background {
            if token.kind != .hotp {
                // Time left on the current code, as a translucent fill behind the whole row.
                CountdownFill(period: token.period, color: NSColor(color.opacity(0.18)))
            }
        }
        // An explicit Rectangle: a bare color background takes the Card's rounded container shape.
        .background { if isSelected { Rectangle().fill(Theme.selection) } }
        .contentShape(Rectangle())
        .overlay(HoverTracker { hovering = $0 })
        // A copy wiggles the row (or just its next code) for about 0.7 s.
        .modifier(Shake(token: token.id, next: false))
    }
}

/// The upcoming code on the right of a TOTP row. Clicking it copies the next code instead of the
/// current one; it highlights on hover and flashes when copied (also by → in the list).
@MainActor
struct NextCode: View {
    @Environment(AppState.self) private var state
    @Environment(\.panelVisible) private var visible
    let token: Token
    let color: Color
    let shown: Bool
    @State private var hovering = false

    var body: some View {
        let copied = state.copiedNext == token.id

        TimelineView(CodeSchedule(period: token.period, paused: !visible)) { context in
            let next = context.date.addingTimeInterval(Double(token.period))
            VStack(alignment: .trailing, spacing: 1) {
                Text(copied ? "copied" : "next")
                    .font(.system(size: 10, weight: copied ? .semibold : .regular))
                Text(token.code(at: next)?.otpGrouped.masked(unless: shown) ?? "")
                    .font(.system(size: 13).monospacedDigit())
            }
            .foregroundStyle(copied ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(copied ? color.opacity(0.45) : Color.primary.opacity(hovering ? 0.1 : 0))
        }
        .scaleEffect(copied ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: copied)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .modifier(Shake(token: token.id, next: true))
        .onTapGesture { state.copy(token, next: true) }
        .help("Click or press → to copy the next code")
    }
}

/// Updates when TOTP codes of `period` seconds change (whole multiples of it since 1970), not every
/// second; nothing while `paused`, e.g. while the panel is closed. Unpausing starts a new schedule,
/// so the view catches up at once.
struct CodeSchedule: TimelineSchedule {
    let period: Int
    let paused: Bool

    func entries(from start: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        let period = Double(max(period, 1))
        var next: Date? = start
        return AnyIterator {
            defer {
                next = paused ? nil : next.map {
                    // Rounding can land on the date itself at a change; never repeat a date.
                    let time = $0.timeIntervalSince1970
                    return Date(timeIntervalSince1970: max(((time / period).rounded(.down) + 1) * period, time + 0.001))
                }
            }
            return next
        }
    }
}

/// Time left on the current code, as a fill that shrinks to the left. Core Animation runs it in the
/// render server: a SwiftUI fill redrawn on every frame redraws the whole panel, about 30 times a
/// second for as long as the app runs (a closed panel is only ordered out). It is set from the
/// clock, so every row shows the same fraction and a row scrolling into view doesn't animate in,
/// and set again when the window comes back on screen or the Mac wakes, as the animation clock
/// stops during sleep.
struct CountdownFill: NSViewRepresentable {
    let period: Int
    let color: NSColor

    func makeNSView(context: Context) -> FillView { FillView() }

    func updateNSView(_ view: FillView, context: Context) {
        view.update(period: TimeInterval(max(period, 1)), color: color.cgColor)
    }

    final class FillView: NSView {
        private let fill = CALayer()
        private var period: TimeInterval = 30
        private var observers: [(NotificationCenter, NSObjectProtocol)] = []

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            fill.anchorPoint = CGPoint(x: 0, y: 0.5)
            layer?.addSublayer(fill)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        deinit { observers.forEach { $0.0.removeObserver($0.1) } }

        // Clicks and right-clicks belong to the row.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func update(period: TimeInterval, color: CGColor) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fill.backgroundColor = color
            CATransaction.commit()
            if period != self.period {
                self.period = period
                sync()
            }
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fill.bounds = bounds
            fill.position = CGPoint(x: bounds.minX, y: bounds.midY)
            CATransaction.commit()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach { $0.0.removeObserver($0.1) }
            observers = []
            guard let window else { return }
            let resync: @Sendable (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated { self?.sync() }
            }
            let center = NotificationCenter.default, workspace = NSWorkspace.shared.notificationCenter
            observers.append((center, center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main, using: resync)))
            observers.append((workspace, workspace.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: resync)))
            sync()
        }

        /// (Re)starts the drain so it lines up with the clock.
        private func sync() {
            let phase = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
            let drain = CABasicAnimation(keyPath: "transform.scale.x")
            drain.fromValue = 1
            drain.toValue = 0
            drain.duration = period
            drain.repeatCount = .infinity
            drain.beginTime = fill.convertTime(CACurrentMediaTime(), from: nil) - phase
            fill.add(drain, forKey: "drain")
        }
    }
}

@MainActor
struct ServiceAvatar: View {
    let name: String
    let color: Color
    var image: NSImage?

    var body: some View {
        if let image {
            // The bare logo, no circle behind it (like 2FAS), a little inset so it doesn't
            // look larger than the initials badges.
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: 36, height: 36)
        } else {
            Text(initials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient, in: Circle())
        }
    }

    private var initials: String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        if words.count >= 2 { return String(words[0].prefix(1) + words[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

/// Wiggles its view for about 0.7 s when `AppState` asks for it: the row's whole content
/// (`next` false) or just its next-code area (`next` true).
@MainActor
private struct Shake: ViewModifier {
    @Environment(AppState.self) private var state
    let token: Token.ID
    let next: Bool
    @State private var shakes = 0

    func body(content: Content) -> some View {
        content
            .onChange(of: state.shakeCount) {
                if state.shakenRow == token, state.shakesNext == next { shakes += 1 }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, dx in
                content.offset(x: dx)
            } keyframes: { _ in
                KeyframeTrack {
                    for dx in [8.0, -8, 6, -6, 4, -4, 2, -2, 0] {
                        CubicKeyframe(dx, duration: 0.078)
                    }
                }
            }
    }
}

private extension String {
    /// The same text with every character but the spaces turned into dots, so the layout doesn't move.
    func masked(unless shown: Bool) -> String {
        shown ? self : String(map { $0 == " " ? " " : "•" })
    }
}

/// Reports whether the pointer is over the view. SwiftUI's `onHover` misses the exit when a menu opens
/// and closes over the row, leaving it "hovered" for good; this tracks with `.activeAlways` and checks the
/// real pointer position again on every update.
private struct HoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: TrackerView, context: Context) {
        view.onChange = onChange
        DispatchQueue.main.async { view.sync() }
    }

    final class TrackerView: NSView {
        var onChange: ((Bool) -> Void)?
        private var inside = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
            sync()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            sync()
        }

        override func mouseEntered(with event: NSEvent) { set(true) }
        override func mouseExited(with event: NSEvent) { set(false) }

        /// Sets the state from where the pointer really is.
        func sync() {
            guard let window, window.isVisible else { set(false); return }
            set(bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)))
        }

        private func set(_ value: Bool) {
            guard value != inside else { return }
            inside = value
            onChange?(value)
        }
    }
}
