import OTPCore
import SwiftUI

@MainActor
struct TokenRow: View {
    @Environment(AppState.self) private var state
    let token: Token
    let isSelected: Bool

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

                // Only the code and the ring tick. Ticking the whole row would rebuild its
                // context menu every second and close open submenus.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(token.code(at: context.date)?.otpGrouped ?? "Invalid secret")
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
                NextCode(token: token, color: color)
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
                // Computed from the clock on every frame (no implicit animation), so every row
                // shows the same fraction and a row scrolling into view doesn't animate in.
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let period = Double(max(token.period, 1))
                    let fraction = 1 - context.date.timeIntervalSince1970.truncatingRemainder(dividingBy: period) / period
                    Rectangle().fill(color.opacity(0.18))
                        .scaleEffect(x: fraction, anchor: .leading)
                }
            }
        }
        // An explicit Rectangle: a bare color background takes the Card's rounded container shape.
        .background { if isSelected { Rectangle().fill(Theme.selection) } }
        .contentShape(Rectangle())
    }
}

/// The upcoming code on the right of a TOTP row. Clicking it copies the next code instead of the
/// current one; it highlights on hover and flashes when copied (also by → in the list).
@MainActor
struct NextCode: View {
    @Environment(AppState.self) private var state
    let token: Token
    let color: Color
    @State private var hovering = false

    var body: some View {
        let copied = state.copiedNext == token.id

        TimelineView(.periodic(from: .now, by: 1)) { context in
            let next = context.date.addingTimeInterval(Double(token.period))
            VStack(alignment: .trailing, spacing: 1) {
                Text(copied ? "copied" : "next")
                    .font(.system(size: 10, weight: copied ? .semibold : .regular))
                Text(token.code(at: next)?.otpGrouped ?? "")
                    .font(.system(size: 13).monospacedDigit())
            }
            .foregroundStyle(copied ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(copied ? color.opacity(0.45) : Color.white.opacity(hovering ? 0.1 : 0))
        }
        .scaleEffect(copied ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: copied)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { state.copy(token, next: true) }
        .help("Click or press → to copy the next code")
    }
}

@MainActor
struct ServiceAvatar: View {
    let name: String
    let color: Color
    var image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: Circle())
                .clipShape(Circle())
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
