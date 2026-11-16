import OTPCore
import SwiftUI

enum Theme {
    static let panelWidth: CGFloat = 340
    static let rowHeight: CGFloat = 68
    static let groupHeaderHeight: CGFloat = 28
    static let maxListHeight: CGFloat = 5 * rowHeight + 20
    static let accent = Color(red: 0.96, green: 0.36, blue: 0.24)

    static let cardFill = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.08)
    static let selection = Color.white.opacity(0.08)

    /// 2FAS badge color names → colors. Tokens without a badge get a stable color from their name.
    static func color(for token: Token) -> Color {
        switch token.color?.lowercased() {
        case "red": return Color(red: 0.93, green: 0.26, blue: 0.27)
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "turquoise": return Color(red: 0.19, green: 0.78, blue: 0.75)
        case "lightblue": return Color(red: 0.35, green: 0.68, blue: 0.98)
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        default:
            let palette: [Color] = [.teal, .blue, .indigo, .purple, .pink, .orange, .green, .mint]
            let hash = token.name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            return palette[hash % palette.count]
        }
    }
}

/// Rounded card used for the token list, like the panels in the reference screenshot.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardStroke))
    }
}

/// Wide bottom buttons ("Add", "Lock", "Quit").
struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardStroke))
            .contentShape(Rectangle())
    }
}
