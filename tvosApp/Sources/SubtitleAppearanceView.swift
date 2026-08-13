import SwiftUI

struct SubtitleAppearanceView: View {
    @ObservedObject var session: MPVPlaybackSession
    let onPreferenceChanged: () -> Void

    var body: some View {
        List {
            Section("Timing") {
                adjustmentRow(
                    title: "Subtitle Delay",
                    value: delayLabel,
                    decrementLabel: "100 ms Earlier",
                    incrementLabel: "100 ms Later",
                    decrement: {
                        session.setSubtitleDelay(
                            milliseconds: session.subtitleDelayMilliseconds - 100
                        )
                        onPreferenceChanged()
                    },
                    increment: {
                        session.setSubtitleDelay(
                            milliseconds: session.subtitleDelayMilliseconds + 100
                        )
                        onPreferenceChanged()
                    }
                )
                Button("Reset Delay") {
                    session.setSubtitleDelay(milliseconds: 0)
                    onPreferenceChanged()
                }
                .disabled(session.subtitleDelayMilliseconds == 0)
            }

            Section("Text Size") {
                adjustmentRow(
                    title: "Font Size",
                    value: "\(session.subtitleFontSize)",
                    decrementLabel: "Smaller Text",
                    incrementLabel: "Larger Text",
                    decrement: {
                        session.setSubtitleFontSize(session.subtitleFontSize - 4)
                        onPreferenceChanged()
                    },
                    increment: {
                        session.setSubtitleFontSize(session.subtitleFontSize + 4)
                        onPreferenceChanged()
                    }
                )
            }
        }
        .navigationTitle("Subtitle Appearance")
    }

    private func adjustmentRow(
        title: String,
        value: String,
        decrementLabel: String,
        incrementLabel: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel(decrementLabel)
            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel(incrementLabel)
        }
    }

    private var delayLabel: String {
        let value = session.subtitleDelayMilliseconds
        if value == 0 { return "0 ms" }
        return value > 0 ? "+\(value) ms" : "\(value) ms"
    }
}
