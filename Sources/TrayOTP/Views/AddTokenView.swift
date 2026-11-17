import OTPCore
import SwiftUI

/// Add a token by pasting an otpauth:// link, a Base32 secret or a QR code image, scanning a QR code,
/// or import a backup file from another app.
@MainActor
struct AddTokenView: View {
    @Environment(AppState.self) private var state
    @State private var input = ""
    @State private var name = ""
    @FocusState private var inputFocused: Bool

    private var isLink: Bool {
        input.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("otpauth://")
    }

    /// A Google Authenticator "Transfer accounts" code, which holds several accounts.
    private var isMigration: Bool { GoogleAuthenticator.isMigrationLink(input) }

    private var parsed: Result<Token, Error> {
        Result { try TokenInput.parse(input, fallbackName: name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { state.screen = .list } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Text("Add or Import").font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("otpauth://… link or Base32 secret", text: $input, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2...4)
                        .focused($inputFocused)

                    if !isLink && !isMigration {
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

            Button {
                state.scanWithCamera()
            } label: {
                Label("Scan QR Code with Camera…", systemImage: "camera.viewfinder")
            }
            .buttonStyle(PanelButtonStyle())
            .help("For QR codes on another device, like Google Authenticator's Transfer accounts screen")

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    state.importBackup()
                } label: {
                    Label("Import from File…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PanelButtonStyle())
                Text("2FAS, Aegis, Ente Auth, Bitwarden, Proton Authenticator, Stratum, andOTP, FreeOTP+, Raivo OTP, password manager CSVs, or a photo of a QR code. For Google Authenticator, use Scan QR Code with Camera, or see the [README](https://github.com/outerstudio/trayotp#import-and-export) for other ways.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            preview

            HStack(spacing: 8) {
                Button("Cancel") { state.screen = .list }
                    .keyboardShortcut(.cancelAction)
                if isMigration {
                    Button("Import Accounts") { state.importText(input) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Add") { if case .success(let t) = parsed { state.add(t) } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canAdd)
                }
            }
            .buttonStyle(PanelButtonStyle())
        }
        .padding(14)
        .onAppear {
            inputFocused = true
            if let scanned = state.scannedInput {
                input = scanned
                state.scannedInput = nil
                return
            }
            // Pre-fill if the clipboard already holds a link.
            if let text = Clipboard.readOTPInput(), text.lowercased().hasPrefix("otpauth") { input = text }
        }
    }

    private var canAdd: Bool {
        guard case .success = parsed else { return false }
        return isLink || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var preview: some View {
        if isMigration {
            Label("Google Authenticator transfer code. Import adds all the accounts it holds; if Google showed several QR codes, import each one.",
                  systemImage: "square.and.arrow.down.on.square")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
