import XCTest
@testable import NuvioTV

/// Controller-level PostPlay behavior: fetch, prefetch, countdown, advancement.
final class PostPlayControllerTests: XCTestCase {
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

    // MARK: - Controller

    @MainActor
    func testControllerBeginWithLoadedRecommendations() {
        let controller = PostPlayController(fetchRecommendations: { _ in [] })
        controller.begin(
            recommendations: [makeRecommendation(id: "a"), makeRecommendation(id: "b")],
            identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0")
        )
        XCTAssertEqual(controller.state.recommendation?.id, "a")
        XCTAssertEqual(controller.state.recommendationCount, 2)
        XCTAssertFalse(controller.state.isLoadingRecommendation)
        XCTAssertFalse(controller.state.isVisible)
        controller.handleNaturalEnd()
        XCTAssertTrue(controller.state.isVisible)
        XCTAssertNil(controller.state.countdownSeconds, "no trailer means no post-end countdown")
    }

    @MainActor
    func testControllerInjectedFetchSuccessEmptyAndFailure() async {
        let identity = PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0")

        let success = PostPlayController(fetchRecommendations: { _ in [self.makeRecommendation(id: "a"), self.makeRecommendation(id: "b")] })
        success.begin(identity: identity)
        XCTAssertTrue(success.state.isLoadingRecommendation)
        await waitForCondition { !success.state.isLoadingRecommendation }
        XCTAssertEqual(success.state.recommendation?.id, "a")
        XCTAssertEqual(success.state.recommendationCount, 2)

        let empty = PostPlayController(fetchRecommendations: { _ in [] })
        empty.begin(identity: identity)
        await waitForCondition { !empty.state.isLoadingRecommendation }
        XCTAssertNil(empty.state.recommendation)
        XCTAssertFalse(empty.state.blocksNaturalCompletion)

        struct FetchFailure: Error {}
        let failing = PostPlayController(fetchRecommendations: { _ in throw FetchFailure() })
        failing.begin(identity: identity)
        await waitForCondition { !failing.state.isLoadingRecommendation }
        XCTAssertNil(failing.state.recommendation)
        XCTAssertFalse(failing.state.isVisible)
    }

    @MainActor
    func testControllerPrefetchThresholdTriggersSingleFetch() async {
        var fetchCount = 0
        let controller = PostPlayController(
            fetchRecommendations: { _ in
                fetchCount += 1
                return [self.makeRecommendation()]
            }
        )
        controller.begin(
            recommendations: [],
            identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0")
        )
        controller.handlePrefetch(progressFraction: 0.5)
        controller.handlePrefetch(progressFraction: 0.89)
        XCTAssertEqual(fetchCount, 0, "prefetch below the 0.9 threshold must not fetch")
        controller.handlePrefetch(progressFraction: 0.9)
        await waitForCondition { fetchCount == 1 }
        XCTAssertEqual(fetchCount, 1)
        controller.handlePrefetch(progressFraction: 0.95)
        await waitForCondition { fetchCount == 2 }
        XCTAssertEqual(fetchCount, 1, "prefetch is one-shot")
        await waitForCondition { controller.state.recommendation != nil }
        XCTAssertEqual(controller.state.recommendation?.id, "tt1")
    }

    @MainActor
    func testControllerNaturalEndTrailerCountdownAndAutoPlay() async {
        let controller = PostPlayController(
            fetchRecommendations: { _ in [self.makeRecommendation(trailer: "https://x/t.mp4")] },
            countdownTickInterval: 0.01
        )
        controller.begin(identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0"))
        await waitForCondition { controller.state.recommendation != nil }
        controller.handleNaturalEnd()
        XCTAssertTrue(controller.state.isVisible)
        XCTAssertEqual(controller.state.countdownSeconds, 5)
        await waitForCondition { controller.state.isTrailerPlaying }
        XCTAssertTrue(controller.state.hasAutoPlayedTrailer)
        XCTAssertNil(controller.state.countdownSeconds)
        XCTAssertFalse(controller.state.canReturnToPlayer)
    }

    @MainActor
    func testControllerAdvancementPagesThroughRecommendations() async {
        let controller = PostPlayController(fetchRecommendations: { _ in [] })
        controller.begin(
            recommendations: [makeRecommendation(id: "a"), makeRecommendation(id: "b"), makeRecommendation(id: "c")],
            identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0")
        )
        controller.handleNaturalEnd()
        controller.showNextRecommendation()
        XCTAssertTrue(controller.state.isChangingRecommendation)
        await waitForCondition { !controller.state.isChangingRecommendation }
        XCTAssertEqual(controller.state.recommendation?.id, "b")
        XCTAssertEqual(controller.state.recommendationIndex, 1)
        controller.showNextRecommendation()
        await waitForCondition { controller.state.recommendationIndex == 2 }
        controller.showNextRecommendation()
        XCTAssertEqual(controller.state.recommendationIndex, 2, "advancing past the last page is a no-op")
        controller.showPreviousRecommendation()
        await waitForCondition { controller.state.recommendationIndex == 1 }
        XCTAssertEqual(controller.state.recommendation?.id, "b")
    }

    @MainActor
    func testControllerReturnToPlayerCancelsAdvancement() async {
        let controller = PostPlayController(
            fetchRecommendations: { _ in [] },
            transitionDuration: 0.05
        )
        controller.begin(
            recommendations: [makeRecommendation(id: "a"), makeRecommendation(id: "b")],
            identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0")
        )
        controller.handleNaturalEnd()
        controller.showNextRecommendation()
        XCTAssertTrue(controller.state.isChangingRecommendation)
        // Return to the player synchronously: the pending advancement task is
        // cancelled before it can apply the paged recommendation.
        controller.returnToPlayer()
        XCTAssertFalse(controller.state.isVisible)
        XCTAssertTrue(controller.state.hasReturnedToPlayer)
        await waitForCondition {
            !controller.state.isChangingRecommendation && !controller.state.isVisible
        }
        XCTAssertEqual(controller.state.recommendationIndex, 0, "cancelled advancement must not apply")
        XCTAssertTrue(controller.state.hasReturnedToPlayer)
        // Android parity: after the transition the whole state collapses to the
        // returned-to-player lockout, dropping the recommendation.
        await waitForCondition {
            controller.state.recommendation == nil && controller.state.recommendationCount == 0
        }
        XCTAssertFalse(controller.state.isVisible)
        // The overlay is locked out for the rest of the session.
        controller.handleNaturalEnd()
        XCTAssertFalse(controller.state.isVisible)
    }

    @MainActor
    func testControllerIdentityChangeResetsSession() async {
        let controller = PostPlayController(fetchRecommendations: { _ in [self.makeRecommendation()] })
        controller.begin(
            recommendations: [makeRecommendation(id: "a")],
            identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt0")
        )
        controller.handleNaturalEnd()
        XCTAssertTrue(controller.state.isVisible)
        controller.begin(identity: PostPlayPlaybackIdentity(contentType: "movie", contentID: "tt9"))
        XCTAssertFalse(controller.state.isVisible)
        XCTAssertTrue(controller.state.isLoadingRecommendation)
        await waitForCondition { controller.state.recommendation != nil }
        XCTAssertEqual(controller.state.recommendationCount, 1)
    }

    // MARK: - Helpers

    @MainActor
    private func waitForCondition(
        timeout: TimeInterval = 2,
        _ condition: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
