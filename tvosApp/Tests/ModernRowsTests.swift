import XCTest
@testable import NuvioTV

final class ModernRowsTests: XCTestCase {
    func testGeometryDefaults() {
        XCTAssertEqual(ModernHomeRowTokens.posterWidth, 126)
        XCTAssertEqual(ModernHomeRowTokens.posterHeight, 189)
        XCTAssertEqual(ModernHomeRowTokens.posterCornerRadius, 12)
        XCTAssertEqual(ModernHomeRowTokens.backdropWidth, 320)
        XCTAssertEqual(ModernHomeRowTokens.backdropHeight, 180)
        XCTAssertEqual(ModernHomeRowTokens.backdropCornerRadius, 16)
        XCTAssertEqual(ModernHomeRowTokens.episodeWidth, 320)
        XCTAssertEqual(ModernHomeRowTokens.episodeHeight, 207)
        XCTAssertEqual(ModernHomeRowTokens.sidePanelCornerRadius, 20)
        XCTAssertEqual(ModernHomeRowTokens.settingsContainerCornerRadius, 28)
    }

    func testBadgeAndProgressVisibilityLogicIncludingClamp() {
        let unwatched = PosterCardStatus(
            isWatched: false,
            isInLibrary: true,
            isUnwatchedNew: true,
            progressFraction: 1.4
        )
        XCTAssertEqual(unwatched.visibleBadges, [.inLibrary, .unwatchedNew])
        XCTAssertTrue(unwatched.showsProgress)
        XCTAssertEqual(unwatched.clampedProgress, 1)

        let watched = PosterCardStatus(
            isWatched: true,
            isInLibrary: true,
            isUnwatchedNew: true,
            progressFraction: -0.25
        )
        XCTAssertEqual(watched.visibleBadges, [.watched, .inLibrary])
        XCTAssertEqual(watched.clampedProgress, 0)

        let noProgress = PosterCardStatus(progressFraction: nil)
        XCTAssertFalse(noProgress.showsProgress)
        XCTAssertEqual(noProgress.clampedProgress, 0)
    }

    func testPrefetchTriggerThresholdMathAndDeduplication() {
        XCTAssertFalse(
            RailPrefetchTrigger.isNearTrailingEdge(index: 5, itemCount: 10)
        )
        XCTAssertTrue(
            RailPrefetchTrigger.isNearTrailingEdge(index: 6, itemCount: 10)
        )
        XCTAssertTrue(
            RailPrefetchTrigger.isNearTrailingEdge(index: 0, itemCount: 4)
        )
        XCTAssertFalse(
            RailPrefetchTrigger.isNearTrailingEdge(index: -1, itemCount: 10)
        )

        var calls = 0
        let trigger = RailPrefetchTrigger { calls += 1 }
        trigger.observe(index: 5, itemCount: 10, hasMore: true, isLoading: false)
        XCTAssertEqual(calls, 0)

        trigger.observe(index: 6, itemCount: 10, hasMore: true, isLoading: false)
        trigger.observe(index: 9, itemCount: 10, hasMore: true, isLoading: false)
        XCTAssertEqual(calls, 1)

        trigger.observe(index: 8, itemCount: 12, hasMore: true, isLoading: true)
        XCTAssertEqual(calls, 1)
        trigger.observe(index: 8, itemCount: 12, hasMore: true, isLoading: false)
        XCTAssertEqual(calls, 2)
    }

    func testRailFocusModelAllowsOnlyOneExpansion() {
        let model = RailFocusModel()
        let first = RailFocusID(sectionID: "popular", itemID: "one")
        let second = RailFocusID(sectionID: "recent", itemID: "two")

        model.focus(first)
        XCTAssertTrue(model.isExpanded(first))

        model.focus(second)
        XCTAssertFalse(model.isExpanded(first))
        XCTAssertTrue(model.isExpanded(second))

        model.blur(first)
        XCTAssertTrue(model.isExpanded(second))
        model.blur(second)
        XCTAssertNil(model.expandedItem)
    }

    func testSpacingConstants() {
        XCTAssertEqual(ModernHomeRowTokens.screenHorizontalMargin, 48)
        XCTAssertEqual(ModernHomeRowTokens.screenVerticalMargin, 24)
        XCTAssertEqual(ModernHomeRowTokens.railLeadingMargin, 52)
        XCTAssertEqual(ModernHomeRowTokens.itemGap, 12)
        XCTAssertEqual(ModernHomeRowTokens.rowGap, 24)
        XCTAssertEqual(ModernHomeRowTokens.focusRingWidth, 2)
        XCTAssertEqual(ModernHomeRowTokens.progressHeight, 3)
        XCTAssertEqual(RailPrefetchTrigger.trailingThreshold, 4)
    }
}
