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
    /// The unflattened stream sources feeding the parity side panel.
    var streamSources: [StreamSource] = []
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
    let displaySummary: String?
    let compatibilityIssue: String?
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
    /// Next-episode autoplay replaces the presented route in place.
    var onReplaceRoute: ((PlayerRoute) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var integrations: IntegrationStore
    @EnvironmentObject var addonStore: AddonStore
    @EnvironmentObject private var deepLinkStore: NuvioDeepLinkStore
    @EnvironmentObject private var syncedProgress: WatchProgressStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject  var session = MPVPlaybackSession()
    @StateObject  var controls = PlayerControlsVisibility()
    @State private var selectedSourceURL: URL?
    @State private var resumePosition: Double?
    @State private var lastSavedPosition = 0.0
    @State private var lastNowPlayingPosition: Double?
    @State private var lastNowPlayingPaused: Bool?
    @State private var nowPlaying: TVNowPlayingController?
    @State private var skipIntervals: [SkipInterval] = []
    @State private var dismissedSkipIntervalIDs: Set<String> = []
    @State private var isControlPanelPresented = false
    @StateObject var postPlay = PostPlayController(
        fetchRecommendations: { _ in [] },
        autoPlayTrailerEnabled: false,
        prefetchThreshold: PostPlayTiming.userMovieThreshold()
    )
    @State var postPlayRecommendations: [PostPlayRecommendation] = []
    @State var showsStreamInfo = false
    @State var nextEpisodeAutoplay: NextEpisodeAutoplayState?
    @State var autoplaySearchTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let progressStore = PlaybackProgressStore()
    private let skipService = SkipSegmentsService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MPVPlayerView(session: session).ignoresSafeArea()
                .onAppear { session.onControlPress = handleControlPress }
            SkipIntroButtonView(
                interval: integrations.settings.skipIntroEnabled ? activeSkipInterval : nil,
                dismissed: false,
                controlsVisible: controls.isVisible,
                onSkip: {
                    if let interval = activeSkipInterval {
                        skip(interval)
                    }
                }
            )
            playerOverlayLayers
            if chrome.isControlsVisible {
                PlayerControlsOverlay(
                    route: route,
                    session: session,
                    selectedSourceURL: selectedSourceURL ?? route.url,
                    activeSkipInterval: activeSkipInterval,
                    onInteraction: { controls.registerInteraction() },
                    onModalPresentationChanged: setControlPanelPresented,
                    onSkip: skip,
                    onSelectSource: switchSource,
                    onSelectEpisode: selectEpisode,
                    onToggleStreamInfo: { showsStreamInfo.toggle() }
                )
                .transition(.opacity)
            }
            if let error = session.errorMessage {
                PlayerErrorView(message: error) { dismiss() }
            }
            if let autoplay = nextEpisodeAutoplay {
                NextEpisodeCountdownView(
                    state: autoplay,
                    onCancel: { cancelNextEpisodeAutoplay() }
                )
            }
            if postPlay.state.isVisible {
                PostPlayOverlayView(
                    state: postPlay.state,
                    currentTitle: route.episodeTitle ?? route.title,
                    actions: PostPlayOverlayActions(
                        onPlay: { recommendation in
                            playRecommendation(recommendation)
                        },
                        onOpenDetails: { recommendation in
                            if let url = NuvioDeepLink.detailsURL(
                                type: recommendation.contentType,
                                id: recommendation.id
                            ) {
                                saveProgress()
                                session.stop()
                                dismiss()
                                deepLinkStore.receive(url)
                            }
                        },
                        onPlayTrailer: {},
                        onReplay: {
                            postPlay.stop()
                            session.clearEnded()
                            session.seek(to: 0)
                            session.play()
                        },
                        onReturnToPlayer: {
                            postPlay.returnToPlayer()
                            session.clearEnded()
                        },
                        onPreviousRecommendation: { postPlay.showPreviousRecommendation() },
                        onNextRecommendation: { postPlay.showNextRecommendation() }
                    ),
                    trailerPlaybackEnabled: false
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            selectedSourceURL = route.url
            session.updateActiveSourceName(route.initialSource?.name ?? route.sourceName)
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
            session.controllerApplySubtitleStyle(persistedSubtitleStyle)
            loadSkipIntervals()
            controls.registerInteraction()
        }
        .onDisappear {
            cancelNextEpisodeAutoplay()
            UIApplication.shared.isIdleTimerDisabled = false
            session.onControlPress = nil
            controls.cancel()
            saveProgress()
            nowPlaying?.invalidate()
            nowPlaying = nil
            session.stop()
        }
        .onChange(of: session.position) { _, position in
            syncNowPlaying(position: position)
            guard abs(position - lastSavedPosition) >= 10 else { return }
            saveProgress()
            lastSavedPosition = position
        }
        .onChange(of: session.isEnded) { _, ended in
            guard ended else { return }
            saveProgress()
            beginPostPlay()
            beginNextEpisodeAutoplayIfArmed()
        }
        .onChange(of: session.isPaused) { _, paused in
            if isControlPanelPresented {
                syncNowPlaying(position: session.position, force: true)
                return
            }
            if paused {
                controls.registerInteraction(keepVisible: true)
            } else {
                controls.registerInteraction()
            }
            syncNowPlaying(position: session.position, force: true)
        }
        .onTapGesture {
            controls.registerInteraction()
        }
        .onExitCommand {
            if nextEpisodeAutoplay != nil {
                cancelNextEpisodeAutoplay()
            } else if showsStreamInfo {
                showsStreamInfo = false
            } else if controls.isVisible {
                controls.hide()
            } else {
                saveProgress()
                session.stop()
                dismiss()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, !session.isPaused {
                session.pause()
                saveProgress()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: controls.isVisible)
    }

    private var activeSkipInterval: SkipInterval? {
        skipIntervals.first {
            $0.contains(session.position) && !dismissedSkipIntervalIDs.contains($0.id)
        }
    }

    /// The persisted subtitle style applied at playback start.
    private var persistedSubtitleStyle: SubtitleStyleOptions {
        let defaults = UserDefaults.standard
        let values = SubtitleStylePersistenceKey.allCases.reduce(into: [String: Any]()) { dict, key in
            if let value = defaults.object(forKey: key.rawValue) {
                dict[key.rawValue] = value
            }
        }
        return SubtitleStylePersistence.load(from: values)
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
        controls.registerInteraction()
    }

    private func setControlPanelPresented(_ presented: Bool) {
        isControlPanelPresented = presented
        controls.registerInteraction(keepVisible: presented || session.isPaused)
    }

    private func handleControlPress() {
        controls.registerInteraction(keepVisible: isControlPanelPresented || session.isPaused)
    }

    private func switchSource(_ source: PlayerSourceOption) {
        saveProgress()
        selectedSourceURL = source.url
        session.updateActiveSourceName(source.name)
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

    private func syncNowPlaying(position: Double, force: Bool = false) {
        let paused = session.isPaused
        let elapsedDelta = lastNowPlayingPosition.map { abs(position - $0) } ?? .infinity
        let stateChanged = lastNowPlayingPaused != paused
        guard force || elapsedDelta >= 1.0 || stateChanged else { return }
        lastNowPlayingPosition = position
        lastNowPlayingPaused = paused
        nowPlaying?.sync(
            position: position,
            duration: session.duration,
            isPaused: paused,
            speed: session.speed
        )
    }



    private func playRecommendation(_ recommendation: PostPlayRecommendation) {
        postPlay.stop()
        session.clearEnded()
        saveProgress()
        session.stop()
        dismiss()
        // Route through details so the stream pipeline resolves fresh sources.
        if let url = NuvioDeepLink.detailsURL(
            type: recommendation.contentType,
            id: recommendation.id
        ) {
            deepLinkStore.receive(url)
        }
    }

    func saveProgress() {
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
}
