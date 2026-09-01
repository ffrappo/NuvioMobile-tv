import SwiftUI

/// Skip Intro/Outro/Recap button ported from Android SkipIntroButton.kt.
/// Appears at bottom-leading while playback is inside a skip interval,
/// auto-hides after 10 seconds (countdown paused while controls are visible),
/// and is focusable for Siri-remote navigation. Reduce Motion replaces the
/// scale transition with a plain fade.
struct SkipIntroButtonView: View {
    let interval: SkipInterval?
    let dismissed: Bool
    let controlsVisible: Bool
    var suppressFocus: Bool = false
    var canFocus: Bool = true
    let onSkip: () -> Void
    var onDismiss: () -> Void = {}
    var onHideControls: (() -> Void)? = nil
    var onVisibilityChanged: (Bool) -> Void = { _ in }
    var onFocused: (() -> Void)? = nil

    @State private var autoHidden = false
    @State private var manuallyDismissed = false
    @State private var progressSeconds: Double = 0
    @State private var isFocused = false
    @FocusState private var focusRequested: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasActiveInterval: Bool { interval != nil }

    /// Android `shouldShow`: active interval not (dismissed while controls
    /// are hidden).
    private var shouldShow: Bool {
        hasActiveInterval && (!dismissed || controlsVisible)
    }

    private var isVisible: Bool {
        SkipIntroVisibilityRules.isSkipIntroButtonVisible(
            hasActiveInterval: hasActiveInterval,
            dismissed: dismissed,
            controlsVisible: controlsVisible,
            autoHidden: autoHidden
        )
    }

    private var timeoutSeconds: Double {
        Double(SkipIntroVisibilityRules.autoHideTimeoutMs) / 1000
    }

    /// Fraction of the auto-hide window already elapsed (0...1).
    private var progress: Double {
        min(max(progressSeconds / timeoutSeconds, 0), 1)
    }

    private var label: String {
        SkipIntroVisibilityRules.skipLabel(forType: interval?.type)
    }

    var body: some View {
        ZStack {
            if isVisible {
                button
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.2)
                : .easeInOut(duration: 0.3),
            value: isVisible
        )
        .task(id: autoHideTickToken) { await runAutoHideCountdown() }
        .task(id: focusToken) { await requestFocusIfNeeded() }
        .onChange(of: interval?.id) { _, _ in
            // New interval: reset the auto-hide state and countdown.
            autoHidden = false
            manuallyDismissed = false
            progressSeconds = 0
        }
        .onChange(of: dismissed) { _, isDismissed in
            if isDismissed {
                manuallyDismissed = true
            } else if !manuallyDismissed {
                autoHidden = false
                progressSeconds = 0
            }
        }
        .onChange(of: isVisible) { _, visible in
            onVisibilityChanged(visible)
        }
        .onChange(of: isFocused) { _, focused in
            if focused { onFocused?() }
        }
    }

    private var button: some View {
        Button(action: onSkip) {
            VStack(spacing: 0) {
                HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text(label)
                        .nuvioTextStyle(.button)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, NuvioDesignTokens.Spacing.md)
                autoHideTrack
            }
            .frame(minWidth: 96)
        }
        .buttonStyle(SkipIntroButtonStyle(focused: isFocused))
        .focused($focusRequested)
        .focusable(canFocus)
        .disabled(!canFocus)
        .onFocusChanged { focused in
            isFocused = focused
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    /// Android progress track: a light elapsed track with a dark remaining
    /// fill on top, both hidden while controls are visible, auto-hidden, or
    /// dismissed.
    private var autoHideTrack: some View {
        let trackHidden = controlsVisible || autoHidden || dismissed
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(trackHidden ? 0 : 0.15))
                Rectangle()
                    .fill(Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255)
                        .opacity(trackHidden ? 0 : 0.85))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: NuvioDesignTokens.Spacing.xs)
    }

    /// Countdown task identity: restarts (freezing the accumulated progress)
    /// whenever the run conditions change, mirroring the Android Animatable
    /// that only advances while shown and controls are hidden.
    private var autoHideTickToken: String {
        "\(interval?.id ?? "none")|\(shouldShow)|\(autoHidden)|\(controlsVisible)"
    }

    private var focusToken: String {
        "\(isVisible)|\(controlsVisible)|\(suppressFocus)|\(canFocus)"
    }

    /// Auto-hide after 10 seconds; pause the countdown while controls are
    /// visible. Progress persists across pauses so the remaining time keeps
    /// shrinking (Android `skipIntroAutoHideRemainingMs` semantics).
    private func runAutoHideCountdown() async {
        guard shouldShow, !autoHidden, !controlsVisible else { return }
        while !Task.isCancelled {
            guard let _ = try? await Task.sleep(for: .milliseconds(100)) else { return }
            progressSeconds = min(progressSeconds + 0.1, timeoutSeconds)
            if progressSeconds >= timeoutSeconds {
                autoHidden = true
                return
            }
        }
    }

    /// Take focus when the button becomes visible while controls are hidden,
    /// unless the next-episode card owns focus or focus is reserved for an
    /// overlay (Android autoplay / subtitle-overlay rules).
    private func requestFocusIfNeeded() async {
        guard isVisible, !controlsVisible, !suppressFocus, canFocus else { return }
        guard let _ = try? await Task.sleep(for: .milliseconds(50)) else { return }
        guard !Task.isCancelled else { return }
        focusRequested = true
    }
}

/// Button chrome matching the Android card colors: dark translucent
/// container, brand secondary when focused, inverted content color.
private struct SkipIntroButtonStyle: ButtonStyle {
    let focused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(focused ? Color.black : Color.white)
            .background(
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                    .fill(focused
                          ? NuvioDesignTokens.Colors.brand
                          : Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255)
                              .opacity(0.85))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: NuvioMotion.focusTransition),
                value: focused
            )
    }
}

private extension View {
    /// Bridges the environment focus state into a plain callback.
    @ViewBuilder
    func onFocusChanged(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(FocusReporter(action: action))
    }
}

private struct FocusReporter: ViewModifier {
    let action: (Bool) -> Void
    @Environment(\.isFocused) private var envFocused

    func body(content: Content) -> some View {
        content
            .onChange(of: envFocused) { _, focused in
                action(focused)
            }
            .onAppear {
                action(envFocused)
            }
    }
}
