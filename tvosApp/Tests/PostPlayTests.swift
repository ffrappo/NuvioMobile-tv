import XCTest
@testable import NuvioTV

final class PostPlayTests: XCTestCase {
    // MARK: - Fixtures

    private func makeRecommendation(
        id: String = "tt1",
        contentType: String = "movie",
        trailer: String? = nil,
        backdrop: String? = "https://example.test/backdrop.jpg"
    ) -> PostPlayRecommendation {
        PostPlayRecommendation(
            id: id,
            contentType: contentType,
            title: "Recommendation \(id)",
            poster: "https://example.test/poster.jpg",
            backdrop: backdrop,
            logo: nil,
            description: "Description for \(id)",
            releaseInfo: "2024",
            rating: 7.6,
            genres: ["Drama", "Thriller", "Extra"],
            runtime: "118 min",
            trailerVideoURL: trailer
        )
    }

    private func makeLoadedState(
        count: Int = 2,
        index: Int = 0,
        visible: Bool = true
    ) -> PostPlayRecommendationState {
        var state = PostPlayRecommendationState()
        state = PostPlayReducer.reduce(
            state,
            .recommendationsLoaded((0..<count).map { makeRecommendation(id: "tt\($0)") })
        )
        state = PostPlayReducer.reduce(state, .show(blockers: PostPlayBlockerInputs(), countdown: nil))
        state.recommendationIndex = index
        return state
    }

    // MARK: - Derived rule truth tables

    func testDerivedNavigationRulesTruthTable() {
        var state = PostPlayRecommendationState(recommendationIndex: 0, recommendationCount: 3)
        XCTAssertFalse(state.canNavigatePrevious)
        XCTAssertTrue(state.canNavigateNext)
        state.recommendationIndex = 2
        XCTAssertTrue(state.canNavigatePrevious)
        XCTAssertFalse(state.canNavigateNext)
        state.recommendationIndex = 1
        XCTAssertTrue(state.canNavigatePrevious)
        XCTAssertTrue(state.canNavigateNext)
        state.isChangingRecommendation = true
        XCTAssertFalse(state.canNavigatePrevious)
        XCTAssertFalse(state.canNavigateNext)
        state.isChangingRecommendation = false
        state.recommendationIndex = 0
        state.recommendationCount = 1
        XCTAssertFalse(state.canNavigatePrevious)
        XCTAssertFalse(state.canNavigateNext)
    }

    func testDerivedReturnToPlayerTruthTable() {
        var state = PostPlayRecommendationState(isVisible: true)
        XCTAssertTrue(state.canReturnToPlayer)
        state.isTrailerPlaying = true
        XCTAssertFalse(state.canReturnToPlayer)
        state.isTrailerPlaying = false
        state.hasAutoPlayedTrailer = true
        XCTAssertFalse(state.canReturnToPlayer)
        state.hasAutoPlayedTrailer = false
        state.isVisible = false
        XCTAssertFalse(state.canReturnToPlayer)
    }

    func testDerivedBlocksNaturalCompletionTruthTable() {
        XCTAssertFalse(PostPlayRecommendationState().blocksNaturalCompletion)
        XCTAssertTrue(PostPlayRecommendationState(isVisible: true).blocksNaturalCompletion)
        XCTAssertTrue(
            PostPlayRecommendationState(isLoadingRecommendation: true).blocksNaturalCompletion
        )
        XCTAssertFalse(
            PostPlayRecommendationState(
                isLoadingRecommendation: true,
                hasReturnedToPlayer: true
            ).blocksNaturalCompletion
        )
        XCTAssertFalse(
            PostPlayRecommendationState(
                isLoadingRecommendation: false,
                hasReturnedToPlayer: false
            ).blocksNaturalCompletion
        )
    }

    func testTimingConstantsMatchAndroidSource() {
        XCTAssertEqual(PostPlayTiming.prefetchProgress, 0.9)
        XCTAssertEqual(PostPlayTiming.prefetchRemainingSeconds, 600)
        XCTAssertEqual(PostPlayTiming.trailerCountdownSeconds, 5)
        XCTAssertEqual(PostPlayTiming.transitionDuration, 0.42)
        XCTAssertEqual(PostPlayTiming.maximumRecommendations, 4)
    }

