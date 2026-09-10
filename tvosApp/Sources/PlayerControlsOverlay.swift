import SwiftUI

struct PlayerControlsOverlay: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let activeSkipInterval: SkipInterval?
    let onInteraction: () -> Void
    let onModalPresentationChanged: (Bool) -> Void
    let onSkip: (SkipInterval) -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void
    var onToggleStreamInfo: () -> Void = {}
    var onOwnFocusChanged: (Bool) -> Void = { _ in }
    var onStripFocusChanged: (Bool) -> Void = { _ in }

    @State private var scrubPosition = 0.0
    @FocusState private var focus: Control?
    @Environment(\.nuvioTheme) private var theme

    private enum Control: Hashable { case timeline, playPause, back10, fwd10, skip }

    var body: some View {
        ZStack {
            overlayGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Spacer()
                if let activeSkipInterval { skipButton(activeSkipInterval) }
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 72)
            .padding(.top, 52)
            .padding(.bottom, 48)
        }
        .defaultFocus($focus, activeSkipInterval == nil ? .timeline : .skip)
        .onAppear { scrubPosition = session.position }
        .onChange(of: session.position) { _, position in
            scrubPosition = position
        }
        .onChange(of: focus) { _, newValue in
            onOwnFocusChanged(newValue != nil && newValue != .timeline)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 7) {
                Text(route.title.tvSafe)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                if let episode = episodeLabel {
                    Text(episode.tvSafe)
                        .font(.headline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
                Text(sourceLabel.tvSafe)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if session.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Loading Video")
            }
        }
    }

    /// Apple TV player bottom chrome: the scrubber with elapsed and remaining
    /// time inline, transport buttons at the leading edge, and the option
    /// strip at the trailing edge, floating directly on the gradient.
    private var bottomControls: some View {
        VStack(spacing: 24) {
            timeline
            HStack(spacing: 28) {
                transportButtons
                Spacer()
                PlayerControlStrip(
                    route: route,
                    session: session,
                    selectedSourceURL: selectedSourceURL,
                    onInteraction: onInteraction,
                    onModalPresentationChanged: onModalPresentationChanged,
                    onSelectSource: onSelectSource,
                    onSelectEpisode: onSelectEpisode,
                    onToggleStreamInfo: onToggleStreamInfo,
                    onFocusChanged: onStripFocusChanged
                )
            }
        }
    }

    private var transportButtons: some View {
        HStack(spacing: 24) {
            transportButton("gobackward.10", label: "Back 10 Seconds", control: .back10) { seek(by: -10) }
            Button {
                session.toggle()
                onInteraction()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(PlayerTransportButtonStyle())
            .focused($focus, equals: .playPause)
            .accessibilityLabel(session.isPaused ? "Play" : "Pause")
            transportButton("goforward.10", label: "Forward 10 Seconds", control: .fwd10) { seek(by: 10) }
        }
    }

    private var timeline: some View {
        HStack(spacing: 20) {
            Text(PlayerTimeFormatter.string(scrubPosition))
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
            PlaybackTimelineScrubber(
                position: scrubPosition,
                duration: max(session.duration, 0),
                isFocused: focus == .timeline,
                onSeek: { position in
                    scrubPosition = position
                    session.seek(to: position)
                },
                onInteraction: onInteraction
            )
            .focused($focus, equals: .timeline)
            .frame(maxWidth: .infinity)
            Text("-\(PlayerTimeFormatter.string(max(0, session.duration - scrubPosition)))")
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private func skipButton(_ interval: SkipInterval) -> some View {
        HStack {
            Spacer()
            Button { onSkip(interval) } label: {
                Label(interval.actionTitle, systemImage: "forward.end.fill")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PlayerTransportButtonStyle(cornerRadius: 40))
            .focused($focus, equals: .skip)
        }
        .padding(.bottom, 22)
    }

    private func transportButton(
        _ symbol: String,
        label: String,
        control: Control,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(PlayerTransportButtonStyle(cornerRadius: 28))
        .focused($focus, equals: control)
        .accessibilityLabel(label)
    }

    private func seek(by seconds: Double) {
        let destination = min(max(session.position + seconds, 0), max(session.duration, 0))
        scrubPosition = destination
        session.seek(to: destination)
        onInteraction()
    }

    private var sourceLabel: String {
        let source = session.activeSourceName.isEmpty ? route.sourceName : session.activeSourceName
        guard let option = route.availableSources.first(where: { $0.url == selectedSourceURL }) else {
            return source
        }
        var label = source
        if let summary = option.displaySummary?.trimmedNonEmpty { label += "  ·  \(summary)" }
        label += "  ·  \(option.addonName)"
        return label
    }

    private var overlayGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.66), location: 0),
                .init(color: .clear, location: 0.28),
                .init(color: .clear, location: 0.56),
                .init(color: .black.opacity(0.86), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var episodeLabel: String? {
        guard let season = route.seasonNumber, let episode = route.episodeNumber else {
            return route.episodeTitle
        }
        let code = "S\(season) E\(episode)"
        return route.episodeTitle.map { "\(code)  \($0)" } ?? code
    }
}

/// Uniform transport control style: unfocused = translucent white circle
/// with white glyph, focused = solid white with black glyph, Apple TV style.
struct PlayerTransportButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 36

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.16),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .scaleEffect(
                reduceMotion ? 1 :
                    (isFocused ? 1.06 : (configuration.isPressed ? 0.95 : 1))
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: isFocused
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

enum PlayerTimeFormatter {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
