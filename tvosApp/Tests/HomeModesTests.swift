import XCTest
@testable import NuvioTV

final class HomeModesTests: XCTestCase {
    // MARK: - Fixtures

    private func summary(
        _ rawID: String,
        type: String = "movie",
        name: String? = nil,
        poster: String? = nil,
        background: String? = nil
    ) -> MetaSummary {
        MetaSummary(
            id: rawID, type: type, name: name ?? "Item \(rawID)",
            poster: poster, background: background
        )
    }

    private func section(
        id: String,
        catalogName: String = "Popular",
        type: String = "movie",
        items: [MetaSummary],
        nextSkip: Int? = nil
    ) -> HomeCatalogSection {
        HomeCatalogSection(
            definition: HomeCatalogDefinition(
                addonBaseURL: "https://example.test/manifest.json",
                addonID: "example",
                addonName: "Example",
                type: type,
                catalogID: id,
                catalogName: catalogName,
                supportsPagination: true
            ),
            items: items,
            nextSkip: nextSkip
        )
    }

    private func card(_ rawID: String, isUpcoming: Bool = false) -> ContinueWatchingCard {
        ContinueWatchingCard(
            id: "card-\(rawID)", summary: summary(rawID, type: "series"),
            videoID: "v\(rawID)", season: 1, episode: 2, episodeTitle: "Pilot",
            episodeThumbnail: "https://example.test/ep-\(rawID).jpg", released: nil,
            positionMilliseconds: 100, durationMilliseconds: 200,
            lastWatchedMilliseconds: 1000, isUpcoming: isUpcoming
        )
    }

    private func makeCollection(id: String, folderIDs: [String]) throws -> TVCollection {
        let folders = folderIDs.map { folderID in
            [
                "id": folderID,
                "title": "Folder \(folderID)",
                "tileShape": "poster",
                "hideTitle": false,
            ] as [String: Any]
        }
        let json: [String: Any] = ["id": id, "title": "Collection \(id)", "folders": folders]
        return try JSONDecoder().decode(
            TVCollection.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
    }

    // MARK: - Classic mapping

    func testClassicHeroSelectionUsesHeroSlotsOnly() {
        let hero = summary("hero", background: "https://example.test/h.jpg")
        let snapshot = HomeSnapshot(
            heroItems: [hero],
            sections: [section(id: "popular", items: [summary("rail-only")])]
        )
        let presentation = ClassicHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )
        XCTAssertEqual(presentation.heroes.map(\.id), ["movie:hero"])
        XCTAssertEqual(presentation.heroes[0].backdropURL, "https://example.test/h.jpg")
        XCTAssertFalse(
            presentation.heroes.contains { $0.id == "movie:rail-only" },
            "Classic must not synthesize hero pages from rail items"
        )
    }

