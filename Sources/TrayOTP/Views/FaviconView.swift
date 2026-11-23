import OTPCore
import SwiftUI

/// Fetch a token's icon from its website's favicon, inside the panel: type the domain, preview and
/// zoom the result, then use it or cancel.
@MainActor
struct FaviconView: View {
    @Environment(AppState.self) private var state
    let token: Token
    @State private var domain: String
    @State private var phase = Phase.idle
    @FocusState private var domainFocused: Bool

    /// A fetched favicon lives in `state.iconDraft`, so it survives the panel closing.
    private enum Phase: Equatable {
        case idle
        case fetching
        case failed(String)
    }

    init(token: Token) {
        self.token = token
        _domain = State(initialValue: Favicon.guessDomain(name: token.name, issuer: token.issuer))
    }

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

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe").foregroundStyle(.secondary)
                        TextField("Website, e.g. github.com", text: $domain)
                            .textFieldStyle(.plain)
                            .focused($domainFocused)
                            .onSubmit(fetch)
                    }
                    Text("The icon is downloaded from DuckDuckGo, which will see this domain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            preview

            HStack(spacing: 8) {
                Button("Cancel") { state.screen = .list }
                    .keyboardShortcut(.cancelAction)
                if let draft = state.iconDraft, let png = draft.layout.png(draft.image) {
                    Button("Use Icon") { state.useIcon(png, for: token) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Fetch", action: fetch)
                        .keyboardShortcut(.defaultAction)
                        .disabled(phase == .fetching || domain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .buttonStyle(PanelButtonStyle())
        }
        .padding(14)
        .onAppear { domainFocused = true }
        // Editing the domain after a fetch asks for a new fetch.
        .onChange(of: domain) {
            if phase != .fetching {
                phase = .idle
                state.iconDraft = nil
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch phase {
        case .idle:
            if let draft = state.iconDraft { IconAdjuster(token: token, draft: draft) }
        case .fetching:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Fetching…").font(.caption).foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func fetch() {
        guard phase != .fetching else { return }
        guard let normalized = Favicon.normalizeDomain(domain) else {
            phase = .failed(String(localized: "Enter a domain like “plurk.com”."))
            return
        }
        phase = .fetching
        state.iconDraft = nil
        Task {
            if let image = await AppState.downloadFavicon(domain: normalized) {
                state.iconDraft = IconDraft(image: image, layout: .onWhiteCircle)
                phase = .idle
            } else {
                phase = .failed(String(localized: "No icon found for \(normalized). Check the domain, or use Set Icon from File…."))
            }
        }
    }
}
