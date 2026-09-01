import SwiftUI

/// Trailer entry rail, per Android `TrailerSection.kt`: landscape cards with a
/// poster, title/subtitle, and a play affordance. Selecting an entry invokes
/// the callback with the trailer URL — no player code lives here.
public struct DetailsTrailerSectionView: View {
    public let items: [DetailsTrailerItemModel]
    public let title: String
    public let onSelectTrailer: (DetailsTrailerItemModel) -> Void

    public init(
        items: [DetailsTrailerItemModel],
        title: String = "Trailer",
        onSelectTrailer: @escaping (DetailsTrailerItemModel) -> Void = { _ in }
    ) {
        self.items = items
        self.title = title
        self.onSelectTrailer = onSelectTrailer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            DetailsSectionHeaderView(title: title, symbol: "play.rectangle.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                    ForEach(items) { item in
                        DetailsPosterCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            artworkURLString: item.thumbnailURLString,
                            placeholderSymbol: "play.rectangle",
                            playAffordance: true,
                            onSelect: { onSelectTrailer(item) }
                        )
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
            .focusSection()
        }
        .padding(.top, NuvioDesignTokens.Spacing.lg)
    }
}
