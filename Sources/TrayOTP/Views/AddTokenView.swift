import OTPCore
import SwiftUI

/// Add a token by pasting an otpauth:// link, a Base32 secret, or a QR code image.
@MainActor
struct AddTokenView: View {
    @Environment(AppState.self) private var state
    @State private var input = ""
    @State private var name = ""
    @FocusState private var inputFocused: Bool

    private var isLink: Bool {
        input.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("otpauth://")
    }

    private var parsed: Result<Token, Error> {
        Result { try TokenInput.parse(input, fallbackName: name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { state.screen = .list } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Text("Add Token").font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("otpauth://… link or Base32 secret", text: $input, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2...4)
                        .focused($inputFocused)

                    if !isLink {
                        Divider().opacity(0.5)
                        TextField("Name (e.g. GitHub)", text: $name)
                            .textFieldStyle(.plain)
                    }
                }
                .padding(12)
            }

            Button {
                if let text = Clipboard.readOTPInput() { input = text }
            } label: {
                Label("Paste Link, Secret or QR Image", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(PanelButtonStyle())

            preview

            HStack(spacing: 8) {
                Button("Cancel") { state.screen = .list }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { if case .success(let t) = parsed { state.add(t) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
            .buttonStyle(PanelButtonStyle())
        }
        .padding(14)
        .onAppear {
            inputFocused = true
            // Pre-fill if the clipboard already holds a link.
            if let text = Clipboard.readOTPInput(), text.lowercased().hasPrefix("otpauth://") { input = text }
        }
    }

    private var canAdd: Bool {
        guard case .success = parsed else { return false }
        return isLink || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var preview: some View {
        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch parsed {
            case .success(let token):
                Card { TokenRow(token: token, isSelected: false) }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            case .failure(let error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