    // MARK: - Pure rules

    func testPrefetchThresholdTruthTable() {
        // Durations stay above the 10-minute lead window so only the
        // progress threshold decides.
        // Positions stay outside the 10-minute lead window so only the
        // progress threshold decides.
        XCTAssertFalse(PostPlayRules.shouldPrefetch(positionSeconds: 0, durationSeconds: 20 * 60))
        XCTAssertFalse(PostPlayRules.shouldPrefetch(positionSeconds: 9 * 60, durationSeconds: 20 * 60))
        XCTAssertTrue(PostPlayRules.shouldPrefetch(positionSeconds: 18 * 60, durationSeconds: 20 * 60))
        XCTAssertTrue(PostPlayRules.shouldPrefetch(positionSeconds: 19 * 60, durationSeconds: 20 * 60))
        XCTAssertFalse(PostPlayRules.shouldPrefetch(positionSeconds: 200, durationSeconds: 0))
        // Remaining-time lead window: 10 minutes before the end.
        XCTAssertTrue(PostPlayRules.shouldPrefetch(positionSeconds: 20 * 60, durationSeconds: 30 * 60))
        XCTAssertFalse(PostPlayRules.shouldPrefetch(positionSeconds: 15 * 60, durationSeconds: 30 * 60))
        // Custom threshold below the lead-window crossover decides early.
        XCTAssertTrue(PostPlayRules.shouldPrefetch(positionSeconds: 9 * 60, durationSeconds: 20 * 60, progressThreshold: 0.4))
        XCTAssertFalse(PostPlayRules.shouldPrefetch(positionSeconds: 9 * 60, durationSeconds: 20 * 60, progressThreshold: 1.5))
    }

    func testCountdownMathAndClamp() {
        XCTAssertNil(PostPlayRules.countdownSeconds(positionSeconds: 10, durationSeconds: 0))
        XCTAssertNil(PostPlayRules.countdownSeconds(positionSeconds: 0, durationSeconds: 120))
        XCTAssertNil(PostPlayRules.countdownSeconds(positionSeconds: 110, durationSeconds: 120))
        // Inside the five-second window: ceiling of remaining seconds.
        XCTAssertEqual(PostPlayRules.countdownSeconds(positionSeconds: 116, durationSeconds: 120), 4)
        XCTAssertEqual(PostPlayRules.countdownSeconds(positionSeconds: 116.2, durationSeconds: 120), 4)
        XCTAssertEqual(PostPlayRules.countdownSeconds(positionSeconds: 115.001, durationSeconds: 120), 5)
        // Clamps: past-the-end positions floor at 1, never exceed 5.
        XCTAssertEqual(PostPlayRules.countdownSeconds(positionSeconds: 120, durationSeconds: 120), 1)
        XCTAssertEqual(PostPlayRules.countdownSeconds(positionSeconds: 200, durationSeconds: 120), 1)
    }

    func testResolveContentKind() {
        XCTAssertEqual(PostPlayRules.resolveContentKind(apiType: "movie"), .movie)
        XCTAssertEqual(PostPlayRules.resolveContentKind(apiType: " Film "), .movie)
        XCTAssertEqual(PostPlayRules.resolveContentKind(apiType: "series"), .series)
        XCTAssertEqual(PostPlayRules.resolveContentKind(apiType: "TV"), .series)
        XCTAssertEqual(PostPlayRules.resolveContentKind(apiType: "tvshow"), .series)
        XCTAssertNil(PostPlayRules.resolveContentKind(apiType: "channel"))
        XCTAssertNil(PostPlayRules.resolveContentKind(apiType: nil))
        XCTAssertEqual(PostPlayRules.resolveContentKind(apiType: "other", fallback: .series), .series)
    }

