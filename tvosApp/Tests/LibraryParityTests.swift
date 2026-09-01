import XCTest
@testable import NuvioTV

final class LibraryParityTests: XCTestCase {
    // MARK: Fixtures

    private func makeItem(
        _ id: String,
        type: String,
        name: String,
        metadataBaseURL: String? = nil
    ) -> MetaSummary {
        MetaSummary(
            id: id,
            type: type,
            name: name,
            metadataBaseURL: metadataBaseURL
        )
    }

    /// Mixed library: two movies, two series, mixed providers, article-led titles.
    private var library: [MetaSummary] {
        [
            makeItem("m1", type: "movie", name: "The Banana", metadataBaseURL: "https://cinemeta.strem.io/manifest.json"),
            makeItem("m2", type: "movie", name: "Apple"),
            makeItem("s1", type: "series", name: "Cherry", metadataBaseURL: "https://example.com/manifest.json"),
            makeItem("s2", type: "series", name: "the Durian"),
        ]
    }

    private var watchedKeys: Set<String> {
        ["movie:m1", "series:s1"]
    }

    // MARK: Type tab filtering

    func testTypeTabFiltering() {
        let presentation = LibraryPresentation(items: library, watchedKeys: watchedKeys)

        // Facet counts are built from the full item list, All first.
        XCTAssertEqual(presentation.typeTabs.map(\.key), [LibraryTypeTab.allKey, "movie", "series"])
        XCTAssertEqual(presentation.typeTabs[0].count, 4)
        XCTAssertEqual(presentation.typeTabs[0].label, "All (4)")
        XCTAssertEqual(presentation.typeTabs[1].label, "Movie (2)")
        XCTAssertEqual(presentation.typeTabs[2].label, "Series (2)")

        // All tab (default) keeps every item.
        XCTAssertEqual(Set(presentation.visibleItems.map(\.id)), ["m1", "m2", "s1", "s2"])

        var movies = presentation
        movies.selectedTypeTabKey = "movie"
        XCTAssertEqual(movies.visibleItems.map(\.id), ["m1", "m2"])

        var series = presentation
        series.selectedTypeTabKey = "series"
        XCTAssertEqual(series.visibleItems.map(\.id), ["s1", "s2"])

        // Type keys normalize case and surrounding whitespace.
        var normalized = presentation
        normalized.selectedTypeTabKey = "  Movie "
        XCTAssertEqual(normalized.visibleItems.map(\.id), ["m1", "m2"])
    }

