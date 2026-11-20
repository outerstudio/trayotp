import OTPCore
import SwiftUI

/// The Updates window: current version, a manual check with its result, and the automatic-check settings.
@MainActor
struct UpdatesView: View {
    let updater: Updater

    var body: some View {
        @Bindable var updater = updater
        VStack(spacing: 18) {
            header
            statusCard
            VStack(spacing: 0) {
                HStack {
                    Text("Check Automatically")
                    Spacer()
                    Toggle("Check Automatically", isOn: $updater.checksAutomatically)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .padding(.vertical, 10)
                Divider()
                HStack {
                    Text("Update Channel")
                    Spacer()
                    // Each channel also gets everything more stable: beta gets releases, alpha gets betas and releases.
                    Menu {
                        Picker("Update Channel", selection: $updater.channel) {
                            ForEach(UpdateChannel.allCases, id: \.self) { Text(Self.name($0)).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        Text(Self.name(updater.channel))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(24)
        .frame(width: 400)
    }

    private static func name(_ channel: UpdateChannel) -> String {
        switch channel {
        case .stable: String(localized: "Stable")
        case .beta: String(localized: "Beta")
        case .alpha: String(localized: "Alpha")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "TrayOTP").font(.system(size: 20, weight: .bold))
                Text("Version \(updater.currentVersion?.description ?? "?")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            statusIcon
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.system(size: 13, weight: .semibold))
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let release = updater.available {
                Button { Task { await updater.offerAvailable() } } label: {
                    Text("Update to \(release.version?.description ?? release.tag)…")
                }
                .buttonStyle(FlatButtonStyle(prominent: true))
                .disabled(updater.isBusy)
            } else {
                Button("Check Now") { Task { await updater.checkNow() } }
                    .buttonStyle(FlatButtonStyle())
                    .disabled(updater.isBusy)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var statusIcon: some View {
        if updater.isBusy {
            ProgressView().controlSize(.small)
        } else if updater.available != nil {
            Image(systemName: "arrow.down.circle.fill").font(.system(size: 24)).foregroundStyle(Color.accentColor)
        } else if case .failed = updater.checkResult {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 22)).foregroundStyle(.red)
        } else if updater.checkResult == .upToDate {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(.green)
        } else {
            Image(systemName: "arrow.triangle.2.circlepath.circle").font(.system(size: 24)).foregroundStyle(.secondary)
        }
    }

    private var headline: String {
        if updater.isInstalling { return String(localized: "Downloading…") }
        if updater.isBusy { return String(localized: "Checking…") }
        if let release = updater.available {
            return String(localized: "TrayOTP \(release.version?.description ?? release.tag) is available.")
        }
        if case .failed = updater.checkResult { return String(localized: "Could not check for updates") }
        if updater.checkResult == .upToDate {
            return String(localized: "You have the latest version (\(updater.currentVersion?.description ?? "?")).")
        }
        return String(localized: "Updates")
    }

    private var detail: String? {
        if updater.isBusy { return nil }
        if case .failed(let message) = updater.checkResult { return message }
        guard let last = updater.lastChecked else { return nil }
        return String(localized: "Last checked: \(last.formatted(.relative(presentation: .named)))")
    }
}

/// A borderless, filled button that follows the system appearance.
private struct FlatButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 28)
            .background(
                (prominent ? Color.accentColor : Color.primary.opacity(0.1)).opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 7))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
    }
}