    func testShouldUseRecommendationsTruthTable() {
        XCTAssertTrue(PostPlayRules.shouldUseRecommendations(
            contentType: "movie", isNextEpisodeMetadataResolved: false, nextEpisodeHasAired: nil
        ))
        XCTAssertFalse(PostPlayRules.shouldUseRecommendations(
            contentType: "movie", isNextEpisodeMetadataResolved: false, nextEpisodeHasAired: nil, enabled: false
        ))
        XCTAssertFalse(PostPlayRules.shouldUseRecommendations(
            contentType: "series", isNextEpisodeMetadataResolved: false, nextEpisodeHasAired: nil
        ))
        XCTAssertTrue(PostPlayRules.shouldUseRecommendations(
            contentType: "series", isNextEpisodeMetadataResolved: true, nextEpisodeHasAired: nil
        ))
        XCTAssertFalse(PostPlayRules.shouldUseRecommendations(
            contentType: "series", isNextEpisodeMetadataResolved: true, nextEpisodeHasAired: true
        ))
        XCTAssertFalse(PostPlayRules.shouldUseRecommendations(
            contentType: "other", isNextEpisodeMetadataResolved: true, nextEpisodeHasAired: nil
        ))
    }

    func testShouldShowTrailerAction() {
        let withTrailer = makeRecommendation(trailer: "https://example.test/trailer.mp4")
        let withoutTrailer = makeRecommendation()
        XCTAssertTrue(PostPlayRules.shouldShowTrailerAction(
            recommendation: withTrailer, isTrailerPlaying: false, trailerPlaybackEnabled: true
        ))
        XCTAssertFalse(PostPlayRules.shouldShowTrailerAction(
            recommendation: withTrailer, isTrailerPlaying: true, trailerPlaybackEnabled: true
        ))
        XCTAssertFalse(PostPlayRules.shouldShowTrailerAction(
            recommendation: withoutTrailer, isTrailerPlaying: false, trailerPlaybackEnabled: true
        ))
        XCTAssertFalse(PostPlayRules.shouldShowTrailerAction(
            recommendation: withTrailer, isTrailerPlaying: false, trailerPlaybackEnabled: false
        ))
        XCTAssertFalse(makeRecommendation(trailer: "   ").hasTrailer)
    }

    func testOrderedCandidatesCapAndArtworkPreference() {
        // tt0 carries no artwork at all; tt1 is the first candidate with art.
        var artless = makeRecommendation(id: "tt0", backdrop: nil)
        artless = PostPlayRecommendation(
            id: artless.id, contentType: artless.contentType, title: artless.title,
            poster: nil, backdrop: nil, logo: nil, description: artless.description,
            releaseInfo: artless.releaseInfo, rating: artless.rating, genres: artless.genres,
            runtime: artless.runtime, trailerVideoURL: nil
        )
        let six = [artless] + (1..<6).map {
            makeRecommendation(id: "tt\($0)", backdrop: "https://x/\($0).jpg")
        }
        let ordered = PostPlayRules.orderedCandidates(six)
        XCTAssertEqual(ordered.count, PostPlayTiming.maximumRecommendations)
        XCTAssertEqual(ordered.first?.id, "tt1", "first candidate with artwork leads")
        XCTAssertTrue(ordered.contains { $0.id == "tt0" })
    }

    // MARK: - Reducer transitions

    func testShowRespectsBlockersAndLockouts() {
        let loaded = PostPlayReducer.reduce(
            PostPlayRecommendationState(),
            .recommendationsLoaded([makeRecommendation()])
        )
        // Blocked by an active player interaction surface.
        var blocked = PostPlayBlockerInputs()
        blocked.showsPauseOverlay = true
        XCTAssertEqual(PostPlayReducer.reduce(loaded, .show(blockers: blocked, countdown: nil)), loaded)
        blocked.showsPauseOverlay = false
        blocked.showsSourcesPanel = true
        XCTAssertEqual(PostPlayReducer.reduce(loaded, .show(blockers: blocked, countdown: 5)), loaded)
        // Without a loaded recommendation there is nothing to show.
        let empty = PostPlayRecommendationState()
        XCTAssertEqual(PostPlayReducer.reduce(empty, .show(blockers: PostPlayBlockerInputs(), countdown: nil)), empty)
        // Valid show applies the initial countdown.
        var shown = PostPlayReducer.reduce(loaded, .show(blockers: PostPlayBlockerInputs(), countdown: 5))
        XCTAssertTrue(shown.isVisible)
        XCTAssertEqual(shown.countdownSeconds, 5)
        // Locked out after returning to the player.
        shown = PostPlayReducer.reduce(shown, .returnToPlayer)
        XCTAssertEqual(
            PostPlayReducer.reduce(shown, .show(blockers: PostPlayBlockerInputs(), countdown: nil)),
            shown
        )
    }