    func testTypeTabOrderingAndLabels() {
        let items = [
            makeItem("c1", type: "collection", name: "Folder"),
            makeItem("a1", type: "anime", name: "Anime"),
            makeItem("s1", type: "series", name: "Show"),
            makeItem("m1", type: "movie", name: "Film"),
            makeItem("m2", type: "Movie", name: "Film 2"),
        ]
        let presentation = LibraryPresentation(items: items)
        // Canonical order (movie, series, tv, show, anime) then alphabetical.
        XCTAssertEqual(
            presentation.typeTabs.map(\.key),
            [LibraryTypeTab.allKey, "movie", "series", "anime", "collection"]
        )
        XCTAssertEqual(presentation.typeTabs[1].count, 2)

        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: "__all__"), "All")
        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: "movie"), "Movie")
        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: "series"), "Series")
        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: "tv"), "TV")
        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: "collection"), "Collection")
        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: "some_type"), "Some Type")
        XCTAssertEqual(LibraryTypeTab.localizedLabel(forKey: ""), "Unknown")
    }

    // MARK: Watched filter

    func testWatchedFilterCombinations() {
        var presentation = LibraryPresentation(items: library, watchedKeys: watchedKeys)

        presentation.watchedFilter = .all
        XCTAssertEqual(Set(presentation.visibleItems.map(\.id)), ["m1", "m2", "s1", "s2"])

        presentation.watchedFilter = .watched
        XCTAssertEqual(Set(presentation.visibleItems.map(\.id)), ["m1", "s1"])
        XCTAssertTrue(presentation.isWatched(library[0]))
        XCTAssertTrue(presentation.isWatched(library[2]))
        XCTAssertFalse(presentation.isWatched(library[1]))
        XCTAssertFalse(presentation.isWatched(library[3]))

        presentation.watchedFilter = .unwatched
        XCTAssertEqual(Set(presentation.visibleItems.map(\.id)), ["m2", "s2"])

        // Combined with a type tab: watched series only.
        presentation.watchedFilter = .watched
        presentation.selectedTypeTabKey = "series"
        XCTAssertEqual(presentation.visibleItems.map(\.id), ["s1"])
    }

    func testWatchedKeyNormalization() {
        // Watched keys match on normalized "type:id", so mixed-case types
        // in the item data still hit the same key as the watch progress store.
        let items = [makeItem("k1", type: " Movie ", name: "Odd Type")]
        let presentation = LibraryPresentation(items: items, watchedKeys: ["movie:k1"])
        XCTAssertEqual(items[0].libraryIdentityKey, "movie:k1")
        XCTAssertTrue(presentation.isWatched(items[0]))
    }

    // MARK: Sort options

    func testEverySortOptionOrdering() {
        // Input order: m1, m2, s1, s2 (index 0 treated as most recently added).
        for option in LibrarySortOption.allCases {
            let sorted = LibraryPresentation.sorted(library, by: option)
            XCTAssertEqual(Set(sorted.map(\.id)), Set(library.map(\.id)), "option \(option.rawValue)")
        }

        // Provider order and added-desc keep the source order.
        XCTAssertEqual(
            LibraryPresentation.sorted(library, by: .providerOrder).map(\.id),
            ["m1", "m2", "s1", "s2"]
        )
        XCTAssertEqual(
            LibraryPresentation.sorted(library, by: .addedDesc).map(\.id),
            ["m1", "m2", "s1", "s2"]
        )

        // Added asc reverses the array.
        XCTAssertEqual(
            LibraryPresentation.sorted(library, by: .addedAsc).map(\.id),
            ["s2", "s1", "m2", "m1"]
        )

        // Title sorts strip leading articles: Apple, Banana, Cherry, Durian.
        XCTAssertEqual(
            LibraryPresentation.sorted(library, by: .titleAsc).map(\.id),
            ["m2", "m1", "s1", "s2"]
        )
        XCTAssertEqual(
            LibraryPresentation.sorted(library, by: .titleDesc).map(\.id),
            ["s2", "s1", "m1", "m2"]
        )
    }

    func testTitleSortTiebreaksAndFallbacks() {
        // Equal titles tiebreak on id ascending in both directions.
        let tied = [
            makeItem("b", type: "movie", name: "Same"),
            makeItem("a", type: "movie", name: "Same"),
        ]
        XCTAssertEqual(LibraryPresentation.sorted(tied, by: .titleAsc).map(\.id), ["a", "b"])
        XCTAssertEqual(LibraryPresentation.sorted(tied, by: .titleDesc).map(\.id), ["a", "b"])

        // Blank names fall back to the id as the sort title.
        let blank = [
            makeItem("zeta", type: "movie", name: "   "),
            makeItem("beta", type: "movie", name: "Beta"),
        ]
        XCTAssertEqual(LibraryPresentation.sorted(blank, by: .titleAsc).map(\.id), ["beta", "zeta"])

        // Article stripping only removes one leading article with a space.
        XCTAssertEqual(LibraryPresentation.titleSortKey(for: "The Walking Dead"), "walking dead")
        XCTAssertEqual(LibraryPresentation.titleSortKey(for: "An Ocean"), "ocean")
        XCTAssertEqual(LibraryPresentation.titleSortKey(for: "A Rocket"), "rocket")
        XCTAssertEqual(LibraryPresentation.titleSortKey(for: "Another Life"), "another life")
        XCTAssertEqual(LibraryPresentation.titleSortKey(for: "A"), "a")
        XCTAssertEqual(LibraryPresentation.titleSortKey(for: "  THE BATMAN  "), "batman")

        // Offered list matches Android's LocalOptions.
        XCTAssertEqual(
            LibraryPresentation(items: []).sortOptions,
            [.addedDesc, .addedAsc, .titleAsc, .titleDesc]
        )
    }

    // MARK: Free-text filter

    func testFreeTextMatchingIsLocalAndCaseInsensitive() {
        var presentation = LibraryPresentation(items: library)

        presentation.query = "BAN"
        XCTAssertEqual(presentation.visibleItems.map(\.id), ["m1"])

        // Query is trimmed before matching.
        presentation.query = "  the  "
        XCTAssertEqual(Set(presentation.visibleItems.map(\.id)), ["m1", "s2"])

        // Empty query keeps everything.
        presentation.query = ""
        XCTAssertEqual(presentation.visibleItems.count, 4)

        // No match empties the grid (and never hits the network: the filter
        // runs over the already-loaded items).
        presentation.query = "zzz"
        XCTAssertTrue(presentation.visibleItems.isEmpty)

        // Combines with the type tab.
        presentation.query = "ban"
        presentation.selectedTypeTabKey = "series"
        XCTAssertTrue(presentation.visibleItems.isEmpty)
        presentation.selectedTypeTabKey = "movie"
        XCTAssertEqual(presentation.visibleItems.map(\.id), ["m1"])
    }

    // MARK: sortSelectionVersion

    func testSortSelectionVersionIncrementsOnlyOnChange() {
        var presentation = LibraryPresentation(items: library)
        XCTAssertEqual(presentation.sortSelectionVersion, 0)
        XCTAssertEqual(presentation.sortOption, .addedDesc)

        // Re-selecting the current option does not bump.
        presentation.select(sortOption: .addedDesc)
        XCTAssertEqual(presentation.sortSelectionVersion, 0)

        presentation.select(sortOption: .titleAsc)
        XCTAssertEqual(presentation.sortSelectionVersion, 1)
        XCTAssertEqual(presentation.sortOption, .titleAsc)

        presentation.select(sortOption: .titleAsc)
        XCTAssertEqual(presentation.sortSelectionVersion, 1)

        presentation.select(sortOption: .titleDesc)
        XCTAssertEqual(presentation.sortSelectionVersion, 2)
    }

    // MARK: Empty-state rules

    func testEmptyStateRules() {
        // Visible items: no empty state.
        XCTAssertNil(LibraryPresentation(items: library, watchedKeys: watchedKeys).emptyState)

        // Truly empty library, saved mode.
        let savedEmpty = LibraryPresentation(items: []).emptyState
        XCTAssertEqual(savedEmpty?.kind, .noItems)
        XCTAssertEqual(savedEmpty?.viewMode, .saved)
        XCTAssertEqual(savedEmpty?.title, "No items yet")
        XCTAssertEqual(savedEmpty?.subtitle, "Start saving your favorites to see them here")

        // Truly empty library, cloud mode.
        let cloudEmpty = LibraryPresentation(items: [], viewMode: .cloud).emptyState
        XCTAssertEqual(cloudEmpty?.kind, .noItems)
        XCTAssertEqual(cloudEmpty?.viewMode, .cloud)
        XCTAssertEqual(cloudEmpty?.title, "Nothing here yet")
        XCTAssertEqual(cloudEmpty?.subtitle, "No playable cloud files match the current filters.")

        // Filters narrowing to zero, saved mode with All tab.
        let allFiltered = LibraryPresentation(items: library, watchedFilter: .unwatched, query: "zzz").emptyState
        XCTAssertEqual(allFiltered?.kind, .noMatches)
        XCTAssertEqual(allFiltered?.viewMode, .saved)
        XCTAssertEqual(allFiltered?.title, "No items yet")

        // Filters narrowing to zero, saved mode with a type tab selected.
        let movieFiltered = LibraryPresentation(items: library, selectedTypeTabKey: "movie", query: "zzz").emptyState
        XCTAssertEqual(movieFiltered?.kind, .noMatches)
        XCTAssertEqual(movieFiltered?.title, "No movie yet")

        // A tab whose type has no items at all also reports noMatches.
        let seriesOnly = [makeItem("s1", type: "series", name: "Only Series")]
        let missingType = LibraryPresentation(items: seriesOnly, selectedTypeTabKey: "movie").emptyState
        XCTAssertEqual(missingType?.kind, .noMatches)
        XCTAssertEqual(missingType?.title, "No movie yet")

        // Filters narrowing to zero, cloud mode.
        let cloudFiltered = LibraryPresentation(items: library, viewMode: .cloud, query: "zzz").emptyState
        XCTAssertEqual(cloudFiltered?.kind, .noMatches)
        XCTAssertEqual(cloudFiltered?.title, "Nothing here yet")
        XCTAssertEqual(cloudFiltered?.subtitle, "No playable cloud files match the current filters.")
    }

    // MARK: Provider filter

    func testProviderFilteringAndOptions() {
        let presentation = LibraryPresentation(items: library)

        // Options derive from the metadata addon hosts, sorted by label.
        XCTAssertEqual(presentation.providerOptions.map(\.key), ["cinemeta.strem.io", "example.com"])
        XCTAssertEqual(presentation.providerOptions.map(\.count), [1, 1])
        XCTAssertEqual(presentation.providerOptions[0].labelWithCount, "cinemeta.strem.io (1)")

        var filtered = presentation
        filtered.selectedProviderKey = "example.com"
        XCTAssertEqual(filtered.visibleItems.map(\.id), ["s1"])

        filtered.selectedProviderKey = "cinemeta.strem.io"
        XCTAssertEqual(filtered.visibleItems.map(\.id), ["m1"])

        // A stale selection resolves back to all providers.
        filtered.selectedProviderKey = "gone.example"
        XCTAssertEqual(filtered.effectiveProviderKey, nil)
        XCTAssertEqual(filtered.visibleItems.count, 4)

        // Items without a provider only appear under "All".
        let bare = [makeItem("b1", type: "movie", name: "No Provider")]
        let barePresentation = LibraryPresentation(items: bare)
        XCTAssertTrue(barePresentation.providerOptions.isEmpty)
        XCTAssertEqual(barePresentation.effectiveProviderKey, nil)
    }

    // MARK: Defaults

    func testPresentationDefaults() {
        let presentation = LibraryPresentation()
        XCTAssertEqual(presentation.viewMode, .saved)
        XCTAssertEqual(presentation.selectedTypeTabKey, LibraryTypeTab.allKey)
        XCTAssertNil(presentation.selectedProviderKey)
        XCTAssertEqual(presentation.watchedFilter, .all)
        XCTAssertEqual(presentation.sortOption, .addedDesc)
        XCTAssertEqual(presentation.query, "")
        XCTAssertEqual(presentation.sortSelectionVersion, 0)
        XCTAssertTrue(presentation.visibleItems.isEmpty)

        XCTAssertEqual(LibraryViewMode.saved.label, "Saved")
        XCTAssertEqual(LibraryViewMode.cloud.label, "Cloud")
        XCTAssertEqual(LibraryViewMode.saved.sourceLabel, "LOCAL")
        XCTAssertEqual(LibraryViewMode.cloud.sourceLabel, "CLOUD")
        XCTAssertEqual(LibraryWatchedFilter.watched.label, "Watched")
        XCTAssertEqual(LibrarySortOption.titleAsc.label, "Title A-Z")
    }
}
