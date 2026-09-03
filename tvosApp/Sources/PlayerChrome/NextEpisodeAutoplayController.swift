import SwiftUI

/// Next-episode autoplay flow for the player: streams are fetched for the
/// next episode, a countdown runs, and playback replaces the route.
extension PlayerView {
    /// Arms autoplay when the setting is on, a next episode exists, and the
    /// ended playback crossed the configured threshold.
    @MainActor
    func beginNextEpisodeAutoplayIfArmed() {
        guard nextEpisodeAutoplay == nil,
              NextEpisodeAutoplaySettings.isEnabled(),
              let next = Self.nextEpisode(after: route) else { return }
        let fraction = session.duration > 0
            ? session.position / session.duration
            : 1.0
        guard fraction >= NextEpisodeAutoplaySettings.triggerFraction() else { return }
        nextEpisodeAutoplay = NextEpisodeAutoplayState(episode: next, phase: .searching)
        autoplaySearchTask = Task { await runAutoplaySearch(for: next) }
    }

    @MainActor
    func cancelNextEpisodeAutoplay() {
        autoplaySearchTask?.cancel()
        autoplaySearchTask = nil
        nextEpisodeAutoplay = nil
    }

    /// The episode following the current one, applying Android
    /// `PlayerNextEpisodeRules.resolveNextEpisode`: season/episode-sorted
    /// across seasons; absolute-numbered content (no season) orders by
    /// episode number alone.
    static func nextEpisode(after route: PlayerRoute) -> PlayerEpisodeOption? {
        let episodes = route.episodes
        let current = episodes.first { $0.id == route.videoID }
        let currentSeason = current?.seasonNumber ?? route.seasonNumber
        let currentEpisodeNumber = current?.episodeNumber ?? route.episodeNumber
        guard let currentEpisodeNumber else { return nil }

        if currentSeason == nil {
            let sorted = episodes
                .filter { $0.episodeNumber != nil }
                .sorted { ($0.seasonNumber ?? 0, $0.episodeNumber ?? 0) < ($1.seasonNumber ?? 0, $1.episodeNumber ?? 0) }
            guard let index = sorted.firstIndex(where: { $0.episodeNumber == currentEpisodeNumber }) else {
                return nil
            }
            return sorted.indices.contains(index + 1) ? sorted[index + 1] : nil
        }

        let sorted = episodes
            .filter { $0.seasonNumber != nil && $0.episodeNumber != nil }
            .sorted {
                ($0.seasonNumber ?? .max, $0.episodeNumber ?? .max)
                    < ($1.seasonNumber ?? .max, $1.episodeNumber ?? .max)
            }
        guard let index = sorted.firstIndex(where: {
            $0.seasonNumber == currentSeason && $0.episodeNumber == currentEpisodeNumber
        }) else { return nil }
        return sorted.indices.contains(index + 1) ? sorted[index + 1] : nil
    }

    /// Fetches streams, picks the first playable source, then counts down.
    @MainActor
    private func runAutoplaySearch(for episode: PlayerEpisodeOption) async {
        var sources: [StreamSource] = []
        let request = StreamRequest(
            type: route.summary.type,
            id: episode.id,
            addons: addonStore.enabledAddons
        )
        for await result in await StreamRepository.shared.results(for: request) {
            guard !Task.isCancelled else { return }
            sources.append(contentsOf: result.sources)
        }
        guard !Task.isCancelled else { return }

        let ordered = TVPlaybackCapabilities.current.ordered(sources)
        guard let source = ordered.first(where: { $0.stream.directURL != nil }),
              let url = source.stream.directURL else {
            // Nothing playable: leave the post-play recommendations visible.
            nextEpisodeAutoplay = nil
            return
        }
        let capabilities = TVPlaybackCapabilities.current
        guard capabilities.compatibility(for: source.stream.displayInfo).issue == nil else {
            nextEpisodeAutoplay = nil
            return
        }

        nextEpisodeAutoplay?.phase = .countdown(
            secondsRemaining: NextEpisodeAutoplaySettings.countdownSeconds
        )
        for remaining in stride(from: NextEpisodeAutoplaySettings.countdownSeconds, through: 1, by: -1) {
            guard !Task.isCancelled else { return }
            nextEpisodeAutoplay?.phase = .countdown(secondsRemaining: remaining)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
        }
        guard !Task.isCancelled, nextEpisodeAutoplay != nil else { return }
        saveProgress()
        onReplaceRoute?(Self.autoplayRoute(from: route, episode: episode, source: source, url: url))
    }

    /// Builds the replacement route for the next episode from the found
    /// source, mirroring StreamSourcesView.play.
    static func autoplayRoute(
        from route: PlayerRoute,
        episode: PlayerEpisodeOption,
        source: StreamSource,
        url: URL
    ) -> PlayerRoute {
        let ordered = TVPlaybackCapabilities.current.ordered([source])
        return PlayerRoute(
            url: url,
            contentID: episode.id,
            imdbID: route.imdbID,
            title: route.title,
            sourceName: source.stream.name,
            summary: route.summary,
            videoID: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            episodeTitle: episode.title,
            availableSources: ordered.compactMap(PlayerSourceOption.init),
            streamSources: ordered,
            episodes: route.episodes,
            onSelectEpisode: route.onSelectEpisode
        )
    }
}

