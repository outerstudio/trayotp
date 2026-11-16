import AppKit
import SwiftUI

@MainActor
struct LockView: View {
    @Environment(AppState.self) private var state
    @State private var password = ""
    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            // Same symbol as the tray icon.
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 44, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Theme.accent.gradient)
                .padding(.top, 10)

            Text("TrayOTP is locked")
                .font(.system(size: 15, weight: .semibold))

            if let message = state.lockMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if state.hasMasterPassword {
                SecureField("Master password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .focused($passwordFocused)
                    .disabled(state.authInProgress)
                    .onSubmit(unlockWithPassword)
                    .onAppear { passwordFocused = true }

                Button(action: unlockWithPassword) {
                    Label(state.authInProgress ? "Unlocking…" : "Unlock", systemImage: "key")
                }
                .buttonStyle(PanelButtonStyle())
                .disabled(state.authInProgress || password.isEmpty)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    Task { await state.unlock() }
                } label: {
                    Label(state.authInProgress ? "Waiting…" : "Unlock", systemImage: "lock.open")
                }
                .buttonStyle(PanelButtonStyle())
                .disabled(state.authInProgress)
                .keyboardShortcut(.defaultAction)
            }

            Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
                .buttonStyle(PanelButtonStyle())
        }
        .padding(20)
    }

    private func unlockWithPassword() {
        let typed = password
        guard !typed.isEmpty else { return }
        Task {
            await state.unlock(password: typed)
            password = ""
            passwordFocused = true
        }
    }
}
