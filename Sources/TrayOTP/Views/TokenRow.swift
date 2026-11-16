import OTPCore
import SwiftUI

@MainActor
struct TokenRow: View {
    @Environment(AppState.self) private var state
    let token: Token
    let isSelected: Bool

    var body: some View {
        let color = Theme.color(for: token)

        HStack(spacing: 12) {
            // A chosen icon wins over the icon pack's automatic match.
            ServiceAvatar(name: token.name, color: color,
                          image: token.icon.flatMap(IconImage.image(for:)) ?? state.icons.image(for: token))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(token.name)
                        .font(.system(size: 12, weight: .medium))
                    if let subtitle = token.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .lineLimit(1)
                .foregroundStyle(.secondary)

                // Only the code and the ring tick. Ticking the whole row would rebuild its
                // context menu every second and close open submenus.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = token.secondsRemaining(at: context.date)
                    Text(token.code(at: context.date)?.otpGrouped ?? "Invalid secret")
                        .font(.system(size: 24, weight: .regular).monospacedDigit())
                        .foregroundStyle(token.kind != .hotp && remaining <= 5 ? Color.red.opacity(0.9) : .primary)
                        .contentTransition(.numericText())
                }
            }

            Spacer(minLength: 4)

            if token.kind == .hotp {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .help("Counter-based code. Right-click → Next code.")
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    CountdownRing(remaining: token.secondsRemaining(at: context.date), period: token.period)
                }
                .frame(width: 26, height: 26)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.rowHeight)
        .background(alignment: .leading) {
            // Colored accent bar like the 2FAS list.
            Rectangle().fill(color).frame(width: 3)
        }
        .background(isSelected ? Theme.selection : .clear)
        .contentShape(Rectangle())
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

struct CountdownRing: View {
    let remaining: Int
    let period: Int

    var body: some View {
        let warn = remaining <= 5
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 2)
            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(period, 1)))
                .stroke(warn ? Color.red : Color.white.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(remaining)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(warn ? Color.red : .secondary)
        }
    }
}
