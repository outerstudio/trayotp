import OTPCore
import SwiftUI

@MainActor
struct ServiceIconReviewView: View {
    private struct Option: Identifiable {
        let suggestion: SimpleIconsCatalog.Suggestion
        var selected = false
        var id: String { suggestion.id }
    }

    @Environment(AppState.self) private var state
    @State private var options: [Option]
    @State private var showsNotice: Bool?

    init(suggestions: [SimpleIconsCatalog.Suggestion]) {
        _options = State(initialValue: suggestions.map { Option(suggestion: $0) })
    }

    private var single: SimpleIconsCatalog.Suggestion? {
        options.count == 1 ? options.first?.suggestion : nil
    }

    private var selected: Set<String> {
        Set(options.lazy.filter(\.selected).map(\.id))
    }

    var body: some View {
        let batch = single == nil
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                Group {
                    if let single {
                        Text("Download the \(single.icon.title) icon?")
                    } else {
                        Text("Choose Service Icons to Download")
                    }
                }
                .font(.system(size: 15, weight: .semibold))
            }

            if batch { batchSelection }

            if showsNotice == true { SimpleIconsFirstUseNotice() }

            HStack(spacing: 8) {
                Button(batch ? "Skip All" : "Skip") { state.finishServiceIconReview() }
                    .buttonStyle(PanelButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .frame(maxWidth: 94)
                Button("Download from jsDelivr") {
                    state.finishServiceIconReview(downloading: single.map { Set([$0.id]) } ?? selected)
                }
                .buttonStyle(ServiceIconDownloadButtonStyle())
                .disabled(batch && selected.isEmpty)
            }
        }
        .padding(14)
        .onAppear {
            if showsNotice == nil { showsNotice = state.takeFirstServiceIconNotice() }
        }
    }

    private var batchSelection: some View {
        let count = selected.count
        let total = options.count
        return Card {
            VStack(spacing: 0) {
                HStack {
                    Toggle("Select All", sources: $options, isOn: \.selected)
                        .toggleStyle(.checkbox)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(count) of \(total) selected")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Theme.selection.opacity(0.5))

                Divider()

                ViewThatFits(in: .vertical) {
                    rows
                    ScrollView { rows }
                        .frame(height: 216)
                }
                .frame(maxHeight: 216)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach($options) { $option in
                let count = option.suggestion.tokenIDs.count
                Toggle(isOn: $option.selected) {
                    HStack {
                        Text(option.suggestion.icon.title)
                        Spacer()
                        Group {
                            if count == 1 { Text("1 token") } else { Text("\(count) tokens") }
                        }
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(option.selected ? Color.accentColor.opacity(0.10) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(6)
    }
}

private struct ServiceIconDownloadButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let fill = isEnabled ? Theme.accent : Color.primary.opacity(0.07)
        return configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.black.opacity(0.88) : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(fill.opacity(configuration.isPressed ? 0.80 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardStroke))
            .contentShape(Rectangle())
    }
}

@MainActor
private struct SimpleIconsFirstUseNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Icon matching happens on this Mac.")
                .fontWeight(.medium)
            Text("Logo licenses and brand guidelines vary by service.")
                .foregroundStyle(.secondary)
            Link(destination: SimpleIconsCatalog.disclaimerURL) {
                Text("Simple Icons Disclaimer").underline()
            }
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}
