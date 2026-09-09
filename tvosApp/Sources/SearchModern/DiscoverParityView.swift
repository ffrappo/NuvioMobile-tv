import SwiftUI

/// Presentation-only port of the Android TV `SearchDiscoverSection.kt`
/// composition, driven entirely by a section-model input
/// (`DiscoverPresentation`): the Discover header, the three filter pickers
/// (Type / Catalog / Genre) rendered as focusable chip rows, the metadata
/// line, the poster grid, and the load-more / show-more / loading action
/// cell. The integrator rebuilds the presentation from the existing
/// `DiscoveryStore`; this view owns no data flow.
public struct DiscoverParityView: View {
    public let presentation: DiscoverPresentation
    public let onSelectType: (String) -> Void
    public let onSelectCatalog: (String) -> Void
    public let onSelectGenre: (String?) -> Void
    public let onSelectItem: (SearchPosterItem) -> Void
    public let onLoadMore: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let posterSize = NuvioDesignTokens.Sizes.Cards.poster

    public init(
        presentation: DiscoverPresentation,
        onSelectType: @escaping (String) -> Void,
        onSelectCatalog: @escaping (String) -> Void,
        onSelectGenre: @escaping (String?) -> Void,
        onSelectItem: @escaping (SearchPosterItem) -> Void,
        onLoadMore: @escaping () -> Void = {}
    ) {
        self.presentation = presentation
        self.onSelectType = onSelectType
        self.onSelectCatalog = onSelectCatalog
        self.onSelectGenre = onSelectGenre
        self.onSelectItem = onSelectItem
        self.onLoadMore = onLoadMore
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.Rail.rowGap) {
                Text(presentation.title)
                    .nuvioTextStyle(.display)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                filterRow(
                    title: DiscoverStrings.filterType,
                    options: presentation.typeOptions,
                    selectedValue: presentation.selectedTypeValue,
                    onSelect: { onSelectType($0.value) }
                )
                filterRow(
                    title: DiscoverStrings.filterCatalog,
                    options: presentation.catalogOptions,
                    selectedValue: presentation.selectedCatalogValue,
                    onSelect: { onSelectCatalog($0.value) }
                )
                filterRow(
                    title: DiscoverStrings.filterGenre,
                    options: presentation.genreOptions,
                    selectedValue: presentation.selectedGenreValue ?? "__default__",
                    onSelect: { option in
                        onSelectGenre(option.value == "__default__" ? nil : option.value)
                    }
                )
                if !presentation.metadataLine.isEmpty {
                    Text(presentation.metadataLine)
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                gridContent
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
            .padding(.vertical, NuvioDesignTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        switch presentation.phase {
        case .loading:
            VStack(spacing: NuvioDesignTokens.Spacing.lg) {
                ProgressView().controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NuvioDesignTokens.Spacing.xxl)
        case .content:
            LazyVGrid(
                columns: [GridItem(
                    .adaptive(minimum: Self.posterSize.width, maximum: Self.posterSize.width * 1.4),
                    spacing: NuvioDesignTokens.Spacing.Rail.itemGap
                )],
                alignment: .leading,
                spacing: NuvioDesignTokens.Spacing.Rail.rowGap
            ) {
                ForEach(presentation.items) { item in
                    SearchPosterCard(item: item) { onSelectItem(item) }
                }
                if presentation.action != .none {
                    DiscoverActionCell(
                        action: presentation.action,
                        size: Self.posterSize,
                        onSelect: onLoadMore
                    )
                }
            }
        case .emptyNoCatalog:
            SearchEmptyStateView(
                systemImage: "square.grid.2x2",
                title: DiscoverPhase.emptyNoCatalogTitle,
                subtitle: DiscoverPhase.emptyNoCatalogSubtitle
            )
        case .emptyNoContent:
            SearchEmptyStateView(
                systemImage: "magnifyingglass",
                title: DiscoverPhase.emptyNoContentTitle,
                subtitle: DiscoverPhase.emptyNoContentSubtitle
            )
        }
    }

    private func filterRow(
        title: String,
        options: [DiscoverFilterOption],
        selectedValue: String?,
        onSelect: @escaping (DiscoverFilterOption) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            Text(title)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: NuvioDesignTokens.Spacing.sm) {
                    ForEach(options) { option in
                        DiscoverFilterChip(
                            label: option.label,
                            isSelected: option.value == selectedValue,
                            action: { onSelect(option) }
                        )
                    }
                }
                .padding(.vertical, NuvioDesignTokens.Spacing.xs)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct DiscoverFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                Text(label)
                    .nuvioTextStyle(.compactBody)
                    .lineLimit(1)
                if isSelected {
                    Image(systemName: "chevron.down")
                        .font(.system(size: NuvioDesignTokens.Sizes.Icons.xs))
                }
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.lg)
            .frame(minHeight: NuvioDesignTokens.Sizes.Buttons.defaultHeight)
            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            .background(
                isSelected
                    ? NuvioDesignTokens.Colors.brand
                    : NuvioDesignTokens.Colors.elevated,
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    NuvioDesignTokens.Colors.neutral700,
                    lineWidth: NuvioDesignTokens.Strokes.hairline
                )
            )
        }
        .buttonStyle(
            NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.lg)
        )
    }
}

/// Android `DiscoverActionCard` parity: a poster-sized trailing cell whose
/// role follows `DiscoverLoadAction` (show more / load more / loading).
private struct DiscoverActionCell: View {
    let action: DiscoverLoadAction
    let size: CGSize
    let onSelect: () -> Void

    private var label: String {
        switch action {
        case .showMore: DiscoverStrings.showMore
        case .loadMore: DiscoverStrings.loadMore
        case .loading: DiscoverStrings.loading
        case .none: ""
        }
    }

    var body: some View {
        Group {
            if action == .loading {
                VStack {
                    ProgressView()
                }
                .frame(width: size.width, height: size.height)
                .background(
                    RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.posterRadius, style: .continuous)
                        .fill(NuvioDesignTokens.Colors.elevated)
                )
                .accessibilityLabel(DiscoverStrings.loading)
            } else {
                Button(action: onSelect) {
                    VStack(spacing: NuvioDesignTokens.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: NuvioDesignTokens.Sizes.Icons.xl))
                            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        Text(label)
                            .nuvioTextStyle(.cardTitle)
                            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: size.width, height: size.height)
                    .background(
                        RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.posterRadius, style: .continuous)
                            .fill(NuvioDesignTokens.Colors.elevated)
                    )
                }
                .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.posterRadius))
            }
        }
    }
}
