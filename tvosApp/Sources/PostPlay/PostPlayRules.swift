import Foundation

/// Pure decision rules ported from `PostPlayRecommendationState.kt`,
/// `PostPlayRecommendationTiming.kt`, and `PostPlayRecommendationController.kt`.
public enum PostPlayRules {

    /// `shouldPrefetchPostPlayRecommendation(positionMs, durationMs, progressThreshold)`:
    /// prefetch once playback progress reaches the threshold or the remaining
    /// time drops to the prefetch lead window.
    public static func shouldPrefetch(
        positionSeconds: Double,
        durationSeconds: Double,
        progressThreshold: Double = PostPlayTiming.prefetchProgress
    ) -> Bool {
        guard durationSeconds > 0 else { return false }
        let position = min(max(positionSeconds, 0), durationSeconds)
        let remaining = durationSeconds - position
        let progress = position / durationSeconds
        let clampedThreshold = min(max(progressThreshold, 0), 1)
        return progress >= clampedThreshold || remaining <= PostPlayTiming.prefetchRemainingSeconds
    }

    /// `postPlayRecommendationCountdownSeconds(positionMs, durationMs)`: the
    /// trailer auto-play countdown shown during the final seconds of playback.
    /// Returns `nil` outside the countdown window; otherwise the ceiling of the
    /// remaining seconds clamped to `1...trailerCountdownSeconds`.
    public static func countdownSeconds(
        positionSeconds: Double,
        durationSeconds: Double
    ) -> Int? {
        guard durationSeconds > 0 else { return nil }
        let remainingMs = max((durationSeconds - positionSeconds) * 1_000, 0)
        let window = Double(PostPlayTiming.trailerCountdownSeconds) * 1_000
        guard remainingMs <= window else { return nil }
        let seconds = Int(ceil(remainingMs / 1_000))
        return min(max(seconds, 1), PostPlayTiming.trailerCountdownSeconds)
    }

    /// `resolvePostPlayContentType(apiType, fallback)`: maps addon API type
    /// strings to the movie/series content kind.
    public static func resolveContentKind(
        apiType: String?,
        fallback: PostPlayContentKind? = nil
    ) -> PostPlayContentKind? {
        switch apiType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movie", "film":
            return .movie
        case "series", "tv", "show", "tvshow":
            return .series
        default:
            return fallback
        }
    }

    /// `shouldUsePostPlayRecommendation(contentType, isNextEpisodeMetadataResolved,
    /// nextEpisodeHasAired, enabled)`: post-play recommendations apply to movies
    /// and to series episodes without an unaired next episode.
    public static func shouldUseRecommendations(
        contentType: String?,
        isNextEpisodeMetadataResolved: Bool,
        nextEpisodeHasAired: Bool?,
        enabled: Bool = true
    ) -> Bool {
        guard enabled else { return false }
        switch resolveContentKind(apiType: contentType) {
        case .movie:
            return true
        case .series:
            return isNextEpisodeMetadataResolved && nextEpisodeHasAired != true
        case nil:
            return false
        }
    }

    /// `shouldShowPostPlayTrailerAction(recommendation, isTrailerPlaying,
    /// inAppTrailerPlaybackEnabled)`.
    public static func shouldShowTrailerAction(
        recommendation: PostPlayRecommendation,
        isTrailerPlaying: Bool,
        trailerPlaybackEnabled: Bool
    ) -> Bool {
        trailerPlaybackEnabled && recommendation.hasTrailer && !isTrailerPlaying
    }

    /// `isShortPlaceholderDuration` guard used by the controller: streams whose
    /// reported duration looks like a placeholder never trigger post-play.
    public static func isShortPlaceholderDuration(_ durationSeconds: Double) -> Bool {
        durationSeconds > 0 && durationSeconds < 60
    }

    /// Caps the candidate list to `MAX_POST_PLAY_RECOMMENDATIONS`, preferring
    /// the first candidate with artwork (mirrors `loadCandidates` ordering).
    public static func orderedCandidates(_ recommendations: [PostPlayRecommendation]) -> [PostPlayRecommendation] {
        let capped = Array(recommendations.prefix(PostPlayTiming.maximumRecommendations))
        guard let firstWithArtwork = capped.first(where: { !(($0.backdrop ?? $0.poster) ?? "").isEmpty }) else {
            return capped
        }
        guard firstWithArtwork.id != capped.first?.id else { return capped }
        return [firstWithArtwork] + capped.filter { $0.id != firstWithArtwork.id }
    }
}
