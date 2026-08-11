import SwiftUI

struct PlayerControlsOverlay: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @State private var showOptions = false
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false
    @FocusState private var focus: Control?

    private enum Control: Hashable {
        case seekBack, playPause, seekForward, options
    }

    var body: some View {
        VStack {
            header
            Spacer()
            transport
        }
        .padding(52)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.7), .clear, .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .defaultFocus($focus, .playPause)
        .sheet(isPresented: $showOptions) {
            PlayerOptionsView(
                route: route,
                session: session,
                selectedSourceURL: selectedSourceURL,
                onSelectSource: onSelectSource,
                onSelectEpisode: onSelectEpisode
            )
        }
        .onChange(of: session.position) { _, position in
            if !isScrubbing { scrubPosition = position }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(route.title.tvSafe)
                    .font(.title.weight(.bold))
                if let episode = episodeLabel {
                    Text(episode.tvSafe).font(.title3)
                }
                Text(route.sourceName.tvSafe)
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
            Spacer()
            if session.isLoading { ProgressView("Loading") }
            Button { showOptions = true } label: {
                Label("Playback Options", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .focused($focus, equals: .options)
        }
    }

    private var transport: some View {
        VStack(spacing: 18) {
            ProgressView(value: scrubPosition, total: max(session.duration, 1))
                .tint(NuvioTheme.accent)

            HStack {
                Text(PlayerTimeFormatter.string(scrubPosition))
                Spacer()
                Button { session.seek(by: -10) } label: {
                    Label("Back 10 Seconds", systemImage: "gobackward.10")
                }
                .focused($focus, equals: .seekBack)
                Button { session.toggle() } label: {
                    Label(
                        session.isPaused ? "Play" : "Pause",
                        systemImage: session.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .focused($focus, equals: .playPause)
                Button { session.seek(by: 10) } label: {
                    Label("Forward 10 Seconds", systemImage: "goforward.10")
                }
                .focused($focus, equals: .seekForward)
                Button { scrub(by: -30) } label: {
                    Label("Back 30 Seconds", systemImage: "gobackward.30")
                }
                Button { scrub(by: 30) } label: {
                    Label("Forward 30 Seconds", systemImage: "goforward.30")
                }
                Spacer()
                Text(PlayerTimeFormatter.string(session.duration))
            }
            .buttonStyle(.bordered)
            .font(.callout.monospacedDigit())
        }
        .padding(28)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
    }

    private func scrub(by seconds: Double) {
        isScrubbing = true
        scrubPosition = (scrubPosition + seconds).clamped(to: 0...max(session.duration, 0))
        session.seek(to: scrubPosition)
        isScrubbing = false
    }

    private var episodeLabel: String? {
        guard let season = route.seasonNumber, let episode = route.episodeNumber else {
            return route.episodeTitle
        }
        let code = "S\(season) E\(episode)"
        return route.episodeTitle.map { "\(code)  \($0)" } ?? code
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
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
