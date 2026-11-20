import AppKit
import OTPCore
import SwiftUI

/// Root of the menu bar window, and of the floating window used when the menu bar icon is hidden.
@MainActor
struct PanelView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    /// Which window this is: the menu bar one or the floating one.
    let inMenuBar: Bool
    /// Whether the window is on screen. A closed panel is only ordered out and keeps its views,
    /// so the code countdowns pause on this rather than drawing for nobody.
    @State private var visible = true

    var body: some View {
        // Both windows can exist, and a hidden one keeps running its views: its search field would take
        // the text cursor from the visible panel. The window of the other mode shows nothing.
        if inMenuBar == state.showsMenuBarIcon {
            panel
        } else {
            Color.clear.frame(width: Theme.panelWidth, height: 1)
        }
    }

    private var panel: some View {
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
                case .favicon(let id):
                    if let token = state.tokens.first(where: { $0.id == id }) {
                        FaviconView(token: token)
                    } else {
                        TokenListView()
                    }
                case .iconEditor(let id):
                    if let token = state.tokens.first(where: { $0.id == id }), let draft = state.iconDraft {
                        IconEditorView(token: token, draft: draft)
                    } else {
                        TokenListView()
                    }
                }
            }
        }
        .frame(width: Theme.panelWidth)
        // A dark tint over the blur keeps the panel dark whatever is behind it; Deep Black replaces the blur.
        .background(state.appearance == .deepBlack ? Color.black : colorScheme == .dark ? Theme.panelTint : Color.clear)
        .environment(\.panelVisible, visible)
        .background(WindowSharing(hidden: state.hidesFromScreenSharing))
        .background(WindowFocusObserver(onVisibility: { visible = $0 }, onHide: { state.panelDidHide() }) {
            state.panelDidOpen()
        })
        .onExitCommand {
            if state.screen == .list { PanelController.shared.close() } else { state.screen = .list }
        }
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
    /// The selection last moved with the arrow keys; a click selects a row too but isn't this.
    @State private var arrowSelected = false
    /// A collapsed section the keyboard selection walked into. Shown open until the selection
    /// leaves it; unlike a click on the header, this isn't saved.
    @State private var peeked: String?
    @FocusState private var focus: Focus?
    /// Whether this list's window is on screen. Both panel windows (menu bar and floating) can exist,
    /// and a hidden one that still holds focus takes the text cursor from the visible one.
    @State private var onScreen = false

    /// Keyboard focus: the search field, or the token list (arrow keys move the selection).
    private enum Focus { case search, list }

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
        var result = savedSections
        if let peeked, let i = result.firstIndex(where: { $0.id == peeked }) { result[i].expanded = true }
        return result
    }

    /// Sections with their saved expanded state.
    private var savedSections: [Section] {
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

    /// Tokens in display order, for keyboard selection. Includes collapsed sections: ↑/↓ open them.
    private var filtered: [Token] { sections.flatMap(\.tokens) }

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
        // Delayed: focus set while the view is being inserted (e.g. right after unlocking) is dropped.
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Back from an icon screen: select the row it was opened from.
                if let id = state.listReturn, let index = filtered.firstIndex(where: { $0.id == id }) {
                    select(index)
                    focus = .list
                } else {
                    focus = .search
                }
                state.listReturn = nil
            }
        }
        // The window is reused, so onAppear doesn't run again: refocus search on every open.
        .background(WindowFocusObserver(onHide: { onScreen = false; focus = nil; arrowSelected = false }) {
            onScreen = true
            arrowSelected = false
            DispatchQueue.main.async { focus = .search; select(0) }
        })
        .onChange(of: state.focusRequest) {
            guard onScreen else { return }
            focus = .search
            select(0)
        }
        .onChange(of: search) { select(0) }
        .onChange(of: focus) { if focus != .list { peeked = nil; arrowSelected = false } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $search)
                    .textFieldStyle(.plain)
                    .focused($focus, equals: .search)
                    .onSubmit { copySelected() }
                    .onKeyPress(.downArrow) {
                        guard !filtered.isEmpty else { return .ignored }
                        select(0)
                        focus = .list
                        return .handled
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.primary.opacity(0.07), in: Capsule())

            SettingsMenu()
        }
    }

    private var list: some View {
        let sections = sections
        let items = sections.flatMap(\.tokens)
        let headers = sections.filter(\.showsHeader).count
        let canDrag = !isSearching
        let shown = sections.flatMap(\.visible).count
        let height = CGFloat(shown) * Theme.rowHeight + CGFloat(headers) * Theme.groupHeaderHeight

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
                                    GroupHeader(group: section.group, count: section.tokens.count,
                                                expanded: section.expanded, canDrag: canDrag) { toggle(section) }
                                }
                                ForEach(section.visible) { token in
                                    let index = items.firstIndex { $0.id == token.id } ?? -1
                                    TokenRow(token: token, isSelected: focus == .list && index == selection,
                                             keyboardSelected: arrowSelected)
                                        .id(token.id)
                                        .onTapGesture { state.copy(token) }
                                        // Any click, including on the next code, selects the row like ↑/↓.
                                        .simultaneousGesture(TapGesture().onEnded {
                                            arrowSelected = false
                                            select(index)
                                            focus = .list
                                        })
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
                    .focusable()
                    .focusEffectDisabled()
                    .focused($focus, equals: .list)
                    .onKeyPress(keys: [.downArrow]) { press in
                        if press.modifiers.contains(.command) { moveSelected(1) } else { moveSelection(1) }
                        return .handled
                    }
                    .onKeyPress(keys: [.upArrow]) { press in
                        if press.modifiers.contains(.command) {
                            moveSelected(-1)
                        } else if selection == 0 {
                            // Up from the first token goes back to the search field.
                            focus = .search
                        } else {
                            moveSelection(-1)
                        }
                        return .handled
                    }
                    .onKeyPress(.return) { copySelected(); return .handled }
                    .onKeyPress(.rightArrow) { copySelected(next: true) }
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
        Button("Edit…") { afterMenu { state.edit(token) } }
        Button("Export…") { afterMenu { state.showQRCode(token) } }
        Toggle("Always Hide Code", isOn: Binding(get: { token.hidesCode == true }, set: { state.setHidesCode(token, $0) }))
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
        // Only for a real icon (chosen, or matched from the pack), not colored initials.
        if let image = token.icon.flatMap(IconImage.image(for:)) ?? state.icons.image(for: token) {
            Button("Edit Icon…") { state.editIcon(token, image: image) }
        }
        if state.icons.pack != nil {
            Button("Choose Icon from Pack…") { open(.iconPicker(token.id), returningTo: token) }
        }
        Button("Set Icon from File…") { afterMenu { state.chooseIconFile(token) } }
        Button("Paste Icon") { afterMenu { state.pasteIcon(token) } }
        Button("Fetch Icon from Website…") { open(.favicon(token.id), returningTo: token) }
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
                Text("Paste an otpauth:// link, or import a backup from another authenticator app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Add or Import") { state.screen = .add }
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { state.screen = .add } label: { Label("Add", systemImage: "plus") }
                Button {
                    // Locking means done for now: close the panel. The lock screen shows on the next open.
                    state.lock()
                    PanelController.shared.close()
                } label: { Label("Lock", systemImage: "lock") }
                Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
            }
            if let release = state.updater.available {
                Button {
                    Task { await state.updater.offerAvailable() }
                } label: {
                    if state.updater.isInstalling {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Downloading…")
                        }
                    } else {
                        Label("Update to \(release.version?.description ?? release.tag)…", systemImage: "arrow.down.circle")
                    }
                }
                .disabled(state.updater.isBusy)
            }
        }
        .buttonStyle(PanelButtonStyle())
    }

    /// Opens another screen in the panel; coming back selects `token`, the row it was opened from.
    private func open(_ screen: AppState.Screen, returningTo token: Token) {
        state.listReturn = token.id
        state.iconDraft = nil
        state.screen = screen
    }

    private func moveSelection(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        arrowSelected = true
        select(min(max(selection + delta, 0), count - 1))
    }

    /// ⌘↑/⌘↓ moves the selected token one place. Past the end of its section it joins the
    /// neighbouring one: below that section's last token going up, above its first going down.
    private func moveSelected(_ delta: Int) {
        let items = filtered
        guard !isSearching, items.indices.contains(selection), items.indices.contains(selection + delta) else { return }
        let token = items[selection], neighbor = items[selection + delta]
        let section = savedSections.first { $0.tokens.contains { $0.id == token.id } }
        let sameSection = section?.tokens.contains { $0.id == neighbor.id } ?? false
        state.moveToken(token.id, nextTo: neighbor.id, after: (delta > 0) == sameSection)
        // Crossing into the next section keeps the token at the same place in the list.
        select(sameSection ? selection + delta : selection)
    }

    /// Selects a token by index in `filtered`, opening its section for now if it is collapsed.
    private func select(_ index: Int) {
        selection = index
        peeked = nil
        var end = 0
        for section in savedSections {
            end += section.tokens.count
            if index < end {
                if !section.expanded { peeked = section.id }
                return
            }
        }
    }

    /// Header click: closes a section the keyboard opened, otherwise flips and saves its state.
    private func toggle(_ section: Section) {
        if peeked == section.id {
            peeked = nil
        } else if let group = section.group {
            state.toggleExpanded(group)
        } else {
            state.toggleUngrouped()
        }
    }

    private func copySelected() {
        let items = filtered
        guard items.indices.contains(selection) else { return }
        state.copy(items[selection])
    }

    /// → copies the selected token's next code (HOTP tokens have none).
    private func copySelected(next: Bool) -> KeyPress.Result {
        let items = filtered
        guard items.indices.contains(selection), items[selection].kind != .hotp else { return .ignored }
        state.copy(items[selection], next: true)
        return .handled
    }
}

