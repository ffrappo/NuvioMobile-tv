import XCTest
@testable import NuvioTV

final class SearchParityTests: XCTestCase {
    // MARK: - Section building for mixed providers

    func testBuildProducesSectionsPerProviderAndDropsEmptyProviders() {
        let loaded = provider(addonName: "A Addon", catalogName: "popular", type: "movie", items: [
            meta(id: "tt1", name: "One"),
            meta(id: "tt2", name: "Two")
        ])
        let empty = provider(addonName: "B Addon", catalogName: "top", type: "series", items: [])
        let stillLoading = provider(
            addonName: "C Addon",
            catalogName: "trending",
            type: "movie",
            items: [],
            state: .loading
        )

        let presentation = SearchPresentation.build(
            query: "matrix",
            submittedQuery: "matrix",
            isSearching: true,
            errorMessage: nil,
            providerResults: [loaded, empty, stillLoading],
            recentSearches: []
        )

        // Empty provider is dropped, order preserved, loading provider stays visible.
        XCTAssertEqual(presentation.sections.count, 2)
        XCTAssertEqual(presentation.sections[0].providerName, "A Addon")
        XCTAssertEqual(presentation.sections[0].title, "Popular - Movie")
        XCTAssertEqual(presentation.sections[0].items.map(\.title), ["One", "Two"])
        XCTAssertTrue(presentation.sections[1].isLoading)
        XCTAssertEqual(presentation.sections[1].title, "Trending - Movie")

        guard case let .results(sections, isLoadingMore, notice) = presentation.phase else {
            return XCTFail("expected results phase, got \(presentation.phase)")
        }
        XCTAssertEqual(sections.map(\.providerName), ["A Addon", "C Addon"])
        XCTAssertTrue(isLoadingMore, "providers still answering must keep the trailing loading rail")
        XCTAssertNil(notice)
    }

    func testSectionTitleSkipsTypeSuffixWhenDisabledAndOmitsSeeAllForSmallRows() {
        let small = provider(catalogName: "found", items: Array(repeating: meta(id: "x", name: "X"), count: 14))
        let presentation = SearchPresentation.build(
            query: "query",
            submittedQuery: "query",
            isSearching: false,
            errorMessage: nil,
            providerResults: [small],
            recentSearches: [],
            showTypeSuffix: false
        )
        XCTAssertEqual(presentation.sections[0].title, "Found")
        XCTAssertFalse(presentation.sections[0].showsSeeAll, "See All needs at least 15 items")

        let big = provider(catalogName: "found", items: (0..<15).map { meta(id: "tt\($0)", name: "T\($0)") })
        let bigPresentation = SearchPresentation.build(
            query: "query",
            submittedQuery: "query",
            isSearching: false,
            errorMessage: nil,
            providerResults: [big],
            recentSearches: []
        )
        XCTAssertTrue(bigPresentation.sections[0].showsSeeAll)
    }

    func testQuerySubmissionRuleRequiresTwoCharacters() {
        XCTAssertEqual(SearchPresentation.submittedQuery(from: "  "), "")
        XCTAssertEqual(SearchPresentation.submittedQuery(from: " m "), "")
        XCTAssertEqual(SearchPresentation.submittedQuery(from: " matrix "), "matrix")
    }

    // MARK: - State rules: empty, loading, partial failure

    func testEmptyQueryWithoutHistoryShowsStartState() {
        let presentation = SearchPresentation.build(
            query: "",
            submittedQuery: "",
            isSearching: false,
            errorMessage: nil,
            providerResults: [],
            recentSearches: []
        )
        XCTAssertEqual(presentation.phase, .startEmpty(subtitle: SearchPresentationPhase.startSubtitle))
        XCTAssertFalse(presentation.showRecentSearches)
        XCTAssertTrue(presentation.isDiscoverMode)
    }

    func testEmptyQueryWithHistoryShowsRecentSearches() {
        let presentation = SearchPresentation.build(
            query: "  ",
            submittedQuery: "",
            isSearching: false,
            errorMessage: nil,
            providerResults: [],
            recentSearches: ["Dune", "Severance"]
        )
        XCTAssertEqual(presentation.phase, .recentSearches)
        XCTAssertTrue(presentation.showRecentSearches)
    }

    func testShortQueryWithDiscoverOffUsesNoDiscoverSubtitle() {
        let presentation = SearchPresentation.build(
            query: "m",
            submittedQuery: "",
            isSearching: false,
            errorMessage: nil,
            providerResults: [],
            recentSearches: [],
            discoverLocation: .off
        )
        XCTAssertEqual(
            presentation.phase,
            .startEmpty(subtitle: SearchPresentationPhase.startSubtitleNoDiscover)
        )
    }

    func testPendingQueryWithoutAnySectionsShowsSkeletons() {
        let presentation = SearchPresentation.build(
            query: "matrix reloaded",
            submittedQuery: "matrix",
            isSearching: false,
            errorMessage: nil,
            providerResults: [],
            recentSearches: []
        )
        XCTAssertTrue(presentation.hasPendingUnsubmittedQuery)
        XCTAssertEqual(presentation.phase, .skeleton(rowCount: 2))
    }

