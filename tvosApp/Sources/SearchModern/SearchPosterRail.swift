import SwiftUI

/// Poster card for search and discover rails. Reuses `NuvioArtworkView` and
/// the Nuvio focus tokens; focus stays entirely system-owned.
struct SearchPosterCard: View {
    let item: SearchPosterItem
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let posterSize = NuvioDesignTokens.Sizes.Cards.poster

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                NuvioArtworkView(
                    url: item.posterURL,
                    mode: .poster,
                    pixelSize: Self.posterSize,
                    cornerRadius: NuvioDesignTokens.Shapes.posterRadius
                )
                Text(item.title)
                    .nuvioTextStyle(.cardTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(1)
                if let year = item.year {
                    Text(year)
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(width: Self.posterSize.width, alignment: .leading)
        }
        .buttonStyle(NuvioFocusButtonStyle(cornerRadius: NuvioDesignTokens.Shapes.posterRadius))
        .accessibilityLabel(item.title)
    }
}

/// Skeleton placeholder card used by skeleton rails and the trailing
/// "still searching" rail (Android placeholder `MetaPreview` shimmer).
struct SearchPosterSkeletonCard: View {
    private static let posterSize = NuvioDesignTokens.Sizes.Cards.poster

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            NuvioShimmerShape(
                size: Self.posterSize,
                cornerRadius: NuvioDesignTokens.Shapes.posterRadius,
                cycleDuration: NuvioMotion.shimmerCycle,
                baseColor: NuvioDesignTokens.Colors.elevated,
                highlightColor: NuvioDesignTokens.Colors.elevatedSecondary
            )
            NuvioDesignTokens.Colors.elevated
                .frame(width: Self.posterSize.width * 0.7, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xs))
        }
        .frame(width: Self.posterSize.width, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// Poster rail with the Android `CatalogRowSection` header composition:
/// catalog title (headline) and `from {addonName}` subtitle, followed by a
/// horizontally scrolling poster row.
struct SearchPosterRail: View {
    let section: SearchPresentationSection
    let onSelect: (SearchPosterItem) -> Void
    let onSeeAll: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        section: SearchPresentationSection,
        onSelect: @escaping (SearchPosterItem) -> Void,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.section = section
        self.onSelect = onSelect
        self.onSeeAll = onSeeAll.flatMap { handler in
            section.showsSeeAll ? handler : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                    ForEach(section.items) { item in
                        SearchPosterCard(item: item) { onSelect(item) }
                    }
                    if section.isLoading {
                        ForEach(0..<8, id: \.self) { _ in
                            SearchPosterSkeletonCard()
                        }
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                if !section.title.isEmpty {
                    Text(section.title)
                        .nuvioTextStyle(.sectionTitle)
                        .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                        .lineLimit(3)
                }
                if !section.providerName.isEmpty {
                    Text("from \(section.providerName)")
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let onSeeAll {
                Button(SearchStrings.seeAll, action: onSeeAll)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
    }
}

/// Skeleton rail matching the two-row Android search skeleton.
struct SearchSkeletonRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            NuvioDesignTokens.Colors.elevated
                .frame(width: 240, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.skeletonRadius))
                .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                    ForEach(0..<8, id: \.self) { _ in
                        SearchPosterSkeletonCard()
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Screen.overscanHorizontal)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
            .scrollClipDisabled()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Searching")
    }
}
