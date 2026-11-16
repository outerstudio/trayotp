import AppKit
import OTPCore
import SwiftUI

/// Root of the menu bar window.
@MainActor
struct PanelView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.isLocked {
                LockView()
            } else {
                switch state.screen {
                case .list:
                    TokenListView()
                case .add:
                    AddTokenView()
                case .iconPicker(let id):
                    if let token = state.tokens.first(where: { $0.id == id }) {
                        IconPickerView(token: token)
                    } else {
                        TokenListView()
                    }
                }
            }
        }
        .frame(width: Theme.panelWidth)
        .environment(\.colorScheme, .dark)
        .background(WindowFocusObserver { state.panelDidOpen() })
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                Text(toast)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThickMaterial, in: Capsule())
                    .padding(.bottom, 56)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.toast)
    }
}

@MainActor
struct TokenListView: View {
    @Environment(AppState.self) private var state
    @State private var search = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    /// A block of the list: ungrouped tokens (group nil) or one group.
    private struct Section: Identifiable {
        let group: TokenGroup?
        let tokens: [Token]
        /// Ungrouped gets a header (and drop target) only once groups exist.
        var showsHeader = true
        var expanded = true
        var id: String { group?.id ?? "ungrouped" }
        /// Tokens actually shown (collapsed sections hide theirs).
        var visible: [Token] { expanded ? tokens : [] }
    }

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }

    private var sections: [Section] {
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            // Searching shows matches from every group, collapsed or not, in one flat list.
            let hits = state.tokens.filter {
                [$0.name, $0.issuer ?? "", $0.account ?? ""].contains { $0.localizedCaseInsensitiveContains(q) }
            }
            return [Section(group: nil, tokens: hits, showsHeader: false)]
        }
        let known = Set(state.groups.map(\.id))
        let ungrouped = state.tokens.filter { $0.groupId.map { !known.contains($0) } ?? true }
        // Without groups there is no Ungrouped header, so it can't be collapsed (or stay collapsed).
        var result = state.groups.isEmpty
            ? [Section(group: nil, tokens: ungrouped, showsHeader: false)]
            : [Section(group: nil, tokens: ungrouped, expanded: state.ungroupedExpanded)]
        for group in state.groups {
            result.append(Section(group: group, tokens: state.tokens.filter { $0.groupId == group.id },
                                  expanded: group.isExpanded))
        }
        return result
    }

    /// Tokens in display order, for keyboard selection.
    private var filtered: [Token] { sections.flatMap(\.visible) }

    var body: some View {
        VStack(spacing: 12) {
            header
            if state.tokens.isEmpty {
                emptyState
            } else {
                list
            }
            footer
        }
        .padding(14)
        .onAppear { searchFocused = true }
        .onChange(of: search) { selection = 0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { copySelected() }
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.07), in: Capsule())

            SettingsMenu()
        }
    }

    private var list: some View {
        let sections = sections
        let items = sections.flatMap(\.visible)
        let headers = sections.filter(\.showsHeader).count
        let canDrag = !isSearching
        let height = CGFloat(items.count) * Theme.rowHeight + CGFloat(headers) * Theme.groupHeaderHeight

        return Card {
            if items.isEmpty && headers == 0 {
                Text(isSearching ? "No matches" : "No tokens")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sections) { section in
                                if section.showsHeader {
                                    GroupHeader(group: section.group, count: section.tokens.count, canDrag: canDrag)
                                }
                                ForEach(section.visible) { token in
                                    let index = items.firstIndex { $0.id == token.id } ?? -1
                                    TokenRow(token: token, isSelected: index == selection)
                                        .id(token.id)
                                        .onTapGesture { state.copy(token) }
                                        .contextMenu { rowMenu(token) }
                                        .modifier(TokenDrag(token: token, enabled: canDrag))
                                    if token.id != section.visible.last?.id {
                                        Divider().opacity(0.5).padding(.leading, 60)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: min(max(height, Theme.groupHeaderHeight), Theme.maxListHeight))
                    .onChange(of: selection) {
                        if items.indices.contains(selection) { proxy.scrollTo(items[selection].id) }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func rowMenu(_ token: Token) -> some View {
        Button("Copy Code") { state.copy(token) }
        if token.kind == .hotp {
            Button("Next Code") { state.incrementCounter(token) }
        } else {
            Button("Copy Next Code") { state.copy(token, next: true) }
        }
        Divider()
        Menu("Move to Group") {
            Picker("Move to Group", selection: Binding(get: { token.groupId }, set: { state.move(token, to: $0) })) {
                Text("Ungrouped").tag(String?.none)
                ForEach(state.groups) { group in
                    Text(group.name).tag(Optional(group.id))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            Button("New Group…") { afterMenu { state.moveToNewGroup(token) } }
        }
        Divider()
        if state.icons.pack != nil {
            Button("Choose Icon from Pack…") { state.screen = .iconPicker(token.id) }
        }
        Button("Set Icon from File…") { afterMenu { if let url = Dialogs.openImage() { state.setIcon(token, from: url) } } }
        Button("Paste Icon") { afterMenu { state.pasteIcon(token) } }
        Button("Fetch Icon from Website…") { afterMenu { state.fetchFavicon(token) } }
        if token.icon != nil {
            Button("Remove Icon") { state.setIcon(token, png: nil) }
        }
        Divider()
        Button("Delete…", role: .destructive) { afterMenu { state.delete(token) } }
    }

    private var emptyState: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No tokens yet").font(.headline)
                Text("Paste an otpauth:// link, or import from 2FAS, Aegis or Ente Auth.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Add Token") { state.screen = .add }
                    Button("Import…") { state.importBackup() }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { state.screen = .add } label: { Label("Add", systemImage: "plus") }
            Button { state.lock() } label: { Label("Lock", systemImage: "lock") }
                .disabled(!state.needsUnlock)
            Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
        }
        .buttonStyle(PanelButtonStyle())
    }

    private func moveSelection(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    private func copySelected() {
        let items = filtered
        guard items.indices.contains(selection) else { return }
        state.copy(items[selection])
    }
}

@MainActor
struct SettingsMenu: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Menu {
            Button("Import from 2FAS, Aegis or Ente…") { afterMenu { state.importBackup() } }
            Menu("Export") {
                Section("2FAS") {
                    Button("2FAS (Encrypted)…") { afterMenu { state.exportBackup(as: .twoFAS, encrypted: true) } }
                    Button("2FAS (Unencrypted)…") { afterMenu { state.exportBackup(as: .twoFAS, encrypted: false) } }
                }
                Section("Aegis") {
                    Button("Aegis (Encrypted)…") { afterMenu { state.exportBackup(as: .aegis, encrypted: true) } }
                    Button("Aegis (Unencrypted)…") { afterMenu { state.exportBackup(as: .aegis, encrypted: false) } }
                }
                Section("Ente Auth") {
                    Button("Ente Auth (Plain Text)…") { afterMenu { state.exportBackup(as: .ente, encrypted: false) } }
                }
            }
            .disabled(state.tokens.isEmpty)
            Divider()
            Button("New Group…") { afterMenu { state.newGroup() } }
            Divider()
            if let pack = state.icons.pack {
                Menu("Icon Pack: \(pack.name)") {
                    Text("\(pack.icons.count) icons, version \(pack.version)")
                    Button("Replace…") { afterMenu { state.installIconPack() } }
                    Button("Remove") { state.icons.remove() }
                }
            } else {
                Button("Install Aegis Icon Pack…") { afterMenu { state.installIconPack() } }
            }
            Button("Import Icons from Folder…") {
                afterMenu { if let url = Dialogs.openFolder() { state.importIcons(from: url) } }
            }
            .disabled(state.tokens.isEmpty)
            Divider()
            if state.hasMasterPassword {
                Menu("Master Password") {
                    Button("Change…") { afterMenu { state.setMasterPassword() } }
                    Button("Remove…") { afterMenu { state.removeMasterPassword() } }
                }
            } else {
                Button("Set Master Password…") { afterMenu { state.setMasterPassword() } }
                Toggle("Require Unlock", isOn: $state.requireAuth)
            }
            Menu("Stay Unlocked: \(AppState.graceLabel(state.graceMinutes))") {
                // An inline Picker gets native menu checkmarks; a Label's icon isn't drawn in menus.
                Picker("Stay Unlocked", selection: $state.graceMinutes) {
                    ForEach(AppState.gracePresets, id: \.self) { minutes in
                        Text(AppState.graceLabel(minutes)).tag(minutes)
                    }
                    if !AppState.gracePresets.contains(state.graceMinutes) {
                        Text("Custom: \(AppState.graceLabel(state.graceMinutes))").tag(state.graceMinutes)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Divider()
                Button("Custom…") { afterMenu { state.setCustomGrace() } }
            }
            .disabled(!state.needsUnlock)
            Toggle("Launch at Login", isOn: Binding(get: { state.launchAtLogin },
                                                     set: { state.launchAtLogin = $0 }))
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.07), in: Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// What is being dragged inside the list.
enum DragItem {
    case token(Token.ID)
    case group(String)

    var payload: String {
        switch self {
        case .token(let id): return "trayotp-token:\(id.uuidString)"
        case .group(let id): return "trayotp-group:\(id)"
        }
    }

    init?(_ payload: String) {
        if payload.hasPrefix("trayotp-token:"), let id = UUID(uuidString: String(payload.dropFirst(14))) {
            self = .token(id)
        } else if payload.hasPrefix("trayotp-group:") {
            self = .group(String(payload.dropFirst(14)))
        } else {
            return nil
        }
    }
}

/// Makes a token row draggable and a drop target: dropping a token on the top or bottom half
/// places it above or below this one, in this token's group.
@MainActor
struct TokenDrag: ViewModifier {
    @Environment(AppState.self) private var state
    let token: Token
    let enabled: Bool
    @State private var targeted = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(DragItem.token(token.id).payload) {
                    Label(token.name, systemImage: "line.3.horizontal")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .dropDestination(for: String.self) { items, location in
                    guard let first = items.first, case .token(let id) = DragItem(first) else { return false }
                    state.moveToken(id, nextTo: token.id, after: location.y > Theme.rowHeight / 2)
                    return true
                } isTargeted: { targeted = $0 }
                .overlay {
                    if targeted { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, lineWidth: 1.5) }
                }
        } else {
            content
        }
    }
}

/// Collapsible section header. Click to fold; right-click to rename, reorder or delete.
/// Tokens dropped on it move into the group; other headers dropped on it reorder the groups.
/// `group == nil` is the Ungrouped header.
@MainActor
struct GroupHeader: View {
    @Environment(AppState.self) private var state
    let group: TokenGroup?
    let count: Int
    let canDrag: Bool
    @State private var targeted = false

    var body: some View {
        if let group {
            header(title: group.name, expanded: group.isExpanded)
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { state.toggleExpanded(group) } }
                .contextMenu { menu(group) }
                .modifier(DraggableIf(enabled: canDrag, payload: DragItem.group(group.id).payload, title: group.name))
        } else {
            header(title: "Ungrouped", expanded: state.ungroupedExpanded)
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { state.toggleUngrouped() } }
                .contextMenu {
                    Button(state.ungroupedExpanded ? "Collapse" : "Expand") { state.toggleUngrouped() }
                }
        }
    }

    private func header(title: String, expanded: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: Theme.groupHeaderHeight)
        .background(targeted ? Theme.accent.opacity(0.25) : Color.white.opacity(0.03))
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard canDrag, let first = items.first, let item = DragItem(first) else { return false }
            switch item {
            case .token(let id):
                state.moveToken(id, toGroup: group?.id)
            case .group(let id):
                guard let group else { return false }
                state.moveGroup(id, before: group.id)
            }
            return true
        } isTargeted: { targeted = $0 && canDrag }
    }

    @ViewBuilder
    private func menu(_ group: TokenGroup) -> some View {
        let index = state.groups.firstIndex { $0.id == group.id } ?? 0
        Button(group.isExpanded ? "Collapse" : "Expand") { state.toggleExpanded(group) }
        Button("Rename…") { afterMenu { state.renameGroup(group) } }
        Divider()
        Button("Move Up") { state.moveGroup(group, by: -1) }.disabled(index == 0)
        Button("Move Down") { state.moveGroup(group, by: 1) }.disabled(index >= state.groups.count - 1)
        Divider()
        Button("Delete Group…", role: .destructive) { afterMenu { state.deleteGroup(group) } }
    }
}

private struct DraggableIf: ViewModifier {
    let enabled: Bool
    let payload: String
    let title: String

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(payload) {
                Label(title, systemImage: "folder")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
        } else {
            content
        }
    }
}

/// Runs a modal dialog after the current menu has closed. Opening one from inside the
/// menu's tracking loop leaves the dialog without keyboard focus.
@MainActor
func afterMenu(_ action: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async { action() }
}

/// Calls `onFocus` each time the hosting window becomes key, i.e. every time the panel opens.
struct WindowFocusObserver: NSViewRepresentable {
    let onFocus: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onFocus = onFocus
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onFocus = onFocus
    }

    final class ObserverView: NSView {
        var onFocus: (() -> Void)?
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
            guard let window else { return }
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in self?.onFocus?() }
            if window.isKeyWindow { onFocus?() }
        }
    }
}
