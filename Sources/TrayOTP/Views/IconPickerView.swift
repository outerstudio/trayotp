import OTPCore
import SwiftUI

/// Pick an icon for a token from the installed Aegis icon pack.
@MainActor
struct IconPickerView: View {
    @Environment(AppState.self) private var state
    let token: Token
    @State private var search: String
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(52), spacing: 8), count: 5)

    init(token: Token) {
        self.token = token
        _search = State(initialValue: token.issuer ?? token.name)
    }

    var body: some View {
        let results = state.icons.pack?.search(search).prefix(150).map { $0 } ?? []

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { state.screen = .list } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Text("Icon for \(token.name)")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
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
            .background(Color.white.opacity(0.07), in: Capsule())

            Card {
                if results.isEmpty {
                    Text("No icons match “\(search)”")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(results, id: \.self) { icon in
                                IconCell(icon: icon)
                                    .onTapGesture { state.choosePackIcon(icon, for: token) }
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: 260)
                }
            }

            HStack(spacing: 8) {
                Button("Automatic") { state.setIcon(token, png: nil); state.screen = .list }
                    .help("Remove the chosen icon and use the pack's automatic match")
                Button("Cancel") { state.screen = .list }
                    .keyboardShortcut(.cancelAction)
            }
            .buttonStyle(PanelButtonStyle())
        }
        .padding(14)
        .onAppear { searchFocused = true }
    }
}

@MainActor
private struct IconCell: View {
    @Environment(AppState.self) private var state
    let icon: IconPack.Icon

    var body: some View {
        VStack(spacing: 3) {
            Group {
                if let image = state.icons.image(for: icon) {
                    Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
                } else {
                    Image(systemName: "questionmark").foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .frame(width: 40, height: 40)

            Text(icon.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 52)
        }
        .contentShape(Rectangle())
        .help(icon.displayName)
    }
}
