import SwiftUI

struct PlayerRoute: Identifiable {
    let id = UUID()
    let url: URL
    let contentID: String
    let title: String
    let sourceName: String
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
    @StateObject private var session = MPVPlaybackSession()
    @State private var controlsVisible = true
    @State private var selectedSourceURL: URL?
    @State private var resumePosition: Double?
    @State private var lastSavedPosition = 0.0
    @State private var nowPlaying: TVNowPlayingController?

    private let progressStore = PlaybackProgressStore()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MPVPlayerView(session: session).ignoresSafeArea()
            if controlsVisible {
                PlayerControlsOverlay(
                    route: route,
                    session: session,
                    selectedSourceURL: selectedSourceURL ?? route.url,
                    onSelectSource: switchSource,
                    onSelectEpisode: selectEpisode
                )
            }
            if let error = session.errorMessage { errorPanel(error) }
        }
        .onAppear {
            selectedSourceURL = route.url
            resumePosition = progressStore.progress(for: route.contentID)?.resumablePosition
            session.load(
                url: route.url,
                startPosition: resumePosition,
                requestHeaders: route.initialSource?.requestHeaders ?? [:]
            )
            let controller = TVNowPlayingController(session: session)
            controller.updateMetadata(title: route.title, subtitle: route.sourceName)
            nowPlaying = controller
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

    private func switchSource(_ source: PlayerSourceOption) {
        saveProgress()
        selectedSourceURL = source.url
        nowPlaying?.updateMetadata(title: route.title, subtitle: source.name)
        session.load(
            url: source.url,
            startPosition: session.position,
            requestHeaders: source.requestHeaders
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
