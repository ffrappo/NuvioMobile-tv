import SwiftUI

/// "More like this" rail of landscape poster cards with per-item route
/// callbacks, per Android `MoreLikeThisSection.kt`.
public struct DetailsMoreLikeThisSectionView: View {
    public let model: DetailsRailSectionModel
    public let watchedItemIDs: Set<String>
    public let onSelectItem: (DetailsPosterItemModel) -> Void

    public init(
        model: DetailsRailSectionModel,
        watchedItemIDs: Set<String> = [],
        onSelectItem: @escaping (DetailsPosterItemModel) -> Void = { _ in }
    ) {
        self.model = model
        self.watchedItemIDs = watchedItemIDs
        self.onSelectItem = onSelectItem
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            DetailsSectionHeaderView(title: model.title, symbol: "sparkles.rectangle.stack")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                    ForEach(model.items) { item in
                        DetailsPosterCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            artworkURLString: item.backdropURLString ?? item.posterURLString,
                            isWatched: watchedItemIDs.contains(item.id),
                            onSelect: { onSelectItem(item) }
                        )
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
            .focusSection()
            if let sourceLabel = model.sourceLabel, !sourceLabel.isEmpty {
                Text(sourceLabel)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
            }
        }
        .padding(.top, NuvioDesignTokens.Spacing.lg)
    }
}