    func testSearchingWithoutAnswersShowsSkeletons() {
        let presentation = SearchPresentation.build(
            query: "matrix",
            submittedQuery: "matrix",
            isSearching: true,
            errorMessage: nil,
            providerResults: [],
            recentSearches: []
        )
        XCTAssertEqual(presentation.phase, .skeleton(rowCount: 2))
    }

    func testTotalFailureWithoutResultsShowsFailed() {
        let failed = provider(items: [], state: .failed(message: "Addon offline"))
        let presentation = SearchPresentation.build(
            query: "matrix",
            submittedQuery: "matrix",
            isSearching: false,
            errorMessage: "Addon offline",
            providerResults: [failed],
            recentSearches: []
        )
        XCTAssertEqual(presentation.phase, .failed(message: "Addon offline"))
    }

    func testNoResultsAfterSearchCompletes() {
        let presentation = SearchPresentation.build(
            query: "zzzzz",
            submittedQuery: "zzzzz",
            isSearching: false,
            errorMessage: nil,
            providerResults: [provider(items: []), provider(items: [])],
            recentSearches: []
        )
        XCTAssertEqual(presentation.phase, .noResults)
    }

    func testPartialFailureSurfacesNoticeNextToRealResults() {
        let loaded = provider(items: [meta(id: "tt1", name: "One")])
        let failed = provider(addonName: "Broken", items: [], state: .failed(message: "Broken addon"))
        let presentation = SearchPresentation.build(
            query: "matrix",
            submittedQuery: "matrix",
            isSearching: false,
            errorMessage: "Broken addon",
            providerResults: [loaded, failed],
            recentSearches: []
        )
        guard case let .results(sections, isLoadingMore, notice) = presentation.phase else {
            return XCTFail("expected results phase for partial failure, got \(presentation.phase)")
        }
        XCTAssertEqual(sections.count, 1, "failed provider must not render an empty rail")
        XCTAssertFalse(isLoadingMore)
        XCTAssertEqual(notice, "Broken addon", "partial failure keeps a non-blocking notice")
    }

    // MARK: - Recent searches: trimming, dedup, persistence

    func testRecentSearchesSaveTrimsAndDeduplicatesCaseInsensitively() {
        var history = RecentSearchHistory()
        history.save("  Matrix  ")
        history.save("dune")
        history.save("MATRIX")
        history.save("")
        history.save("   ")
        XCTAssertEqual(history.items, ["MATRIX", "dune"], "newest first, case-insensitive dedup, blanks dropped")
    }

    func testRecentSearchesCollapsePrefixSearches() {
        var history = RecentSearchHistory()
        history.save("f")
        history.save("fr")
        history.save("frieren")
        XCTAssertEqual(history.items, ["frieren"], "prefixes are collapsed into the landed query")
    }

    func testRecentSearchesCapAtMaxCount() {
        var history = RecentSearchHistory()
        for index in 0..<12 {
            history.save("query \(index)")
        }
        XCTAssertEqual(history.items.count, RecentSearchHistory.maxCount)
        XCTAssertEqual(history.items.first, "query 11")
        XCTAssertFalse(history.items.contains("query 0"))
        XCTAssertFalse(history.items.contains("query 3"))
    }

    func testRecentSearchesEncodedRoundTripAndMalformedPayload() {
        var history = RecentSearchHistory()
        history.save("Blade Runner")
        history.save("Arrival")
        let decoded = RecentSearchHistory(encoded: history.encoded)
        XCTAssertEqual(decoded.items, ["Arrival", "Blade Runner"])

        let malformed = RecentSearchHistory(encoded: "not json at all")
        XCTAssertTrue(malformed.items.isEmpty)

        let normalized = RecentSearchHistory(encoded: "[\"  spaced \",\"spaced\",\"\",\"\"]")
        XCTAssertEqual(normalized.items, ["spaced"], "payload is trimmed and deduped on parse")
    }

    func testRecentSearchesClear() {
        var history = RecentSearchHistory(items: ["a", "b"])
        history.clear()
        XCTAssertTrue(history.items.isEmpty)
    }

    // MARK: - Discover section model completeness

    func testDiscoverPresentationBuildsCompleteSectionModel() {
        let movieDescriptor = descriptor(type: "movie", catalogID: "popular", catalogName: "Popular", genres: ["Sci-Fi", "Drama"])
        let seriesDescriptor = descriptor(type: "series", catalogID: "top", catalogName: "Top Series", genres: [])
        let items = (0..<3).map { meta(id: "tt\($0)", name: "Movie \($0)") }

        let presentation = DiscoverPresentation.build(
            descriptors: [movieDescriptor, seriesDescriptor],
            selectedType: "movie",
            selectedCatalogID: movieDescriptor.id,
            selectedGenre: "Sci-Fi",
            items: items,
            canLoadMore: true,
            isLoadingMore: false,
            isInitialLoad: false
        )

        XCTAssertEqual(presentation.typeOptions.map(\.label), ["Movie", "Series"])
        XCTAssertEqual(presentation.selectedTypeValue, "movie")
        XCTAssertEqual(presentation.catalogOptions.map(\.label), ["Popular"], "catalogs must be filtered by type")
        XCTAssertEqual(presentation.selectedCatalogValue, movieDescriptor.id)
        XCTAssertEqual(presentation.genreOptions.map(\.label), ["Default", "Sci-Fi", "Drama"])
        XCTAssertEqual(presentation.selectedGenreValue, "Sci-Fi")
        XCTAssertEqual(presentation.metadataLine, "Example Addon • Movie • Sci-Fi")
        XCTAssertEqual(presentation.items.count, 3)
        XCTAssertEqual(presentation.action, .loadMore)
        XCTAssertEqual(presentation.phase, .content)
    }

