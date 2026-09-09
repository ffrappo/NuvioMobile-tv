import Foundation

/// Where Discover lives, mirroring Android `DiscoverLocation`.
public enum SearchDiscoverLocation: String, CaseIterable, Equatable, Sendable {
    case inSearch
    case inSidebar
    case off
}

/// Android parity: `MIN_SEARCH_QUERY_LENGTH` in `SearchUiState.kt`.
public let searchMinQueryLength = 2

/// Presentation-only poster item mapped from the live search store results.
public struct SearchPosterItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let year: String?
    public let type: String
    public let posterURL: URL?
    public let backdropURL: URL?

    public init(
        id: String,
        title: String,
        year: String?,
        type: String,
        posterURL: URL?,
        backdropURL: URL?
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.type = type
        self.posterURL = posterURL
        self.backdropURL = backdropURL
    }

    /// Maps an in-module `MetaSummary` from the live search store.
    init(summary: MetaSummary) {
        id = "\(summary.type):\(summary.id)"
        title = summary.name
        year = summary.releaseInfo?.trimmedNonEmpty
        type = summary.type
        posterURL = summary.poster.flatMap(URL.init(string:))
        backdropURL = (summary.background ?? summary.poster).flatMap(URL.init(string:))
    }
}

/// Outcome of one provider catalog for a query. Matches the Android per-catalog
/// `CatalogRow` accumulation in `SearchViewModel.loadCatalog`. Internal because
/// it carries `MetaSummary` values from the in-module search store.
struct SearchProviderResult: Identifiable, Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case loading
        case loaded
        case failed(message: String?)
    }

    public let addonID: String
    public let addonName: String
    public let addonBaseURL: String
    public let catalogID: String
    public let catalogName: String
    public let type: String
    public let items: [MetaSummary]
    public let state: State

    public init(
        addonID: String,
        addonName: String,
        addonBaseURL: String,
        catalogID: String,
        catalogName: String,
        type: String,
        items: [MetaSummary],
        state: State
    ) {
        self.addonID = addonID
        self.addonName = addonName
        self.addonBaseURL = addonBaseURL
        self.catalogID = catalogID
        self.catalogName = catalogName
        self.type = type
        self.items = items
        self.state = state
    }

    public var id: String { [addonBaseURL, addonID, type, catalogID].joined(separator: "|") }

    /// Android placeholder rows shimmer until the provider answers
    /// (`CatalogRow.isLoading` with `__placeholder_` items).
    public var isPlaceholder: Bool { state == .loading && items.isEmpty }
}

/// One provider row in the search results, including the Android header format:
/// capitalized catalog name (optionally ` - Type` suffix) and `from {addonName}`.
public struct SearchPresentationSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let providerName: String
    public let items: [SearchPosterItem]
    public let isLoading: Bool
    public let showsSeeAll: Bool

    public init(
        id: String,
        title: String,
        providerName: String,
        items: [SearchPosterItem],
        isLoading: Bool,
        showsSeeAll: Bool
    ) {
        self.id = id
        self.title = title
        self.providerName = providerName
        self.items = items
        self.isLoading = isLoading
        self.showsSeeAll = showsSeeAll
    }

    static func build(from result: SearchProviderResult, showTypeSuffix: Bool) -> SearchPresentationSection {
        SearchPresentationSection(
            id: result.id,
            title: sectionTitle(
                catalogName: result.catalogName,
                type: result.type,
                showTypeSuffix: showTypeSuffix
            ),
            providerName: result.addonName,
            items: result.items.map(SearchPosterItem.init(summary:)),
            isLoading: result.state == .loading,
            // Android CatalogRowSection: See All only for real rows with >= 15 items.
            showsSeeAll: result.state != .loading && result.items.count >= 15
        )
    }

    static func sectionTitle(catalogName: String, type: String, showTypeSuffix: Bool) -> String {
        guard let first = catalogName.first else { return "" }
        let formatted = String(first).uppercased() + catalogName.dropFirst()
        let label = type.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        if formatted.isEmpty { return "" }
        if showTypeSuffix && !label.isEmpty { return "\(formatted) - \(label)" }
        return formatted
    }
}

/// Whole-screen search state, mirroring the decision tree in Android `SearchScreen.kt`.
public enum SearchPresentationPhase: Equatable, Sendable {
    /// `EmptyScreenState(R.string.search_start_*)`.
    case startEmpty(subtitle: String)
    /// Recent-searches section replaces the empty screen.
    case recentSearches
    /// `SEARCH_SKELETON_ROW_COUNT` skeleton rails while the first answers arrive.
    case skeleton(rowCount: Int)
    /// Progressive per-provider rails; `isLoadingMore` adds the trailing skeleton rail.
    case results(sections: [SearchPresentationSection], isLoadingMore: Bool, notice: String?)
    /// `EmptyScreenState(R.string.search_no_results_*)`.
    case noResults
    /// `ErrorState(message, onRetry)` — only when nothing else can be shown.
    case failed(message: String)