    func testCountdownReducerTransitions() {
        var state = makeLoadedState()
        state = PostPlayReducer.reduce(state, .countdownUpdated(5))
        XCTAssertEqual(state.countdownSeconds, 5)
        // Identical value is a no-op.
        XCTAssertEqual(PostPlayReducer.reduce(state, .countdownUpdated(5)), state)
        state = PostPlayReducer.reduce(state, .countdownTick)
        XCTAssertEqual(state.countdownSeconds, 4)
        state = PostPlayReducer.reduce(state, .countdownUpdated(1))
        // Tick floors at one; the controller starts the trailer instead.
        XCTAssertEqual(PostPlayReducer.reduce(state, .countdownTick), state)
        state = PostPlayReducer.reduce(state, .countdownUpdated(nil))
        XCTAssertNil(state.countdownSeconds)
        XCTAssertEqual(PostPlayReducer.reduce(state, .countdownTick), state)
    }

    func testNavigationBoundsAndTransitions() {
        // Not visible: navigation is a no-op.
        var hidden = PostPlayReducer.reduce(
            PostPlayRecommendationState(),
            .recommendationsLoaded([makeRecommendation(id: "a"), makeRecommendation(id: "b")])
        )
        XCTAssertEqual(PostPlayReducer.reduce(hidden, .navigateNext), hidden)
        hidden = PostPlayReducer.reduce(hidden, .show(blockers: PostPlayBlockerInputs(), countdown: nil))
        // Out-of-bounds paging is a no-op.
        XCTAssertEqual(PostPlayReducer.reduce(hidden, .navigatePrevious), hidden)
        var last = makeLoadedState(count: 2, index: 1)
        XCTAssertEqual(PostPlayReducer.reduce(last, .navigateNext), last)
        // Valid navigation: changing state, countdown and trailer cleared.
        var state = makeLoadedState(count: 3, index: 1)
        state.countdownSeconds = 5
        state.isTrailerPlaying = true
        let navigated = PostPlayReducer.reduce(state, .navigateNext)
        XCTAssertTrue(navigated.isChangingRecommendation)
        XCTAssertNil(navigated.countdownSeconds)
        XCTAssertFalse(navigated.isTrailerPlaying)
        XCTAssertFalse(navigated.canNavigateNext)
        // Re-entrant navigation while changing is a no-op.
        XCTAssertEqual(PostPlayReducer.reduce(navigated, .navigateNext), navigated)
        XCTAssertEqual(PostPlayReducer.reduce(navigated, .navigatePrevious), navigated)
        // Resolution applies the new page and clears changing.
        let resolved = PostPlayReducer.reduce(
            navigated,
            .recommendationChanged(makeRecommendation(id: "tt2"), index: 2)
        )
        XCTAssertEqual(resolved.recommendationIndex, 2)
        XCTAssertEqual(resolved.recommendation?.id, "tt2")
        XCTAssertFalse(resolved.isChangingRecommendation)
        // Failed resolution only clears the changing flag.
        let failed = PostPlayReducer.reduce(navigated, .recommendationChangeFailed)
        XCTAssertFalse(failed.isChangingRecommendation)
        XCTAssertEqual(failed.recommendationIndex, 1)
        XCTAssertEqual(
            PostPlayReducer.reduce(state, .recommendationChangeFailed),
            state,
            "failure without a pending change is a no-op"
        )
    }

