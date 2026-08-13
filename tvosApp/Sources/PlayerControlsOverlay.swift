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

    @State private var scrubPosition = 0.0
    @State private var showMoreControls = false
    @FocusState private var focus: Control?
    @Environment(\.nuvioTheme) private var theme

    private enum Control: Hashable { case timeline, playPause, more, skip }

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

    private var bottomControls: some View {
        VStack(spacing: showMoreControls ? 20 : 16) {
            timeline
            HStack(spacing: 28) {
                transportButtons
                Spacer()
                Button {
                    showMoreControls.toggle()
                    onInteraction()
                    focus = showMoreControls ? .more : .timeline
                } label: {
                    Label(showMoreControls ? "Fewer Controls" : "More Controls", systemImage: "ellipsis")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .focused($focus, equals: .more)
            }
            if showMoreControls {
                PlayerControlMenus(
                    route: route,
                    session: session,
                    selectedSourceURL: selectedSourceURL,
                    onInteraction: onInteraction,
                    onModalPresentationChanged: onModalPresentationChanged,
                    onSelectSource: onSelectSource,
                    onSelectEpisode: onSelectEpisode
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .nuvioAdaptiveSurface(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var transportButtons: some View {
        HStack(spacing: 18) {
            transportButton("gobackward.10", label: "Back 10 Seconds") { seek(by: -10) }
            Button {
                session.toggle()
                onInteraction()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(.white)
            .foregroundStyle(.black)
            .focused($focus, equals: .playPause)
            .accessibilityLabel(session.isPaused ? "Play" : "Pause")
            transportButton("goforward.10", label: "Forward 10 Seconds") { seek(by: 10) }
        }
    }

    private var timeline: some View {
        VStack(spacing: 2) {
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
            .accessibilityLabel("Playback Position")
            .accessibilityValue(PlayerTimeFormatter.string(scrubPosition))
            HStack {
                Text(PlayerTimeFormatter.string(scrubPosition))
                Spacer()
                Text("-\(PlayerTimeFormatter.string(max(0, session.duration - scrubPosition)))")
            }
            .font(.callout.monospacedDigit().weight(.medium))
            .foregroundStyle(theme.secondaryText)
        }
    }

    private func skipButton(_ interval: SkipInterval) -> some View {
        HStack {
            Spacer()
            Button { onSkip(interval) } label: {
                Label(interval.actionTitle, systemImage: "forward.end.fill")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .focused($focus, equals: .skip)
        }
        .padding(.bottom, 22)
    }

    private func transportButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .foregroundStyle(.white)
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
