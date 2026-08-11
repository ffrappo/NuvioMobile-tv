import SwiftUI

struct PlayerRoute: Identifiable {
    let id = UUID()
    let url: URL
    let contentID: String
    let imdbID: String?
    let title: String
    let sourceName: String
    let summary: MetaSummary
    let videoID: String
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeTitle: String?
    let availableSources: [PlayerSourceOption]
    let episodes: [PlayerEpisodeOption]
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    var initialSource: PlayerSourceOption? {
        availableSources.first { $0.url == url }
    }
}

struct PlayerSourceOption: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let addonName: String
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
}

struct PlayerEpisodeOption: Identifiable, Hashable {
    let id: String
    let title: String
    let seasonNumber: Int?
    let episodeNumber: Int?
}

struct MPVPlayerView: UIViewControllerRepresentable {
    let session: MPVPlaybackSession

    func makeUIViewController(context: Context) -> MPVPlayerController {
        MPVPlayerController(session: session)
    }

    func updateUIViewController(_ controller: MPVPlayerController, context: Context) {}
}

struct PlayerView: View {
    let route: PlayerRoute

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var integrations: IntegrationStore
    @EnvironmentObject private var syncedProgress: WatchProgressStore
    @StateObject private var session = MPVPlaybackSession()
    @State private var controlsVisible = true
    @State private var selectedSourceURL: URL?
    @State private var resumePosition: Double?
    @State private var lastSavedPosition = 0.0
    @State private var nowPlaying: TVNowPlayingController?
    @State private var skipIntervals: [SkipInterval] = []
    @State private var dismissedSkipIntervalIDs: Set<String> = []

    private let progressStore = PlaybackProgressStore()
    private let skipService = SkipSegmentsService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MPVPlayerView(session: session).ignoresSafeArea()
            if controlsVisible {
                PlayerControlsOverlay(
                    route: route,
                    session: session,
                    selectedSourceURL: selectedSourceURL ?? route.url,
                    activeSkipInterval: activeSkipInterval,
                    onSkip: skip,
                    onSelectSource: switchSource,
                    onSelectEpisode: selectEpisode
                )
            }
            if let error = session.errorMessage { errorPanel(error) }
        }
        .onAppear {
            selectedSourceURL = route.url
            resumePosition = syncedProgress.resumablePosition(
                videoID: route.videoID,
                contentID: route.summary.id
            ) ?? progressStore.progress(for: route.contentID)?.resumablePosition
            session.load(
                url: route.url,
                startPosition: resumePosition,
                requestHeaders: route.initialSource?.requestHeaders ?? [:],
                responseHeaders: route.initialSource?.responseHeaders ?? [:]
            )
            let controller = TVNowPlayingController(session: session)
            controller.updateMetadata(title: route.title, subtitle: route.sourceName)
            nowPlaying = controller
            loadSkipIntervals()
        }
        .onDisappear {
            saveProgress()
            nowPlaying?.invalidate()
            nowPlaying = nil
            session.stop()
        }
        .onChange(of: session.position) { _, position in
            nowPlaying?.sync(
                position: position,
                duration: session.duration,
                isPaused: session.isPaused,
                speed: session.speed
            )
            guard abs(position - lastSavedPosition) >= 10 else { return }
            saveProgress()
            lastSavedPosition = position
        }
        .onPlayPauseCommand {
            session.toggle()
            controlsVisible = true
        }
        .onTapGesture { controlsVisible.toggle() }
        .onExitCommand {
            saveProgress()
            session.stop()
            dismiss()
        }
    }

    private var activeSkipInterval: SkipInterval? {
        skipIntervals.first {
            $0.contains(session.position) && !dismissedSkipIntervalIDs.contains($0.id)
        }
    }

    private func loadSkipIntervals() {
        guard let imdbID = route.imdbID,
              let season = route.seasonNumber,
              let episode = route.episodeNumber else { return }
        Task {
            skipIntervals = await skipService.intervals(
                imdbID: imdbID,
                season: season,
                episode: episode,
                settings: integrations.settings
            )
        }
    }

    private func skip(_ interval: SkipInterval) {
        dismissedSkipIntervalIDs.insert(interval.id)
        session.seek(to: interval.endTime)
    }

    private func switchSource(_ source: PlayerSourceOption) {
        saveProgress()
        selectedSourceURL = source.url
        nowPlaying?.updateMetadata(title: route.title, subtitle: source.name)
        session.load(
            url: source.url,
            startPosition: session.position,
            requestHeaders: source.requestHeaders,
            responseHeaders: source.responseHeaders
        )
    }

    private func selectEpisode(_ episode: PlayerEpisodeOption) {
        saveProgress()
        session.stop()
        dismiss()
        route.onSelectEpisode(episode)
    }

    private func saveProgress() {
        progressStore.save(
            contentID: route.contentID,
            position: session.position,
            duration: session.duration
        )
        syncedProgress.record(
            summary: route.summary,
            videoID: route.videoID,
            season: route.seasonNumber,
            episode: route.episodeNumber,
            episodeTitle: route.episodeTitle,
            episodeThumbnail: nil,
            positionSeconds: session.position,
            durationSeconds: session.duration
        )
    }

    private func errorPanel(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 58))
                .foregroundStyle(.orange)
            Text("Playback Error").font(.title.weight(.bold))
            Text(error.tvSafe).font(.title3).multilineTextAlignment(.center)
            Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
        }
        .padding(46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
    }
}
