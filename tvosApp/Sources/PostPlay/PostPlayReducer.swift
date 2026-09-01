import Foundation

/// Inputs and the pure state machine mirroring the Android controller's
/// state mutations (`evaluate`, `selectRecommendation`, `returnToPlayer`,
/// `startPostEndCountdown`, `startTrailer`, `onTrailerEnded`,
/// `clearRecommendationState`).
public enum PostPlayAction: Equatable {
    /// Makes the overlay visible. Mirrors the `evaluate` show path: blocked
    /// while a player interaction surface is active, suppressed forever after
    /// the user has returned to the player once, and never shown without a
    /// loaded recommendation. The caller supplies the initial countdown
    /// (post-end trailer countdown or position-derived countdown).
    case show(blockers: PostPlayBlockerInputs, countdown: Int?)
    /// Overwrites the position-derived trailer countdown.
    case countdownUpdated(Int?)
    /// One-second countdown tick; floors at 1. The controller starts the
    /// trailer once the final second elapses.
    case countdownTick
    /// Pages to the previous recommendation; a no-op outside navigation bounds
    /// or while a change is already in flight.
    case navigatePrevious
    /// Pages to the next recommendation; a no-op outside navigation bounds
    /// or while a change is already in flight.
    case navigateNext
    /// Applies an asynchronously resolved recommendation page.
    case recommendationChanged(PostPlayRecommendation, index: Int)
    /// Clears `isChangingRecommendation` when async resolution fails.
    case recommendationChangeFailed
    /// Populates the session from a loaded candidate list (empty clears loading).
    case recommendationsLoaded([PostPlayRecommendation])
    /// Toggles `isLoadingRecommendation`.
    case loadingRecommendationChanged(Bool)
    /// Toggles `isLoadingTrailer` (detail/trailer enrichment in flight).
    case trailerLoadingChanged(Bool)
    /// Mirrors `returnToPlayer()`: hides the overlay and locks it out.
    case returnToPlayer
    /// Mirrors `startTrailer()`: marks the trailer as playing.
    case trailerStarted
    /// Mirrors `onTrailerEnded()`: marks the trailer as stopped after autoplay.
    case trailerStopped
    /// Mirrors `clearRecommendationState()`: returns to the default state.
    case reset
}

public enum PostPlayReducer {
    /// Reduces `state` by `action`; invalid or out-of-bounds actions return the
    /// state unchanged, mirroring the Android guards.
    public static func reduce(
        _ state: PostPlayRecommendationState,
        _ action: PostPlayAction
    ) -> PostPlayRecommendationState {
        switch action {
        case let .show(blockers, countdown):
            guard !state.hasReturnedToPlayer, !state.isVisible else { return state }
            guard !blockers.isBlocked else { return state }
            guard state.recommendation != nil else { return state }
            var next = state
            next.isVisible = true
            next.countdownSeconds = countdown
            return next

        case let .countdownUpdated(countdown):
            guard state.countdownSeconds != countdown else { return state }
            var next = state
            next.countdownSeconds = countdown
            return next

        case .countdownTick:
            guard let seconds = state.countdownSeconds, seconds > 1 else { return state }
            var next = state
            next.countdownSeconds = seconds - 1
            return next

        case .navigatePrevious:
            return navigate(state, offset: -1)

        case .navigateNext:
            return navigate(state, offset: 1)

        case let .recommendationChanged(recommendation, index):
            var next = state
            next.recommendation = recommendation
            next.recommendationIndex = index
            next.isChangingRecommendation = false
            return next

        case .recommendationChangeFailed:
            guard state.isChangingRecommendation else { return state }
            var next = state
            next.isChangingRecommendation = false
            return next

        case let .recommendationsLoaded(recommendations):
            var next = state
            next.isLoadingRecommendation = false
            guard let first = recommendations.first else { return next }
            next.recommendation = first
            next.recommendationIndex = 0
            next.recommendationCount = recommendations.count
            return next

        case let .loadingRecommendationChanged(isLoading):
            guard state.isLoadingRecommendation != isLoading else { return state }
            var next = state
            next.isLoadingRecommendation = isLoading
            return next

        case let .trailerLoadingChanged(isLoading):
            guard state.isLoadingTrailer != isLoading else { return state }
            var next = state
            next.isLoadingTrailer = isLoading
            return next

        case .returnToPlayer:
            guard state.canReturnToPlayer else { return state }
            var next = state
            next.isVisible = false
            next.hasReturnedToPlayer = true
            next.countdownSeconds = nil
            return next

        case .trailerStarted:
            guard !state.isTrailerPlaying, state.recommendation?.hasTrailer == true else { return state }
            var next = state
            next.isVisible = true
            next.countdownSeconds = nil
            next.isTrailerPlaying = true
            next.hasAutoPlayedTrailer = true
            return next

        case .trailerStopped:
            guard state.isTrailerPlaying || state.countdownSeconds != nil else { return state }
            var next = state
            next.countdownSeconds = nil
            next.isTrailerPlaying = false
            next.hasAutoPlayedTrailer = true
            return next

        case .reset:
            return PostPlayRecommendationState()
        }
    }

    /// Mirrors `selectRecommendation(offset)`: only from a visible overlay,
    /// never re-entrant, always within the candidate bounds.
    private static func navigate(
        _ state: PostPlayRecommendationState,
        offset: Int
    ) -> PostPlayRecommendationState {
        guard state.isVisible, !state.isChangingRecommendation else { return state }
        let target = state.recommendationIndex + offset
        let canMove = offset < 0 ? state.canNavigatePrevious : state.canNavigateNext
        guard canMove, target >= 0, target < state.recommendationCount else { return state }
        var next = state
        next.isChangingRecommendation = true
        next.countdownSeconds = nil
        next.isTrailerPlaying = false
        return next
    }
}
