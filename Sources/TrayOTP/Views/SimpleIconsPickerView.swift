import OTPCore
import SwiftUI

@MainActor
struct SimpleIconsPickerView: View {
    @Environment(AppState.self) private var state
    @FocusState private var searchFocused: Bool
    @State private var search: String
    @State private var selection: SimpleIconsCatalog.Icon?
    @State private var downloadFailed = false
    @State private var catalog: SimpleIconsCatalog?
    @State private var catalogUnavailable = false
    @State private var loadAttempt = 0
    let token: Token
    let initialQuery: String?

    init(token: Token, initialQuery: String?) {
        self.token = token
        self.initialQuery = initialQuery
        _search = State(initialValue: initialQuery ?? token.issuer ?? token.name)
    }

    var body: some View {
        let results = catalog?.search(search, limit: 100) ?? []
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { state.screen = .list } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Text("Search Simple Icons")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search icons", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.primary.opacity(0.07), in: Capsule())
            .disabled(selection != nil)

            Card {
                if catalogUnavailable {
                    VStack(spacing: 8) {
                        Text("Could not load the Simple Icons catalog.")
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            catalogUnavailable = false
                            loadAttempt += 1
                        }
                        .buttonStyle(PanelButtonStyle())
                    }
                    .padding(12)
                } else if catalog == nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading Simple Icons…")
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else if results.isEmpty {
                    let empty = search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Text(empty ? "Enter a brand name." : "No icons match “\(search)”")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(results) { icon in
                                HStack(alignment: .firstTextBaseline) {
                                    Button { preview(icon) } label: {
                                        Text(icon.title).frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Download from jsDelivr")
                                    .disabled(selection != nil)
                                    if let license = icon.license, let url = license.link {
                                        Link(license.type, destination: url)
                                            .font(.caption)
                                    }
                                    if let url = icon.guidelines {
                                        Link(String(localized: "Brand Guidelines"), destination: url)
                                            .font(.caption)
                                    } else if let url = icon.source {
                                        Link(String(localized: "Source"), destination: url)
                                            .font(.caption)
                                    }
                                    Button("Preview") { preview(icon) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help("Download from jsDelivr")
                                        .disabled(selection != nil)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                            }
                        }
                    }
                    .frame(height: 250)
                }
            }

            Link(String(localized: "Simple Icons Disclaimer"), destination: SimpleIconsCatalog.disclaimerURL)
                .font(.caption)
            if downloadFailed {
                Text("Could not download the icon. Try again.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                Button("Cancel") { state.screen = .list }
                    .keyboardShortcut(.cancelAction)
                if selection != nil {
                    ProgressView().controlSize(.small)
                    Text("Fetching…").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PanelButtonStyle())
        }
        .padding(14)
        .onAppear { searchFocused = true }
        .task(id: loadAttempt) {
            let loaded = await SimpleIconsCatalogStore.shared.load()
            guard !Task.isCancelled else { return }
            catalog = loaded
            catalogUnavailable = loaded == nil
        }
        .task(id: selection?.id) {
            guard let selection else { return }
            let image = await state.fetchServiceIcon(selection)
            guard !Task.isCancelled, state.screen == .simpleIcons(token.id, query: initialQuery), !state.isLocked else { return }
            if let image {
                state.editIcon(token, image: image)
            } else {
                downloadFailed = true
                self.selection = nil
            }
        }
    }

    private func preview(_ icon: SimpleIconsCatalog.Icon) {
        downloadFailed = false
        selection = icon
    }
}
