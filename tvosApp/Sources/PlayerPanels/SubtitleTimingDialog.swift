import SwiftUI

/// Native tvOS port of the Android subtitle timing dialog. The Android app
/// has two related surfaces: the sync-by-line `SubtitleTimingDialog` and the
/// delay stepper `SubtitleDelayOverlay` in `PlayerScreen.kt`. This dialog
/// combines them: a ±100 ms delay stepper with reset (the overlay), the
/// sync-by-line entry point, and the auto-sync status message, plus the
/// explanation text required by the tvOS parity brief.
struct SubtitleTimingDialog: View {
    let state: SubtitleTimingDialogState

    let onAdjustDelay: (Int) -> Void
    let onResetDelay: () -> Void
    var onSyncByLine: (() -> Void)?
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        state: SubtitleTimingDialogState,
        onAdjustDelay: @escaping (Int) -> Void,
        onResetDelay: @escaping () -> Void,
        onSyncByLine: (() -> Void)? = nil,
        onClose: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onAdjustDelay = onAdjustDelay
        self.onResetDelay = onResetDelay
        self.onSyncByLine = onSyncByLine
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.lg) {
            header
            delayReadout
            stepper
            actions
            if let status = state.statusMessage, !status.isEmpty {
                Text(status.tvSafe)
                    .font(.footnote)
                    .foregroundStyle(Color(nuvioARGB: 0xFF_9B_E2_AF))
                    .multilineTextAlignment(.center)
            }
            if let error = state.errorMessage, !error.isEmpty {
                Text(error.tvSafe)
                    .font(.footnote)
                    .foregroundStyle(Color(nuvioARGB: 0xFF_FF_B3_7A))
                    .multilineTextAlignment(.center)
            }
            explanation
        }
        .padding(NuvioDesignTokens.Spacing.Dialog.outer)
        .frame(maxWidth: NuvioDesignTokens.Components.dialogMaximumWidth)
        .background(
            Color(nuvioARGB: 0xCC_0F_0F_0F),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: NuvioDesignTokens.Strokes.hairline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Subtitle timing dialog")
    }

    private var header: some View {
        HStack {
            Text("Subtitle Delay")
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close timing dialog")
        }
    }

    private var delayReadout: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.xs) {
            Text(SubtitleTimingMath.delayMillisecondsLabel(state.delayMilliseconds))
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: state.delayMilliseconds)
                .accessibilityLabel("Current subtitle delay")
            Text(relativeDelayDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var relativeDelayDescription: String {
        switch state.delayMilliseconds {
        case ..<0: return "Subtitles appear earlier"
        case 1...: return "Subtitles appear later"
        default: return "Subtitles are in sync"
        }
    }

    private var stepper: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.xl) {
            Button {
                onAdjustDelay(-SubtitleDelayRange.stepMilliseconds)
            } label: {
                VStack(spacing: NuvioDesignTokens.Spacing.xxs) {
                    Image(systemName: "minus")
                        .font(.title2.weight(.semibold))
                    Text("100 ms earlier")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(SubtitlePanelRowStyle())
            .accessibilityLabel("Delay subtitles 100 milliseconds earlier")

            Button {
                onAdjustDelay(SubtitleDelayRange.stepMilliseconds)
            } label: {
                VStack(spacing: NuvioDesignTokens.Spacing.xxs) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                    Text("100 ms later")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(SubtitlePanelRowStyle())
            .accessibilityLabel("Delay subtitles 100 milliseconds later")
        }
    }

    private var actions: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            Button(action: onResetDelay) {
                Text("Reset")
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(SubtitlePanelRowStyle())
            .disabled(state.delayMilliseconds == 0)
            .opacity(state.delayMilliseconds == 0 ? 0.55 : 1)
            .accessibilityHint("Restores the default zero delay")

            if let onSyncByLine {
                Button(action: onSyncByLine) {
                    Text("Sync by Line…")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(SubtitlePanelRowStyle())
                .accessibilityHint("Opens the sync-by-line cue picker")
            }
        }
    }

    /// Explanation text required by the tvOS parity brief; the Android delay
    /// overlay communicates the same rules through its slider bounds.
    private var explanation: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.xs) {
            Text(
                "Press − or + to shift subtitles in 100 ms steps. " +
                    "Subtitles can be shifted up to 3 minutes earlier or later."
            )
            Text(
                "Reset restores the original timing. Sync by Line aligns subtitles " +
                    "to the line you are currently hearing."
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}
