import SwiftUI

/// Post-play hosting for the player: the Android recommendation rule, the
/// same-genre Cinemeta stand-in loader, and recommendation playback.
extension PlayerView {
    // MARK: - Post-play

    /// Loads similar titles for the ended item and reveals the Android-style
    /// post-play overlay.
    func beginPostPlay() {
        let identity = PostPlayPlaybackIdentity(
            contentType: route.summary.type,
            contentID: route.summary.id,
            videoID: route.videoID,
            season: route.seasonNumber,
            episode: route.episodeNumber
        )
        // Android `shouldUseRecommendations`: movies always; series only
        // when there is no aired next episode to autoplay into.
        let autoplayArmed = NextEpisodeAutoplaySettings.isEnabled()
            && PlayerView.nextEpisode(after: route) != nil
        let kind = PostPlayRules.resolveContentKind(apiType: route.summary.type)
        let useRecommendations = kind == .movie || (kind == .series && !autoplayArmed)
        guard PersistedPlaybackSetting.toggle("playback.postPlayRecommendations", default: true),
              useRecommendations else { return }
        postPlay.begin(identity: identity)
        Task { await loadPostPlayRecommendations(identity: identity) }
    }

    func loadPostPlayRecommendations(identity: PostPlayPlaybackIdentity) async {
        // Same-genre Cinemeta catalog stands in for the Android Trakt/TMDB
        // more-like-this source until those integrations ship.
        let service = StremioService()
        let genre = route.summary.genres.first ?? ""
        do {
            let items = try await service.catalog(
                type: route.summary.type,
                id: "top",
                genre: genre.isEmpty ? nil : genre
            )
            let recommendations = items
                .filter { $0.id != route.summary.id }
                .prefix(6)
                .map { summary in
                    PostPlayRecommendation(
                        id: summary.id,
                        contentType: summary.type,
                        title: summary.name,
                        poster: summary.poster,
                        backdrop: summary.background,
                        description: summary.description,
                        releaseInfo: summary.releaseInfo,
                        genres: Array(summary.genres.prefix(3))
                    )
                }
            postPlayRecommendations = recommendations
            postPlay.begin(recommendations: recommendations, identity: identity)
        } catch {
            postPlay.begin(recommendations: [], identity: identity)
        }
        // The recommendations (or their absence) are loaded; the ended
        // player reveals the overlay now (`handleNaturalEnd`).
        postPlay.handleNaturalEnd()
    }


}
