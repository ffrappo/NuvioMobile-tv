import XCTest
@testable import NuvioTV

final class ModernHeroTests: XCTestCase {
    @MainActor
    func testAutoAdvanceRotationUsesInjectedScheduler() async {
        let clock = ManualHeroClock()
        let presentation = HeroPresentation(
            pages: makePages(3),
            scheduler: HeroRotationScheduler { duration in
                try await clock.sleep(for: duration)
            }
        )

        presentation.startAutoAdvance()
        await clock.waitUntilScheduled()
        await clock.advance()
        await waitUntil { presentation.currentIndex == 1 }

        XCTAssertEqual(presentation.currentIndex, 1)
        presentation.stopAutoAdvance()
    }

    @MainActor
    func testRotationPausesWhileAnActionIsFocused() {
        let presentation = HeroPresentation(pages: makePages(3))

        presentation.setActionFocused(true)
        presentation.handleAutoAdvanceTick()
        XCTAssertEqual(presentation.currentIndex, 0)

        presentation.setActionFocused(false)
        presentation.handleAutoAdvanceTick()
        XCTAssertEqual(presentation.currentIndex, 1)
    }

    @MainActor
    func testRotationPausesUnderReduceMotion() {
        let presentation = HeroPresentation(pages: makePages(3))

        presentation.setReduceMotion(true)
        presentation.handleAutoAdvanceTick()
        XCTAssertEqual(presentation.currentIndex, 0)

        presentation.setReduceMotion(false)
        presentation.handleAutoAdvanceTick()
        XCTAssertEqual(presentation.currentIndex, 1)
    }

    @MainActor
    func testOverridePagePreviewsFocusedItemAndPausesRotation() {
        let presentation = HeroPresentation(pages: makePages(3))
        let override = HeroItem(id: "rail:99", title: "Focused Rail Item")

        presentation.displayOverride(override)
        XCTAssertEqual(presentation.currentPage?.id, "rail:99")
        XCTAssertTrue(presentation.isDisplayingOverride)
        XCTAssertTrue(presentation.isAutoAdvancePaused)

        presentation.handleAutoAdvanceTick()
        XCTAssertEqual(presentation.currentIndex, 0)

        presentation.displayOverride(nil)
        XCTAssertFalse(presentation.isDisplayingOverride)
        XCTAssertEqual(presentation.currentPage?.id, "hero:0")
        XCTAssertFalse(presentation.isAutoAdvancePaused)
    }

    @MainActor
    func testRotationWrapsAroundAndRetreatWrapsBackward() {
        let presentation = HeroPresentation(pages: makePages(3), currentIndex: 2)

        presentation.advance()
        XCTAssertEqual(presentation.currentIndex, 0)

        presentation.retreat()
        XCTAssertEqual(presentation.currentIndex, 2)
    }

    func testRuntimeFormatting() {
        XCTAssertEqual(HeroFormatting.runtime(minutes: 119), "1h 59m")
        XCTAssertEqual(HeroFormatting.runtime(minutes: 60), "1h")
        XCTAssertEqual(HeroFormatting.runtime(minutes: 42), "42m")
        XCTAssertNil(HeroFormatting.runtime(minutes: 0))
        XCTAssertNil(HeroFormatting.runtime(minutes: nil))
    }

    func testCanonicalBadgeFormattingAndDeduplication() {
        let item = HeroItem(
            id: "movie:1",
            title: "Example",
            year: " 2026 ",
            runtimeMinutes: 119,
            classification: "PG-13",
            badges: ["4K", "pg-13", " "]
        )

        XCTAssertEqual(item.canonicalBadges, ["2026", "1h 59m", "PG-13", "4K"])
    }

    @MainActor
    func testDefaultAutoAdvanceIntervalMatchesAndroidTenSeconds() {
        XCTAssertEqual(HeroPresentation(pages: makePages(2)).autoAdvanceInterval, .seconds(10))
    }

    func testPageIndicatorCountAndIndexMath() {
        let wrapped = HeroPageIndicatorState(pageCount: 4, currentIndex: 5)
        XCTAssertEqual(wrapped.count, 4)
        XCTAssertEqual(wrapped.activeIndex, 1)
        XCTAssertTrue(wrapped.isActive(1))
        XCTAssertFalse(wrapped.isActive(0))

        XCTAssertEqual(
            HeroPageIndicatorState.normalizedIndex(-1, pageCount: 4),
            3
        )
        XCTAssertEqual(
            HeroPageIndicatorState.normalizedIndex(8, pageCount: 0),
            0
        )
    }

    func testHeroItemIdentityRemainsStableAcrossContentChanges() {
        let original = HeroItem(id: "catalog:42", title: "Original")
        let enriched = HeroItem(
            id: "catalog:42",
            title: "Localized title",
            titleLogoURL: "https://example.com/logo.png",
            backdropURL: "https://example.com/backdrop.jpg"
        )

        XCTAssertEqual(original.id, enriched.id)
        XCTAssertEqual(Set([original.id, enriched.id]).count, 1)
        XCTAssertNotEqual(original, enriched)
    }

    private func makePages(_ count: Int) -> [HeroItem] {
        (0..<count).map { HeroItem(id: "hero:\($0)", title: "Hero \($0)") }
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}

private actor ManualHeroClock {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private var waiters: [Waiter] = []

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    func waitUntilScheduled() async {
        while waiters.isEmpty {
            await Task.yield()
        }
    }

    func advance() {
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().continuation.resume()
    }

    private func cancel(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
