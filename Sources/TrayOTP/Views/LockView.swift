import AppKit
import SwiftUI

@MainActor
struct LockView: View {
    @Environment(AppState.self) private var state
    @State private var password = ""
    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            // The app icon, its ring counting down. It has ~10% transparent margin, so 56 pt shows a ~45 pt tile.
            LockIcon(spinner: state.iconSpinner)
                .frame(width: 56, height: 56)
                .padding(.top, 6)
                .accessibilityHidden(true)

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
            } else if let touchIDView = state.touchIDView {
                VStack(spacing: 6) {
                    TouchIDHost(view: touchIDView).frame(width: 56, height: 56)
                    Text("Touch ID to unlock").font(.caption).foregroundStyle(.secondary)
                }
                .id(ObjectIdentifier(touchIDView))

                Button {
                    Task { await state.unlock(alert: true) }
                } label: {
                    Label("Use Password…", systemImage: "key")
                }
                .buttonStyle(PanelButtonStyle())
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
        .background {
            // Esc closes the panel. Nothing here takes focus (unless there's a password field), so the
            // panel's onExitCommand never sees the key; a window shortcut does.
            Button("") { PanelController.shared.close() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    private func unlockWithPassword() {
        let typed = password
        guard !typed.isEmpty else { return }
        Task {
            await state.unlock(password: typed)
            password = ""
            // After a successful unlock this view is gone and the token list takes focus.
            if state.isLocked { passwordFocused = true }
        }
    }
}

/// Shows the inline Touch ID view. A hidden panel window keeps updating its views too, and an NSView
/// lives in one window only, so the view moves in only while this window is on screen.
struct TouchIDHost: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> Container { Container() }
    func updateNSView(_ container: Container, context: Context) { container.content = view }

    final class Container: NSView {
        var content: NSView? { didSet { attach() } }

        override init(frame: NSRect) {
            super.init(frame: frame)
            // The glyph draws past its view's bounds; keep it off the text around it.
            wantsLayer = true
            layer?.masksToBounds = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attach()
        }

        // Also runs when the window comes on screen after the content was set.
        override func layout() {
            super.layout()
            attach()
        }

        private func attach() {
            guard let content, content.superview !== self, window?.isVisible == true else { return }
            content.removeFromSuperview()
            content.translatesAutoresizingMaskIntoConstraints = false
            addSubview(content)
            NSLayoutConstraint.activate([
                content.centerXAnchor.constraint(equalTo: centerXAnchor),
                content.centerYAnchor.constraint(equalTo: centerYAnchor),
                content.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
                content.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
            ])
        }
    }
}

/// The app icon on the lock screen, its ring draining like a 30-second code, then sweeping full
/// again. While it refills it sometimes turns somewhere new (a full ring would hide the turn).
/// With Reduce Motion it stays still, as shipped.
@MainActor
struct LockIcon: View {
    let spinner: IconSpinner
    private static let period: TimeInterval = 30

    var body: some View {
        if IconSpinner.reduceMotion {
            IconCanvas(rotation: spinner.rotation, remaining: 0.75)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let time = context.date.timeIntervalSince1970
                let phase = time.truncatingRemainder(dividingBy: Self.period), refill = IconSpinner.duration
                IconCanvas(rotation: spinner.rotation,
                           remaining: phase < refill ? IconSpinner.ease(phase / refill)
                                                     : 1 - (phase - refill) / (Self.period - refill))
                    .onChange(of: Int(time / Self.period)) { spinner.maybeTurn(chance: 1.0 / 3) }
            }
        }
    }
}

/// `IconArt.drawAppIcon` in a SwiftUI view, so the ring can change every frame.
private struct IconCanvas: View {
    let rotation: Double
    let remaining: Double

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cg in
                // Canvas is y-down; the icon is drawn y-up in a 1024-point space.
                cg.translateBy(x: 0, y: size.height)
                cg.scaleBy(x: size.width / 1024, y: -size.height / 1024)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
                IconArt.drawAppIcon(rotation: rotation, remaining: remaining)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}