@MainActor
struct SettingsMenu: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Menu {
            Button("New Group…") { afterMenu { state.newGroup() } }
            Divider()
            Menu("Icon Pack") {
                if let pack = state.icons.pack {
                    Text("Icon Pack: \(pack.name)")
                    Text("\(pack.icons.count) icons, version \(pack.version)")
                    Divider()
                    Button("Replace…") { afterMenu { state.installIconPack() } }
                    Button("Remove") { state.icons.remove() }
                } else {
                    Button("Install Aegis Icon Pack…") { afterMenu { state.installIconPack() } }
                }
                Divider()
                Button("Import Icons from Folder…") {
                    afterMenu { if let url = Dialogs.openFolder() { state.importIcons(from: url) } }
                }
                .disabled(state.tokens.isEmpty)
            }
            Divider()
            if state.hasPasswordGate {
                Menu("Master Password") {
                    Button("Change…") { afterMenu { state.changeMasterPassword() } }
                    Button("Remove…") { afterMenu { state.removeMasterPassword() } }
                    Toggle("Unlock with Password Instead of Touch ID",
                           isOn: Binding(get: { state.hasMasterPassword }, set: { on in afterMenu { state.setUnlocksWithPassword(on) } }))
                    if !state.hasMasterPassword {
                        Divider()
                        Button("Forgot Password…") { afterMenu { state.forgotMasterPassword() } }
                    }
                }
            } else {
                Button("Set Master Password…") { afterMenu { state.setMasterPassword() } }
            }
            if state.hasPasswordGate {
                Menu("Password Reminder: \(AppState.reminderLabel(state.passwordReminderDays))") {
                    Picker("Password Reminder", selection: $state.passwordReminderDays) {
                        ForEach(AppState.reminderPresets, id: \.self) { days in
                            Text(AppState.reminderLabel(days)).tag(days)
                        }
                        if !AppState.reminderPresets.contains(state.passwordReminderDays) {
                            Text("Custom: \(AppState.reminderLabel(state.passwordReminderDays))").tag(state.passwordReminderDays)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Divider()
                    Button("Custom…") { afterMenu { state.setCustomReminder() } }
                }
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
            Button(state.shortcut.map { String(localized: "Global Shortcut: \($0.display)…") } ?? String(localized: "Set Global Shortcut…")) {
                afterMenu { state.editShortcut() }
            }
            Toggle("Show Menu Bar Icon", isOn: Binding(get: { state.showsMenuBarIcon }, set: { show in
                afterMenu { if show { state.showsMenuBarIcon = true } else { state.hideMenuBarIcon() } }
            }))
            Menu("Menu Bar Countdown") {
                Picker("Menu Bar Countdown", selection: $state.menuBarCountdown) {
                    Text("Off").tag(MenuBarCountdown.off)
                    Text("Until Stay Unlocked Ends").tag(MenuBarCountdown.untilGraceEnds)
                    Text("Until Locked").tag(MenuBarCountdown.untilLocked)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .disabled(!state.showsMenuBarIcon)
            Toggle("Close After Copying", isOn: $state.closesAfterCopy)
            Toggle("Clear Clipboard After 30 Seconds", isOn: $state.clearsClipboard)
            Menu("Hide Codes: \(AppState.codeHidingLabel(state.codeHiding))") {
                Picker("Hide Codes", selection: $state.codeHiding) {
                    ForEach(AppState.CodeHiding.allCases, id: \.self) { Text(AppState.codeHidingLabel($0)).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Toggle("Hide Panel from Screen Sharing", isOn: $state.hidesFromScreenSharing)
            Menu("Theme: \(AppState.appearanceLabel(state.appearance))") {
                Picker("Theme", selection: $state.appearance) {
                    ForEach(AppState.Appearance.allCases, id: \.self) { Text(AppState.appearanceLabel($0)).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Toggle("Launch at Login", isOn: Binding(get: { state.launchAtLogin },
                                                     set: { state.setLaunchAtLogin($0) }))
            Menu("Language") {
                Picker("Language", selection: Binding(get: { state.language },
                                                      set: { code in afterMenu { state.language = code } })) {
                    Text("System Default").tag(String?.none)
                    Divider()
                    ForEach(AppState.languages, id: \.self) { code in
                        Text(verbatim: AppState.languageName(code)).tag(Optional(code))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Divider()
            Menu("Backup & Export") {
                Button("Back Up Now") { afterMenu { state.backUpNow() } }
                    .disabled(state.tokens.isEmpty)
                if let last = state.lastBackup {
                    Text("Last backup: \(last.formatted(.relative(presentation: .named)))")
                } else {
                    Text("No backup yet")
                }
                Button("Restore from Backup…") { afterMenu { state.importBackup() } }
                Button("Choose Backup Folder…") { afterMenu { state.chooseBackupFolder() } }
                Divider()
                Menu("Backup Reminder: \(AppState.reminderLabel(state.backupReminderDays))") {
                    Picker("Backup Reminder", selection: $state.backupReminderDays) {
                        ForEach(AppState.reminderPresets, id: \.self) { days in
                            Text(AppState.reminderLabel(days)).tag(days)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Divider()
                Menu("Export to Another App") {
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
                    Section("Google Authenticator") {
                        Button("Google Authenticator (QR Codes)…") { afterMenu { state.exportToGoogle() } }
                    }
                    Section("Bitwarden") {
                        Button("Bitwarden (JSON)…") { afterMenu { state.exportBackup(as: .bitwarden, encrypted: false) } }
                    }
                    Section("Other Apps") {
                        Button("otpauth Links (Plain Text)…") { afterMenu { state.exportBackup(as: .linkList, encrypted: false) } }
                    }
                }
                .disabled(state.tokens.isEmpty)
            }
            Divider()
            Button("Check for Updates…") { afterMenu { Dialogs.updates(state.updater) } }
            Divider()
            // A brand name: the same in every language.
            Button("About TrayOTP") { afterMenu { Dialogs.about() } }
            Menu("Support TrayOTP") {
                ForEach(Dialogs.sponsorLinks, id: \.name) { link in
                    Button { NSWorkspace.shared.open(link.url) } label: {
                        Text(verbatim: link.name + "…")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if state.updater.available != nil {
                        Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                    }
                }
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
    /// As shown, which may differ from the saved state while the keyboard selection is inside.
    let expanded: Bool
    let canDrag: Bool
    let toggle: () -> Void
    @State private var targeted = false

    var body: some View {
        if let group {
            header(title: group.name)
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { toggle() } }
                .contextMenu { menu(group) }
                .modifier(DraggableIf(enabled: canDrag, payload: DragItem.group(group.id).payload, title: group.name))
        } else {
            header(title: String(localized: "Ungrouped"))
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { toggle() } }
                .contextMenu {
                    Button(expanded ? "Collapse" : "Expand") { toggle() }
                }
        }
    }

    private func header(title: String) -> some View {
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
        .background { Rectangle().fill(targeted ? Theme.accent.opacity(0.25) : Color.primary.opacity(0.03)) }
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
        Button(expanded ? "Collapse" : "Expand") { toggle() }
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

/// Calls `onFocus` each time the hosting window becomes key, i.e. every time the panel opens,
/// and `onHide` when the window goes off screen. `onVisibility` follows the window on and off screen.
struct WindowFocusObserver: NSViewRepresentable {
    var onVisibility: ((Bool) -> Void)?
    var onHide: (() -> Void)?
    let onFocus: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onFocus = onFocus
        view.onVisibility = onVisibility
        view.onHide = onHide
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onFocus = onFocus
        view.onVisibility = onVisibility
        view.onHide = onHide
    }

    final class ObserverView: NSView {
        var onFocus: (() -> Void)?
        var onVisibility: ((Bool) -> Void)?
        var onHide: (() -> Void)?
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            tokens.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in self?.onFocus?() })
            tokens.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self, weak window] _ in
                let visible = window?.occlusionState.contains(.visible) == true
                self?.onVisibility?(visible)
                if !visible { self?.onHide?() }
            })
            onVisibility?(window.occlusionState.contains(.visible))
            if window.isKeyWindow { onFocus?() }
        }
    }
}

/// Keeps the hosting window out of screen sharing, screenshots and recordings while `hidden`.
struct WindowSharing: NSViewRepresentable {
    let hidden: Bool

    func makeNSView(context: Context) -> SharingView { SharingView() }
    func updateNSView(_ view: SharingView, context: Context) { view.excluded = hidden }

    final class SharingView: NSView {
        var excluded = false { didSet { apply() } }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        private func apply() { window?.sharingType = excluded ? .none : .readOnly }
    }
}

private struct PanelVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether the panel's window is on screen; see `PanelView.visible`.
    var panelVisible: Bool {
        get { self[PanelVisibleKey.self] }
        set { self[PanelVisibleKey.self] = newValue }
    }
}
