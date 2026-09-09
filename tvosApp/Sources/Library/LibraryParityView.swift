import SwiftUI

/// Presentation-only Library composition the integrator wires into
/// `LibraryView`. All filtering/sorting state lives in the bound
/// `LibraryPresentation`; this view renders the header, view-mode switcher,
/// type tabs, provider + watched filter rows, sort row, a native free-text
/// search field, and the poster grid with watched markers. Focus restoration
/// after a re-sort mirrors Android's `sortSelectionVersion` LaunchedEffect:
/// scroll to the top and focus the first visible poster.
struct LibraryParityView: View {
    @Binding var presentation: LibraryPresentation
    let onSelect: (MetaSummary) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedPosterID: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xl) {
                    header
                    HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.xxl) {
                        LibraryFilterRow(
                            title: "View",
                            choices: viewModeChoices,
                            selection: viewModeSelection
                        )
                        LibraryFilterRow(
                            title: "Type",
                            choices: typeTabChoices,
                            selection: $presentation.selectedTypeTabKey
                        )
                        LibraryFilterRow(
                            title: "Provider",
                            choices: providerChoices,
                            selection: providerSelection
                        )
                    }
                    HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.xxl) {
                        LibraryFilterRow(
                            title: "Watched",
                            choices: watchedFilterChoices,
                            selection: watchedFilterSelection
                        )
                        LibraryFilterRow(
                            title: "Sort",
                            choices: sortChoices,
                            selection: sortSelection
                        )
                    }
                    searchField

                    if let empty = presentation.emptyState {
                        emptyState(empty)
                    } else {
                        posterGrid
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.horizontal)
                .padding(.top, NuvioDesignTokens.Spacing.Screen.vertical)
                .padding(.bottom, NuvioDesignTokens.Spacing.xxl)
            }
            .onChange(of: presentation.sortSelectionVersion) {
                restoreFocusToFirstPoster(proxy)
            }
        }
        .defaultFocus($focusedPosterID, presentation.visibleItems.first?.libraryIdentityKey)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Library".tvSafe)
                .nuvioTextStyle(.headline)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            Spacer()
            Text(presentation.viewMode.sourceLabel.tvSafe)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .tracking(2)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Row choices and bindings

    private var viewModeChoices: [LibraryFilterChoice] {
        LibraryViewMode.allCases.map {
            LibraryFilterChoice(id: $0.rawValue, label: $0.label)
        }
    }

    private var viewModeSelection: Binding<String> {
        Binding(
            get: { presentation.viewMode.rawValue },
            set: { rawValue in
                if let mode = LibraryViewMode(rawValue: rawValue) {
                    presentation.viewMode = mode
                }
            }
        )
    }

    private var typeTabChoices: [LibraryFilterChoice] {
        presentation.typeTabs.map {
            LibraryFilterChoice(id: $0.key, label: $0.label)
        }
    }

    private var providerChoices: [LibraryFilterChoice] {
        var choices = [
            LibraryFilterChoice(id: LibraryProviderOption.allKey, label: "All")
        ]
        choices += presentation.providerOptions.map {
            LibraryFilterChoice(id: $0.key, label: $0.labelWithCount)
        }
        return choices
    }

    private var providerSelection: Binding<String> {
        Binding(
            get: { presentation.effectiveProviderKey ?? LibraryProviderOption.allKey },
            set: { rawValue in
                presentation.selectedProviderKey =
                    rawValue == LibraryProviderOption.allKey ? nil : rawValue
            }
        )
    }

    private var watchedFilterChoices: [LibraryFilterChoice] {
        LibraryWatchedFilter.allCases.map {
            LibraryFilterChoice(id: $0.rawValue, label: $0.label)
        }
    }

    private var watchedFilterSelection: Binding<String> {
        Binding(
            get: { presentation.watchedFilter.rawValue },
            set: { rawValue in
                if let filter = LibraryWatchedFilter(rawValue: rawValue) {
                    presentation.watchedFilter = filter
                }
            }
        )
    }

    private var sortChoices: [LibraryFilterChoice] {
        presentation.sortOptions.map {
            LibraryFilterChoice(id: $0.rawValue, label: $0.label)
        }
    }

    /// Selecting a sort option routes through `select(sortOption:)` so the
    /// `sortSelectionVersion` increments and focus restoration fires.
    private var sortSelection: Binding<String> {
        Binding(
            get: { presentation.sortOption.rawValue },
            set: { rawValue in
                if let option = LibrarySortOption(rawValue: rawValue) {
                    presentation.select(sortOption: option)
                }
            }
        )
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            TextField("Search your library", text: $presentation.query)
                .textFieldStyle(.plain)
            if !presentation.query.isEmpty {
                Button {
                    presentation.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .nuvioTextStyle(.body)
        .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
        .padding(.vertical, NuvioDesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.md, style: .continuous)
                .fill(NuvioDesignTokens.Colors.elevated)
        )
    }

    // MARK: Empty state

    private func emptyState(_ empty: LibraryEmptyState) -> some View {
        NuvioUnavailableView(
            title: empty.title,
            symbol: empty.viewMode == .cloud ? "cloud" : "heart",
            message: empty.subtitle
        )
    }

    // MARK: Poster grid

    private var posterWidth: CGFloat {
        NuvioDesignTokens.Sizes.Cards.poster.width
    }

    private var posterGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: posterWidth),
                    spacing: NuvioDesignTokens.Spacing.md
                )
            ],
            spacing: NuvioDesignTokens.Spacing.lg
        ) {
            ForEach(presentation.visibleItems, id: \.libraryIdentityKey) { item in
                PosterCardView(
                    title: item.name,
                    year: item.releaseInfo?.trimmedNonEmpty,
                    artwork: artworkSource(for: item),
                    status: PosterCardStatus(isWatched: presentation.isWatched(item)),
                    artworkProvider: artworkProvider,
                    onSelect: { onSelect(item) }
                )
                .focused($focusedPosterID, equals: item.libraryIdentityKey)
            }
        }
        .focusSection()
        .animation(
            reduceMotion ? nil : NuvioMotion.animation(for: .content, reduceMotion: reduceMotion),
            value: presentation.visibleItems.map(\.libraryIdentityKey)
        )
    }

    // MARK: Focus restoration

    /// Mirrors Android's `sortSelectionVersion` effect: scroll the grid back
    /// to the top and focus the first visible poster after a re-sort.
    private func restoreFocusToFirstPoster(_ proxy: ScrollViewProxy) {
        guard presentation.sortSelectionVersion > 0,
              let first = presentation.visibleItems.first
        else { return }
        if reduceMotion {
            proxy.scrollTo(first.libraryIdentityKey, anchor: .top)
            focusedPosterID = first.libraryIdentityKey
        } else {
            withAnimation(NuvioMotion.animation(for: .content, reduceMotion: reduceMotion)) {
                proxy.scrollTo(first.libraryIdentityKey, anchor: .top)
                focusedPosterID = first.libraryIdentityKey
            }
        }
    }

    // MARK: Artwork

    private func artworkSource(for item: MetaSummary) -> PosterArtworkSource {
        if let poster = item.poster, let url = URL(string: poster) {
            return .url(url)
        }
        return .placeholder(systemName: "film")
    }

    private func artworkProvider(
        _ source: PosterArtworkSource,
        _ pixelSize: CGSize,
        _ cornerRadius: CGFloat
    ) -> AnyView {
        switch source {
        case .url(let url):
            return AnyView(NuvioArtworkView(
                url: url,
                mode: .poster,
                pixelSize: pixelSize,
                cornerRadius: cornerRadius
            ))
        case .loading:
            return AnyView(NuvioShimmerShape(size: pixelSize, cornerRadius: cornerRadius))
        case .placeholder(let systemName):
            return AnyView(NuvioArtworkView(
                url: nil,
                mode: .poster,
                pixelSize: pixelSize,
                cornerRadius: cornerRadius,
                placeholderSystemImage: systemName
            ))
        }
    }
}