    func testClassicRowOrderPlacesPersonalRowsBeforeCatalogs() throws {
        let collection = try makeCollection(id: "c1", folderIDs: ["f1", "f2"])
        let snapshot = HomeSnapshot(
            heroItems: [summary("hero")],
            sections: [section(id: "popular", items: [summary("tt1")])],
            continueWatching: [card("cw")],
            upcoming: [card("up", isUpcoming: true)],
            collections: [collection]
        )
        let presentation = ClassicHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )
        XCTAssertEqual(
            presentation.rows.map(\.id),
            ["continue_watching", "upcoming_section", "collection_c1", "example:movie:popular"]
        )
    }

    func testClassicMappingAppliesPreferencesAndWatchedState() {
        var preferences = HomePreferences()
        preferences.items = [
            HomeCatalogPreference(
                key: "example:movie:popular",
                enabled: true,
                order: 0,
                customTitle: "Featured Picks"
            )
        ]
        let snapshot = HomeSnapshot(
            sections: [section(id: "popular", items: [summary("watched"), summary("fresh")])],
            watchedContentKeys: ["movie:watched"]
        )
        let presentation = ClassicHomePresentation.build(
            snapshot: snapshot,
            preferences: preferences
        )
        guard case .catalog(let rail) = presentation.rows.first else {
            return XCTFail("Expected a catalog row")
        }
        XCTAssertEqual(rail.title, "Featured Picks")
        XCTAssertTrue(rail.items[0].status.isWatched)
        XCTAssertFalse(rail.items[1].status.isWatched)
        XCTAssertEqual(
            presentation.summary(for: rail.items[0])?.id,
            "watched",
            "Rail items must route back to their MetaSummary"
        )
    }

    func testClassicEmptySnapshotProducesNoHeroesOrRows() {
        let presentation = ClassicHomePresentation.build(
            snapshot: HomeSnapshot(),
            preferences: HomePreferences()
        )
        XCTAssertTrue(presentation.heroes.isEmpty)
        XCTAssertTrue(presentation.rows.isEmpty)
        XCTAssertTrue(presentation.sectionsByID.isEmpty)
    }

    func testClassicFocusArtworkFallbackChains() {
        XCTAssertEqual(
            ClassicFocusArtwork(
                summary: summary("tt1", poster: "p", background: "b"),
                prefersBackdrop: true
            ).imageURL,
            "b"
        )
        XCTAssertEqual(
            ClassicFocusArtwork(
                summary: summary("tt1", poster: "p", background: "b"),
                prefersBackdrop: false
            ).imageURL,
            "p"
        )
        XCTAssertEqual(
            ClassicFocusArtwork(card: card("cw"), prefersBackdrop: true).imageURL,
            "https://example.test/ep-cw.jpg"
        )
        XCTAssertEqual(
            ClassicFocusArtwork(
                summary: summary("tt1", poster: "p", background: "b"),
                prefersBackdrop: true
            ).seed,
            "tt1|Item tt1|movie"
        )
    }

    // MARK: - Classic focus gradient rules

    func testJavaHashCodeAndHueMatchAndroid() {
        XCTAssertEqual(ClassicRGBMath.javaHashCode("a"), 97)
        XCTAssertEqual(ClassicRGBMath.javaHashCode("abc"), 96354)
        XCTAssertEqual(ClassicRGBMath.hueDegrees(fromSeed: "abc"), 234)
        XCTAssertEqual(ClassicRGBMath.hueDegrees(fromSeed: "a"), 97)
    }

    func testSeedColorIsStableAndReadable() {
        let seed = "abc"
        let expected = ClassicFocusGradient.defaultFallback
            .blended(
                with: ClassicRGBMath.rgb(hueDegrees: 234, saturation: 0.58, value: 0.82),
                fraction: 0.58
            )
            .stabilized
        XCTAssertEqual(ClassicFocusGradient.seedColor(seed: seed), expected)
        XCTAssertEqual(
            ClassicFocusGradient.seedColor(seed: seed),
            ClassicFocusGradient.seedColor(seed: seed)
        )
        // Extreme inputs are pulled back into the readable luminance band.
        XCTAssertGreaterThan(ClassicRGB(red: 0, green: 0, blue: 0).stabilized.luminance, 0.09)
        XCTAssertLessThan(ClassicRGB(red: 1, green: 1, blue: 1).stabilized.luminance, 0.75)
        // Blank seeds fall back to the theme color.
        XCTAssertEqual(
            ClassicFocusGradient.seedColor(seed: "  "),
            ClassicFocusGradient.defaultFallback.stabilized
        )
    }

    func testGradientStopsVisibilityRuleAndScaleTokens() {
        XCTAssertEqual(ClassicFocusGradient.stops.map(\.location), [0, 0.42, 0.66, 0.84, 1])
        XCTAssertEqual(ClassicFocusGradient.stops.map(\.alpha), [0, 0, 0.16, 0.30, 0.44])
        XCTAssertTrue(ClassicFocusGradient.isBackdropVisible(immersiveAlpha: 0))
        XCTAssertFalse(ClassicFocusGradient.isBackdropVisible(immersiveAlpha: 0.01))
        XCTAssertFalse(ClassicFocusGradient.isBackdropVisible(immersiveAlpha: 1))
        XCTAssertEqual(ClassicHomeScale.catalogPosterScale, 1.35)
        XCTAssertEqual(ClassicHomeScale.secondaryRowPosterScale, 1.2)
        XCTAssertEqual(ClassicHomeScale.catalogPosterSize.width, 170.1, accuracy: 0.001)
        XCTAssertEqual(ClassicHomeScale.catalogPosterSize.height, 255.15, accuracy: 0.001)
        XCTAssertEqual(ClassicHomeScale.heroBandHeight, 400)
        XCTAssertEqual(ClassicHomeScale.immersiveFadeDistance, 180)
    }

    // MARK: - Grid mapping

    func testGridSectionTitlesFollowTypeSuffixRule() {
        XCTAssertEqual(
            GridHomePresentation.sectionTitle(catalogName: "popular", type: "movie", showsTypeSuffix: true),
            "Popular - Movie"
        )
        XCTAssertEqual(
            GridHomePresentation.sectionTitle(catalogName: "top series", type: "series", showsTypeSuffix: true),
            "Top series - Series"
        )
        XCTAssertEqual(
            GridHomePresentation.sectionTitle(catalogName: "popular", type: "movie", showsTypeSuffix: false),
            "Popular"
        )
        XCTAssertEqual(GridHomePresentation.typeLabel("anime"), "Anime")
    }
    func testGridPagingMath() {
        XCTAssertEqual(GridHomeGeometry.rowsPerSection(posterWidth: 126), 3)
        XCTAssertEqual(GridHomeGeometry.rowsPerSection(posterWidth: 104), 2)
        XCTAssertEqual(GridHomeGeometry.rowsPerSection(posterWidth: 100), 2)
        XCTAssertEqual(GridHomeGeometry.maxDisplaySlots(posterWidth: 126), 24)
        XCTAssertEqual(GridHomeGeometry.maxDisplaySlots(posterWidth: 104), 16)
        XCTAssertEqual(GridHomeGeometry.columns(containerWidth: 1920), 13)
        XCTAssertEqual(GridHomeGeometry.columns(containerWidth: 960), 6)
        XCTAssertEqual(GridHomeGeometry.columns(containerWidth: 100), 1)
    }

    func testGridTrimKeepsSeeAllOffLonelyRows() {
        // (content, seeAll, columns, rows, expected)
        let cases: [(Int, Bool, Int, Int, Int)] = [
            (4, true, 4, 2, 3), // 4 cards + See All on 4 columns leaves See All alone: drop one
            (7, true, 4, 2, 7), // aligned case keeps everything
            (24, true, 6, 3, 17), // capped at columns * rows - 1
            (9, false, 6, 3, 9), // no See All: page fits
            (30, true, 1, 3, 30), // single-column layouts are not trimmed
        ]
        for (count, seeAll, columns, rows, expected) in cases {
            XCTAssertEqual(
                GridHomeGeometry.trimmedContentCount(
                    contentCount: count,
                    showsSeeAll: seeAll,
                    columns: columns,
                    rowsPerSection: rows
                ),
                expected
            )
        }
    }

    func testGridBuildCapsSectionsAndAddsSeeAll() {
        let many = (0..<30).map { summary("tt\($0)") }
        let few = (0..<10).map { summary("s\($0)", type: "series") }
        var preferences = HomePreferences()
        preferences.showCatalogType = true
        let snapshot = HomeSnapshot(
            heroItems: [summary("hero")],
            sections: [
                section(id: "popular", items: many),
                section(id: "airing", catalogName: "airing", type: "series", items: few, nextSkip: 10),
            ],
            continueWatching: [card("cw")],
            upcoming: [card("up", isUpcoming: true)]
        )
        let presentation = GridHomePresentation.build(
            snapshot: snapshot,
            preferences: preferences
        )
        XCTAssertEqual(presentation.heroes.map(\.id), ["movie:hero"])
        XCTAssertEqual(presentation.sections.count, 2)

        let popular = presentation.sections[0]
        XCTAssertEqual(popular.headerTitle, "Popular - Movie")
        XCTAssertTrue(popular.hasSeeAll, "30 items exceed the 24-slot page")
        XCTAssertEqual(popular.contentItems.count, 23, "23 content cards plus See All = 24 slots")

        let airing = presentation.sections[1]
        XCTAssertEqual(airing.headerTitle, "Airing - Series")
        XCTAssertTrue(airing.hasSeeAll, "A next-page cursor forces See All")
        XCTAssertEqual(airing.contentItems.count, 10)

        let visible = presentation.visibleItems(in: popular, columns: 6)
        XCTAssertEqual(visible.count, 18, "6 columns x 3 rows minus the See All slot")
        XCTAssertEqual(visible.last, .seeAll(sectionID: popular.id))
        XCTAssertEqual(presentation.summary(for: visible[0])?.id, "tt0")
        XCTAssertEqual(presentation.continueWatching.map(\.id), ["card-cw"])
        XCTAssertEqual(presentation.upcoming.map(\.id), ["card-up"])
    }

    func testGridSectionWithoutSeeAllWhenPageFits() {
        let items = (0..<24).map { summary("tt\($0)") }
        let snapshot = HomeSnapshot(sections: [section(id: "popular", items: items)])
        var preferences = HomePreferences()
        preferences.showCatalogType = false
        let presentation = GridHomePresentation.build(
            snapshot: snapshot,
            preferences: preferences
        )
        XCTAssertEqual(presentation.sections.count, 1)
        XCTAssertFalse(presentation.sections[0].hasSeeAll)
        XCTAssertEqual(presentation.sections[0].contentItems.count, 24)
        XCTAssertEqual(presentation.sections[0].headerTitle, "Popular")
    }

    func testGridCollectionsBecomeSections() throws {
        let collection = try makeCollection(id: "c1", folderIDs: ["f1", "f2"])
        let snapshot = HomeSnapshot(collections: [collection])
        let presentation = GridHomePresentation.build(
            snapshot: snapshot,
            preferences: HomePreferences()
        )
        XCTAssertEqual(presentation.sections.map(\.id), ["collection_c1"])
        XCTAssertEqual(presentation.sections[0].isCollection, true)
        XCTAssertEqual(presentation.sections[0].folderItems.count, 2)
        XCTAssertEqual(presentation.collections, [collection])
        let visible = presentation.visibleItems(in: presentation.sections[0], columns: 6)
        XCTAssertEqual(visible.count, 2)
        XCTAssertEqual(visible[0].id, "col_folder_c1_f1")
    }

    func testGridEmptySnapshotHasNoSectionsAndNoHeaderTitle() {
        let presentation = GridHomePresentation.build(
            snapshot: HomeSnapshot(),
            preferences: HomePreferences()
        )
        XCTAssertTrue(presentation.heroes.isEmpty)
        XCTAssertTrue(presentation.sections.isEmpty)
        XCTAssertTrue(presentation.continueWatching.isEmpty)
        XCTAssertTrue(presentation.upcoming.isEmpty)
        XCTAssertNil(presentation.sectionMapping().title(forItemIndex: 0))
    }

    func testGridSectionMappingFindsStickyHeader() {
        let items = (0..<6).map { summary("tt\($0)") }
        let snapshot = HomeSnapshot(
            heroItems: [summary("hero")],
            sections: [
                section(id: "popular", catalogName: "Popular", items: items),
                section(id: "top", catalogName: "Top", items: Array(items.prefix(3))),
            ],
            continueWatching: [card("cw")]
        )
        let presentation = GridHomePresentation.build(
            snapshot: snapshot,
            preferences: { var p = HomePreferences(); p.showCatalogType = false; return p }()
        )
        let mapping = presentation.sectionMapping()
        // Slot 0 = hero, slot 1 = continue watching, slot 2 = Popular header.
        XCTAssertEqual(mapping.title(forItemIndex: 2), "Popular")
        XCTAssertEqual(mapping.title(forItemIndex: 7), "Popular", "Last Popular card")
        // Slot 9 = Top header (1 + 1 + 1 + 6 + 1).
        XCTAssertEqual(mapping.title(forItemIndex: 9), "Top")
        XCTAssertEqual(mapping.title(forItemIndex: 12), "Top")
        XCTAssertNil(mapping.title(forItemIndex: 0), "Before the first divider")
        XCTAssertNil(mapping.title(forItemIndex: 1))
    }

    // MARK: - Layout switch

    func testLayoutSwitchResolvesSettings() {
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "modern"), .modern)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "classic"), .classic)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "grid"), .grid)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "Grid View"), .grid)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "Classic View"), .classic)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "unknown"), .modern)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: nil), .modern)
        XCTAssertEqual(HomeLayoutSwitch.mode(forSetting: "  "), .modern)
        XCTAssertEqual(HomeLayoutMode.defaultMode, .modern)
        XCTAssertEqual(
            HomeLayoutMode.allCases.map(\.displayName),
            ["Modern View", "Classic View", "Grid View"]
        )
    }
}
