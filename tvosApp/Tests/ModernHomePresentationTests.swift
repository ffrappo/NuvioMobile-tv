import XCTest
@testable import NuvioTV

final class ModernHomePresentationTests: XCTestCase {
    func testBuildMapsHeroesAndRowsWithoutLosingRoutes() {
        let first = MetaSummary(
            id: "tt1",
            type: "movie",
            name: "First",
            poster: "https://example.test/first-poster.jpg",
            background: "https://example.test/first-backdrop.jpg",
            description: "First description",
            releaseInfo: "2026",
            metadataBaseURL: "https://example.test/manifest.json",
            genres: ["Drama"]
        )
        let second = MetaSummary(id: "tt2", type: "series", name: "Second")
        let definition = HomeCatalogDefinition(
            addonBaseURL: "https://example.test/manifest.json",
            addonID: "example",
            addonName: "Example Addon",
            type: "movie",
            catalogID: "popular",
            catalogName: "Popular",
            supportsPagination: true
        )
        let section = HomeCatalogSection(definition: definition, items: [first, second])
        let snapshot = HomeSnapshot(heroItems: [first], sections: [section])
        var preferences = HomePreferences()
        preferences.items = [HomeCatalogPreference(
            key: section.id,
            enabled: true,
            order: 0,
            customTitle: "Featured Picks"
        )]

        let presentation = ModernHomePresentation.build(
            snapshot: snapshot,
            preferences: preferences
        )

        XCTAssertEqual(presentation.heroes.map(\.id), ["movie:tt1", "series:tt2"])
        XCTAssertEqual(presentation.catalogRows.count, 1)
        XCTAssertEqual(presentation.catalogRows[0].title, "Featured Picks")
        XCTAssertEqual(presentation.catalogRows[0].items.count, 2)
        XCTAssertFalse(presentation.catalogRows[0].hasMore, "Sections without a next page cursor must not offer more")
        XCTAssertEqual(presentation.summary(for: presentation.heroes[0]), first)
        XCTAssertEqual(presentation.summary(for: presentation.catalogRows[0].items[1]), second)
        XCTAssertEqual(presentation.heroPage(for: presentation.catalogRows[0].items[1])?.id, "series:tt2")
        XCTAssertEqual(presentation.sectionsByID[section.id], section)
    }

    func testBuildDeduplicatesHeroesButKeepsRepeatedRailRoutes() {
        let item = MetaSummary(id: "tt1", type: "movie", name: "First")
        let firstSection = section(id: "one", item: item)
        let secondSection = section(id: "two", item: item)
        let snapshot = HomeSnapshot(
            heroItems: [item],
            sections: [firstSection, secondSection]
        )

        let presentation = ModernHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )

        XCTAssertEqual(presentation.heroes.count, 1)
        XCTAssertEqual(presentation.catalogRows.count, 2)
        let firstRailItem = presentation.catalogRows[0].items[0]
        let secondRailItem = presentation.catalogRows[1].items[0]
        XCTAssertNotEqual(firstRailItem.id, secondRailItem.id)
        XCTAssertEqual(presentation.summary(for: firstRailItem), item)
        XCTAssertEqual(presentation.summary(for: secondRailItem), item)
    }

    func testBuildPreservesPaginatedItemsAndCapsHeroPagesAtSeven() {
        let items = (0..<24).map {
            MetaSummary(id: "tt\($0)", type: "movie", name: "Movie \($0)")
        }
        let snapshot = HomeSnapshot(
            sections: [section(id: "many", items: items, nextSkip: 24)]
        )

        let presentation = ModernHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )

        XCTAssertEqual(presentation.catalogRows[0].items.count, 24)
        XCTAssertTrue(presentation.catalogRows[0].hasMore)
        XCTAssertFalse(presentation.catalogRows[0].isLoading)
        XCTAssertEqual(presentation.heroes.count, ModernHomePresentation.heroPageLimit)
        XCTAssertEqual(
            presentation.heroes.map(\.id),
            (0..<7).map { "movie:tt\($0)" }
        )
        // Focused rail items beyond the page cap still preview on the hero.
        XCTAssertEqual(
            presentation.heroPage(for: presentation.catalogRows[0].items[10])?.id,
            "movie:tt10"
        )
    }

    func testBuildMarksWatchedItemsAndRailLoadingState() {
        let watched = MetaSummary(id: "tt1", type: "movie", name: "Watched")
        let unwatched = MetaSummary(id: "tt2", type: "movie", name: "Unwatched")
        var snapshot = HomeSnapshot(
            sections: [section(id: "one", items: [watched, unwatched])]
        )
        snapshot.watchedContentKeys = ["movie:tt1"]
        snapshot.loadingSectionIDs = ["example:movie:one"]

        let presentation = ModernHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )

        XCTAssertTrue(presentation.catalogRows[0].items[0].status.isWatched)
        XCTAssertFalse(presentation.catalogRows[0].items[1].status.isWatched)
        XCTAssertTrue(presentation.catalogRows[0].isLoading)
    }

    func testHeroPagesPreferArtworkAndBalanceAcrossSections() {
        let artworkItem = { (id: String) in
            MetaSummary(
                id: id,
                type: "movie",
                name: id,
                background: "https://example.test/\(id).jpg"
            )
        }
        let plainItem = { (id: String) in
            MetaSummary(id: id, type: "movie", name: id)
        }
        let snapshot = HomeSnapshot(
            sections: [
                section(id: "one", items: [
                    artworkItem("a1"), plainItem("p1"), artworkItem("a2"),
                ]),
                section(id: "two", items: [
                    artworkItem("b1"), plainItem("p2"), artworkItem("b2"),
                ]),
                section(id: "three", items: [
                    plainItem("p3"), artworkItem("c1"),
                ]),
            ]
        )

        let presentation = ModernHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )

        // Round-robin artwork columns first, then the plain fallback in
        // section order, capped at seven pages.
        XCTAssertEqual(
            presentation.heroes.map(\.id),
            [
                "movie:a1", "movie:b1", "movie:c1",
                "movie:a2", "movie:b2",
                "movie:p1", "movie:p2",
            ]
        )
    }

    private func section(
        id: String,
        item: MetaSummary
    ) -> HomeCatalogSection {
        section(id: id, items: [item])
    }

    private func section(
        id: String,
        items: [MetaSummary],
        nextSkip: Int? = nil
    ) -> HomeCatalogSection {
        HomeCatalogSection(
            definition: HomeCatalogDefinition(
                addonBaseURL: "https://example.test/manifest.json",
                addonID: "example",
                addonName: "Example",
                type: "movie",
                catalogID: id,
                catalogName: id.capitalized,
                supportsPagination: false
            ),
            items: items,
            nextSkip: nextSkip
        )
    }
}
