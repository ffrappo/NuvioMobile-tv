import SwiftUI

/// Collection rail with folder-art fallback, per Android `CollectionSection.kt`.
public struct DetailsCollectionSectionView: View {
    public let model: DetailsCollectionSectionModel
    public let onSelectItem: (DetailsPosterItemModel) -> Void

    public init(
        model: DetailsCollectionSectionModel,
        onSelectItem: @escaping (DetailsPosterItemModel) -> Void = { _ in }
    ) {
        self.model = model
        self.onSelectItem = onSelectItem
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            DetailsSectionHeaderView(title: model.title, symbol: "folder.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                    ForEach(model.items) { item in
                        DetailsPosterCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            artworkURLString: item.posterURLString ?? item.backdropURLString,
                            placeholderSymbol: "folder.fill",
                            onSelect: { onSelectItem(item) }
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

/// Company / network logo row, per Android `CompanyLogosSection.kt`:
/// white cards with fitted logos and a text fallback. Read-only presentation.
public struct DetailsCompanyLogosView: View {
    public let title: String
    public let companies: [DetailsCompanyItem]

    /// Android CompanyLogoCard parity: 140dp x 56dp white cards.
    private let cardWidth: CGFloat = 140
    private let cardHeight: CGFloat = 56

    public init(title: String, companies: [DetailsCompanyItem]) {
        self.title = title
        self.companies = companies
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            DetailsSectionHeaderView(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvioDesignTokens.Spacing.md) {
                    ForEach(companies) { company in
                        companyCard(company)
                    }
                }
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
                .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
            }
        }
        .padding(.top, NuvioDesignTokens.Spacing.lg)
    }

    @ViewBuilder
    private func companyCard(_ company: DetailsCompanyItem) -> some View {
        ZStack {
            NuvioDesignTokens.Colors.primaryText
            if let logo = company.logoURLString {
                NuvioArtworkView(
                    urlString: logo,
                    mode: .titleLogo,
                    pixelSize: CGSize(width: cardWidth - 28, height: cardHeight - 20),
                    cornerRadius: 0,
                    statePresentation: .transparent,
                    failureSystemImage: "building.2"
                )
                .padding(.horizontal, NuvioDesignTokens.Spacing.md)
                .padding(.vertical, NuvioDesignTokens.Spacing.sm)
            } else {
                Text(company.name)
                    .nuvioTextStyle(.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral650)
                    .lineLimit(1)
                    .padding(.horizontal, NuvioDesignTokens.Spacing.md)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.sm, style: .continuous)
        )
        .accessibilityLabel(company.name)
    }
}

/// Read-only comments placeholder header, per Android `CommentsSection.kt`
/// (`detail_comments_title` / `detail_comments_subtitle`). The full Trakt
/// comments surface arrives in a later integration round.
public struct DetailsCommentsPlaceholderView: View {
    public let model: DetailsCommentsHeaderModel

    public init(model: DetailsCommentsHeaderModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
            DetailsSectionHeaderView(title: model.title, symbol: "bubble.left.and.bubble.right.fill")
            Text(model.subtitle)
                .nuvioTextStyle(.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
            Text("Comments are read-only in this build.")
                .nuvioTextStyle(.compactBody)
                .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
                .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
        }
        .padding(.top, NuvioDesignTokens.Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}