    func testLoadActions() {
        var state = PostPlayReducer.reduce(PostPlayRecommendationState(), .loadingRecommendationChanged(true))
        XCTAssertTrue(state.isLoadingRecommendation)
        XCTAssertEqual(
            PostPlayReducer.reduce(state, .loadingRecommendationChanged(true)),
            state,
            "redundant loading flag is a no-op"
        )
        state = PostPlayReducer.reduce(state, .recommendationsLoaded([]))
        XCTAssertFalse(state.isLoadingRecommendation)
        XCTAssertNil(state.recommendation)
        XCTAssertEqual(state.recommendationCount, 0)
        state = PostPlayReducer.reduce(
            state,
            .recommendationsLoaded([makeRecommendation(id: "a"), makeRecommendation(id: "b")])
        )
        XCTAssertFalse(state.isLoadingRecommendation)
        XCTAssertEqual(state.recommendation?.id, "a")
        XCTAssertEqual(state.recommendationIndex, 0)
        XCTAssertEqual(state.recommendationCount, 2)
        var trailerState = PostPlayReducer.reduce(state, .trailerLoadingChanged(true))
        XCTAssertTrue(trailerState.isLoadingTrailer)
        XCTAssertEqual(PostPlayReducer.reduce(trailerState, .trailerLoadingChanged(true)), trailerState)
        trailerState = PostPlayReducer.reduce(trailerState, .trailerLoadingChanged(false))
        XCTAssertFalse(trailerState.isLoadingTrailer)
    }

    func testReturnToPlayerAndReset() {
        // Invalid: not visible.
        let hidden = PostPlayRecommendationState()
        XCTAssertEqual(PostPlayReducer.reduce(hidden, .returnToPlayer), hidden)
        // Invalid: trailer playing or already auto-played.
        var trailer = makeLoadedState()
        trailer.isTrailerPlaying = true
        XCTAssertEqual(PostPlayReducer.reduce(trailer, .returnToPlayer), trailer)
        var played = makeLoadedState()
        played.hasAutoPlayedTrailer = true
        XCTAssertEqual(PostPlayReducer.reduce(played, .returnToPlayer), played)
        // Valid: hides, locks out, clears countdown.
        var state = makeLoadedState()
        state.countdownSeconds = 3
        let returned = PostPlayReducer.reduce(state, .returnToPlayer)
        XCTAssertFalse(returned.isVisible)
        XCTAssertTrue(returned.hasReturnedToPlayer)
        XCTAssertNil(returned.countdownSeconds)
        XCTAssertFalse(returned.canReturnToPlayer)
        // Reset returns to defaults.
        XCTAssertEqual(PostPlayReducer.reduce(returned, .reset), PostPlayRecommendationState())
    }

    func testTrailerTransitions() {
        // Invalid: no trailer, or already playing.
        let withoutTrailer = makeLoadedState()
        XCTAssertEqual(PostPlayReducer.reduce(withoutTrailer, .trailerStarted), withoutTrailer)
        var withTrailer = makeLoadedState()
        withTrailer.recommendation = makeRecommendation(trailer: "https://x/t.mp4")
        var playing = PostPlayReducer.reduce(withTrailer, .trailerStarted)
        XCTAssertTrue(playing.isTrailerPlaying)
        XCTAssertTrue(playing.hasAutoPlayedTrailer)
        XCTAssertTrue(playing.isVisible)
        XCTAssertNil(playing.countdownSeconds)
        XCTAssertEqual(PostPlayReducer.reduce(playing, .trailerStarted), playing, "re-start is a no-op")
        // Stop mirrors onTrailerEnded.
        var stopped = PostPlayReducer.reduce(playing, .trailerStopped)
        XCTAssertFalse(stopped.isTrailerPlaying)
        XCTAssertTrue(stopped.hasAutoPlayedTrailer)
        XCTAssertEqual(PostPlayReducer.reduce(stopped, .trailerStopped), stopped, "idle stop is a no-op")
        // Trailer stop clears a pending countdown too.
        playing.countdownSeconds = 4
        stopped = PostPlayReducer.reduce(playing, .trailerStopped)
        XCTAssertNil(stopped.countdownSeconds)
    }
}