    func testDiscoverActionPrioritiesMatchAndroid() {
        let movieDescriptor = descriptor(type: "movie", catalogID: "popular", catalogName: "Popular", genres: [])

        func build(pending: Int, loadingMore: Bool, canLoadMore: Bool) -> DiscoverLoadAction {
            DiscoverPresentation.build(
                descriptors: [movieDescriptor],
                selectedType: "movie",
                selectedCatalogID: movieDescriptor.id,
                selectedGenre: nil,
                items: [meta(id: "tt1", name: "One")],
                pendingItemsCount: pending,
                canLoadMore: canLoadMore,
                isLoadingMore: loadingMore,
                isInitialLoad: false
            ).action
        }

        XCTAssertEqual(build(pending: 2, loadingMore: true, canLoadMore: true), .showMore)
        XCTAssertEqual(build(pending: 0, loadingMore: true, canLoadMore: true), .loading)
        XCTAssertEqual(build(pending: 0, loadingMore: false, canLoadMore: true), .loadMore)
        XCTAssertEqual(build(pending: 0, loadingMore: false, canLoadMore: false), .none)
    }

    func testDiscoverPhaseRulesCoverAllBranches() {
        let movieDescriptor = descriptor(type: "movie", catalogID: "popular", catalogName: "Popular", genres: [])

        let loading = DiscoverPresentation.build(
            descriptors: [movieDescriptor],
            selectedType: nil,
            selectedCatalogID: movieDescriptor.id,
            selectedGenre: nil,
            items: [],
            canLoadMore: false,
            isLoadingMore: false,
            isInitialLoad: true
        )
        XCTAssertEqual(loading.phase, .loading)

        let noCatalog = DiscoverPresentation.build(
            descriptors: [],
            selectedType: nil,
            selectedCatalogID: nil,
            selectedGenre: nil,
            items: [],
            canLoadMore: false,
            isLoadingMore: false,
            isInitialLoad: false
        )
        XCTAssertEqual(noCatalog.phase, .emptyNoCatalog)

        let noContent = DiscoverPresentation.build(
            descriptors: [movieDescriptor],
            selectedType: nil,
            selectedCatalogID: movieDescriptor.id,
            selectedGenre: nil,
            items: [],
            canLoadMore: false,
            isLoadingMore: false,
            isInitialLoad: false
        )
        XCTAssertEqual(noContent.phase, .emptyNoContent)
    }

    func testDiscoverFallsBackToFirstCatalogWhenSelectionMissing() {
        let movieDescriptor = descriptor(type: "movie", catalogID: "popular", catalogName: "Popular", genres: ["Drama"])
        let presentation = DiscoverPresentation.build(
            descriptors: [movieDescriptor],
            selectedType: nil,
            selectedCatalogID: nil,
            selectedGenre: nil,
            items: [meta(id: "tt1", name: "One")],
            canLoadMore: false,
            isLoadingMore: false,
            isInitialLoad: false
        )
        XCTAssertEqual(presentation.selectedTypeValue, "movie", "Android defaults selectedDiscoverType to movie")
        XCTAssertEqual(presentation.selectedCatalogValue, movieDescriptor.id)
        XCTAssertEqual(presentation.metadataLine, "Example Addon • Movie")
    }

    // MARK: - Fixtures

    private func meta(id: String, name: String, poster: String? = "https://example.test/p.jpg") -> MetaSummary {
        MetaSummary(id: id, type: "movie", name: name, poster: poster)
    }

    private func provider(
        addonName: String = "Example Addon",
        catalogName: String = "popular",
        type: String = "movie",
        items: [MetaSummary],
        state: SearchProviderResult.State = .loaded
    ) -> SearchProviderResult {
        SearchProviderResult(
            addonID: addonName.lowercased(),
            addonName: addonName,
            addonBaseURL: "https://\(addonName.replacingOccurrences(of: " ", with: "")).test/manifest.json",
            catalogID: catalogName,
            catalogName: catalogName,
            type: type,
            items: items,
            state: state
        )
    }

    private func descriptor(
        type: String,
        catalogID: String,
        catalogName: String,
        genres: [String]
    ) -> CatalogDescriptor {
        CatalogDescriptor(
            baseURL: "https://example.test/manifest.json",
            addonID: "example",
            addonName: "Example Addon",
            type: type,
            catalogID: catalogID,
            catalogName: catalogName,
            genre: nil,
            genres: genres,
            supportsPagination: true
        )
    }
}
