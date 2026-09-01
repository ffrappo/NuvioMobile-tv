import SwiftUI

/// Presentation-only port of the Android TV `SearchScreen.kt` composition:
/// native search field, recent-searches capsule row with clear-all,
/// per-provider poster rails that appear progressively as results stream in,
/// and the Android empty/loading/partial-failure state rules. The integrator
/// rebuilds `SearchPresentation` from the existing `SearchStore` and feeds it
/// in; this view owns no data flow.
public struct SearchParityView: View {
    @Binding public var query: String
    public let presentation: SearchPresentation
    public let onSubmitQuery: () -> Void
    public let onSelectItem: (SearchPosterItem) -> Void
    public let onSelectRecentSearch: (String) -> Void
    public let onClearRecentSearches: () -> Void
    public let onRetry: () -> Void
    public let onSeeAll: ((SearchPresentationSection) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        query: Binding<String>,
        presentation: SearchPresentation,
        onSubmitQuery: @escaping () -> Void,
        onSelectItem: @escaping (SearchPosterItem) -> Void,
        onSelectRecentSearch: @escaping (String) -> Void,
        onClearRecentSearches: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onSeeAll: ((SearchPresentationSection) -> Void)? = nil
    ) {
        _query = query
        self.presentation = presentation
        self.onSubmitQuery = onSubmitQuery
        self.onSelectItem = onSelectItem
        self.onSelectRecentSearch = onSelectRecentSearch
        self.onClearRecentSearches = onClearRecentSearches
        self.onRetry = onRetry
        self.onSeeAll = onSeeAll
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.rowGap) {
                SearchParityField(query: $query, onSubmit: onSubmitQuery)
                content
            }
            .padding(.top, NuvioDesignTokens.Spacing.lg)
            .padding(.bottom, NuvioDesignTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presentation.phase {
        case .recentSearches:
            RecentSearchesView(
                searches: presentation.recentSearches,
                onSelect: onSelectRecentSearch,
                onClearAll: onClearRecentSearches
            )
        case let .startEmpty(subtitle):
            SearchEmptyStateView(
                systemImage: "magnifyingglass",
                title: SearchPresentationPhase.startTitle,
                subtitle: subtitle
            )
        case let .skeleton(rowCount):
            // SEARCH_SKELETON_ROW_COUNT rows while the first answers arrive.
            ForEach(0..<rowCount, id: \.self) { _ in
                SearchSkeletonRail()
            }
        case let .failed(message):
            SearchErrorStateView(message: message, onRetry: onRetry)
        case .noResults:
            SearchEmptyStateView(
                systemImage: "magnifyingglass",
                title: SearchPresentationPhase.noResultsTitle,
                subtitle: SearchPresentationPhase.noResultsSubtitle
            )
        case let .results(sections, isLoadingMore, notice):
            // Progressive appearance: sections render as providers answer.
            ForEach(sections) { section in
                SearchPosterRail(
                    section: section,
                    onSelect: onSelectItem,
                    onSeeAll: onSeeAll.map { handler in { handler(section) } }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }
            if isLoadingMore {
                // Android search_loading_more: a trailing skeleton rail while
                // remaining providers still answer.
                SearchSkeletonRail()
            }
            if let notice {
                // Partial failure: results are shown, the failure is surfaced
                // as a non-blocking footnote (Android drops it silently).
                Text(notice)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                    .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
            }
        }
    }
}

extension SearchParityView {
    /// Convenience for wiring straight against the existing `SearchStore`
    /// progressive results without rebuilding the presentation by hand.
    static func presentation(
        query: String,
        submittedQuery: String,
        isSearching: Bool,
        errorMessage: String?,
        providerResults: [SearchProviderResult],
        recentSearches: [String],
        discoverLocation: SearchDiscoverLocation = .inSearch
    ) -> SearchPresentation {
        SearchPresentation.build(
            query: query,
            submittedQuery: submittedQuery,
            isSearching: isSearching,
            errorMessage: errorMessage,
            providerResults: providerResults,
            recentSearches: recentSearches,
            discoverLocation: discoverLocation
        )
    }
}