    public static let startTitle = "Start Searching"
    public static let startSubtitle = "Enter at least 2 characters"
    public static let startSubtitleNoDiscover = "Discover is disabled. Enter at least 2 characters"
    public static let noResultsTitle = "No Results"
    public static let noResultsSubtitle = "Try searching with different keywords"
    public static let failedFallbackMessage = "Search failed"
}

public enum SearchStrings {
    public static let recentTitle = "Recent searches"
    public static let recentClear = "Clear history"
    public static let seeAll = "See All"
    public static let retry = "Retry"
}

/// Pure, testable mapping from the existing search store into the parity screen.
public struct SearchPresentation: Equatable, Sendable {
    public let query: String
    public let submittedQuery: String
    public let phase: SearchPresentationPhase
    public let recentSearches: [String]
    public let isDiscoverMode: Bool
    public let showRecentSearches: Bool
    public let hasPendingUnsubmittedQuery: Bool
    public let sections: [SearchPresentationSection]

    /// Android `shouldShowDiscoverInSearch` (`SearchUiState.kt`).
    public static func shouldShowDiscoverInSearch(
        discoverLocation: SearchDiscoverLocation,
        query: String,
        submittedQuery: String
    ) -> Bool {
        discoverLocation == .inSearch &&
            query.trimmingCharacters(in: .whitespacesAndNewlines).count < searchMinQueryLength &&
            submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func submittedQuery(from rawQuery: String) -> String {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= searchMinQueryLength ? trimmed : ""
    }

    static func build(
        query: String,
        submittedQuery: String,
        isSearching: Bool,
        errorMessage: String?,
        providerResults: [SearchProviderResult],
        recentSearches: [String],
        discoverLocation: SearchDiscoverLocation = .inSearch,
        showTypeSuffix: Bool = true
    ) -> SearchPresentation {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubmitted = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDiscoverMode = shouldShowDiscoverInSearch(
            discoverLocation: discoverLocation,
            query: trimmedQuery,
            submittedQuery: trimmedSubmitted
        )
        // Android SearchScreen: hasPendingUnsubmittedQuery.
        let hasPendingUnsubmittedQuery = !isDiscoverMode &&
            trimmedQuery.count >= searchMinQueryLength &&
            trimmedQuery != trimmedSubmitted
        let showRecentSearches = trimmedQuery.isEmpty && !recentSearches.isEmpty

        // Android updateCatalogRowsNow: keep placeholder rails and non-empty rails,
        // preserve provider (manifest) order, drop rows that came back empty.
        let sections = providerResults
            .filter { $0.items.isNotEmpty || $0.isPlaceholder }
            .map { SearchPresentationSection.build(from: $0, showTypeSuffix: showTypeSuffix) }
        let visibleSections = sections.filter { !$0.items.isEmpty || $0.isLoading }
        let everythingEmpty = providerResults.allSatisfy { $0.items.isEmpty }

        let phase: SearchPresentationPhase
        if isDiscoverMode {
            phase = showRecentSearches
                ? .recentSearches
                : .startEmpty(subtitle: SearchPresentationPhase.startSubtitle)
        } else if trimmedSubmitted.count < searchMinQueryLength && !hasPendingUnsubmittedQuery {
            let subtitle = discoverLocation == .off
                ? SearchPresentationPhase.startSubtitleNoDiscover
                : SearchPresentationPhase.startSubtitle
            phase = showRecentSearches ? .recentSearches : .startEmpty(subtitle: subtitle)
        } else if (hasPendingUnsubmittedQuery || isSearching) && visibleSections.isEmpty {
            // SEARCH_SKELETON_ROW_COUNT in SearchScreen.kt.
            phase = .skeleton(rowCount: 2)
        } else if errorMessage != nil && everythingEmpty && !isSearching {
            phase = .failed(message: errorMessage ?? SearchPresentationPhase.failedFallbackMessage)
        } else if !isSearching && !hasPendingUnsubmittedQuery && visibleSections.isEmpty {
            phase = .noResults
        } else {
            // Progressive: real rails stay visible while slower providers stream in.
            // Android ignores per-catalog errors whenever something can be shown;
            // we surface the message as a non-blocking notice instead of dropping it.
            phase = .results(
                sections: visibleSections,
                isLoadingMore: isSearching || hasPendingUnsubmittedQuery,
                notice: everythingEmpty ? nil : errorMessage
            )
        }

        return SearchPresentation(
            query: query,
            submittedQuery: submittedQuery,
            phase: phase,
            recentSearches: recentSearches,
            isDiscoverMode: isDiscoverMode,
            showRecentSearches: showRecentSearches,
            hasPendingUnsubmittedQuery: hasPendingUnsubmittedQuery,
            sections: sections
        )
    }
}

private extension Collection {
    var isNotEmpty: Bool { !isEmpty }
}
