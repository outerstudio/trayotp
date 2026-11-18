import SwiftUI

/// "Support TrayOTP" with the sponsor links as a 2×2 grid of pills. Shown in the About window and the update dialog.
struct SponsorLinks: View {
    /// Shown above the pills when given (the update dialog).
    var releaseNotes: URL?

    private static let symbols = ["cup.and.saucer.fill", "heart.fill", "gift.fill", "sparkles"]

    var body: some View {
        VStack(spacing: 10) {
            if let releaseNotes {
                Link(destination: releaseNotes) {
                    Label("Release Notes", systemImage: "doc.text")
                }
                .font(.system(size: 13, weight: .medium))
            }
            Text("Enjoying TrayOTP? Help keep it going.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(Dialogs.sponsorLinks.enumerated()), id: \.offset) { index, link in
                    Link(destination: link.url) {
                        Label { Text(verbatim: link.name) } icon: {
                            Image(systemName: Self.symbols[index % Self.symbols.count]).foregroundStyle(Theme.accent)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 280)
    }
}

struct AboutView: View {
    let version: String
    let releaseNotes: URL?
    let copyright: String

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text(verbatim: "TrayOTP").font(.system(size: 20, weight: .bold))
            Text("Version \(version)").font(.system(size: 12)).foregroundStyle(.secondary)
            SponsorLinks(releaseNotes: releaseNotes).padding(.top, 14)
            Text(verbatim: copyright)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
}
