import SwiftUI

struct PlayerControlsOverlay: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let activeSkipInterval: SkipInterval?
    let onSkip: (SkipInterval) -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @State private var showOptions = false
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false
    @FocusState private var focus: Control?

    private enum Control: Hashable { case playPause, skip, options }

    var body: some View {
        VStack {
            header
            Spacer()
            if let activeSkipInterval { skipButton(activeSkipInterval) }
            transport
        }
        .padding(.horizontal, 62)
        .padding(.vertical, 48)
        .background(overlayGradient.ignoresSafeArea())
        .defaultFocus($focus, activeSkipInterval == nil ? .playPause : .skip)
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
        .onMoveCommand { direction in
            guard !showOptions else { return }
            switch direction {
            case .left: scrub(by: -10)
            case .right: scrub(by: 10)
            default: break
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 7) {
                Text(route.title.tvSafe)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .lineLimit(1)
                if let episode = episodeLabel {
                    Text(episode.tvSafe).font(.title3.weight(.medium))
                }
                Label(route.sourceName.tvSafe, systemImage: "antenna.radiowaves.left.and.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
            Spacer()
            if session.isLoading { ProgressView().controlSize(.large) }
            Button { showOptions = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .focused($focus, equals: .options)
            .accessibilityLabel("Playback Options")
        }
    }

    private var transport: some View {
        VStack(spacing: 20) {
            timeline
            HStack(spacing: 26) {
                transportButton("gobackward.10", label: "Back 10 Seconds") { scrub(by: -10) }
                Button { session.toggle() } label: {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 34, weight: .bold))
                        .frame(width: 82, height: 82)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.white)
                .foregroundStyle(.black)
                .focused($focus, equals: .playPause)
                transportButton("goforward.10", label: "Forward 10 Seconds") { scrub(by: 10) }
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var timeline: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.24)).frame(height: 7)
                    Capsule().fill(.white).frame(width: width * progress, height: 7)
                    Circle().fill(.white).frame(width: 20, height: 20).offset(x: max(0, width * progress - 10))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
            HStack {
                Text(PlayerTimeFormatter.string(scrubPosition))
                Spacer()
                Text("-\(PlayerTimeFormatter.string(max(0, session.duration - scrubPosition)))")
            }
            .font(.callout.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func skipButton(_ interval: SkipInterval) -> some View {
        HStack {
            Spacer()
            Button { onSkip(interval) } label: {
                Label(interval.actionTitle, systemImage: "forward.end.fill")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .focused($focus, equals: .skip)
        }
        .padding(.bottom, 22)
    }

    private func transportButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 28, weight: .semibold)).frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var overlayGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.76), location: 0),
                .init(color: .clear, location: 0.42),
                .init(color: .black.opacity(0.96), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var progress: Double {
        guard session.duration > 0 else { return 0 }
        return min(max(scrubPosition / session.duration, 0), 1)
    }

    private func scrub(by seconds: Double) {
        isScrubbing = true
        scrubPosition = min(max(scrubPosition + seconds, 0), max(session.duration, 0))
        session.seek(to: scrubPosition)
        isScrubbing = false
    }

    private var episodeLabel: String? {
        guard let season = route.seasonNumber, let episode = route.episodeNumber else { return route.episodeTitle }
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
