import SwiftUI

/// Native port of GridHomeContent.kt: a full-width hero band, horizontal
/// Continue Watching / Upcoming rails, then poster grid sections with pinned
/// divider headers and See All cards, with cells sized from the design
/// tokens and trimmed so See All never sits alone on a row.
struct GridHomeView: View {
    let presentation: GridHomePresentation
    let onSelect: (MetaSummary) -> Void
    let onOpenCatalog: (HomeCatalogSection) -> Void
    let onOpenCollection: (TVCollection) -> Void

    init(
        presentation: GridHomePresentation,
        onSelect: @escaping (MetaSummary) -> Void,
        onOpenCatalog: @escaping (HomeCatalogSection) -> Void,
        onOpenCollection: @escaping (TVCollection) -> Void
    ) {
        self.presentation = presentation
        self.onSelect = onSelect
        self.onOpenCatalog = onOpenCatalog
        self.onOpenCollection = onOpenCollection
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = GridHomeGeometry.columns(containerWidth: proxy.size.width)
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: GridHomeGeometry.rowSpacing,
                    pinnedViews: [.sectionHeaders]
                ) {
                    if !presentation.heroes.isEmpty {
                        HomeModeHeroBand(
                            pages: presentation.heroes,
                            height: ClassicHomeScale.heroBandHeight,
                            showsBackdrop: true,
                            onSelect: { hero in
                                if let summary = presentation.summary(for: hero) {
                                    onSelect(summary)
                                }
                            }
                        )
                        .padding(.horizontal, GridHomeGeometry.horizontalPadding)
                    }
                    if !presentation.continueWatching.isEmpty {
                        gridRailHeader("Continue Watching")
                        ProgressRail(items: presentation.continueWatching) { item in
                            selectProgress(item)
                        }
                    }
                    if !presentation.upcoming.isEmpty {
                        gridRailHeader("Upcoming")
                        ProgressRail(items: presentation.upcoming) { item in
                            selectProgress(item)
                        }
                    }
                    ForEach(presentation.sections) { section in
                        Section {
                            LazyVGrid(
                                columns: gridColumns(columns),
                                alignment: .leading,
                                spacing: GridHomeGeometry.rowSpacing
                            ) {
                                ForEach(presentation.visibleItems(in: section, columns: columns)) { item in
                                    cell(item)
                                }
                            }
                            .padding(.horizontal, GridHomeGeometry.horizontalPadding)
                        } header: {
                            GridSectionHeader(title: section.headerTitle)
                        }
                    }
                }
                .padding(
                    .top,
                    presentation.heroes.isEmpty ? NuvioDesignTokens.Spacing.xl : 0
                )
                .padding(.bottom, NuvioDesignTokens.Spacing.xxl)
            }
        }
        .background(NuvioDesignTokens.Colors.canvasBlack.ignoresSafeArea())
    }

    private func gridColumns(_ count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: GridHomeGeometry.posterSize.width),
                spacing: GridHomeGeometry.itemSpacing
            ),
            count: max(1, count)
        )
    }

    private func gridRailHeader(_ title: String) -> some View {
        Text(title)
            .nuvioTextStyle(.sectionTitle)
            .padding(.horizontal, GridHomeGeometry.horizontalPadding)
    }

    @ViewBuilder
    private func cell(_ item: GridHomeItem) -> some View {
        switch item {
        case .content(let railItem):
            HomeModePosterCard(
                item: railItem,
                size: GridHomeGeometry.posterSize
            ) {
                if let summary = presentation.summariesByItemID[railItem.id] {
                    onSelect(summary)
                }
            }
        case .seeAll(let sectionID):
            GridSeeAllCard {
                if let section = presentation.sectionsByID[sectionID] {
                    onOpenCatalog(section)
                }
            }
        case .collectionFolder(let folder, let collectionID):
            GridCollectionFolderCard(folder: folder) {
                if let collection = presentation.collections
                    .first(where: { $0.id == collectionID }) {
                    onOpenCollection(collection)
                }
            }
        }
    }

    private func selectProgress(_ item: ContinueWatchingCard) {
        onSelect(
            item.summary.routedTo(
                videoID: item.videoID,
                season: item.season,
                episode: item.episode
            )
        )
    }
}

/// SectionDivider: the headline that opens each grid section. Pinned while
/// the section scrolls, backed by a canvas gradient like StickyCategoryHeader.
struct GridSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.tvSafe)
            .nuvioTextStyle(.headline)
            .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GridHomeGeometry.horizontalPadding)
            .padding(.top, NuvioDesignTokens.Spacing.xl)
            .padding(.bottom, NuvioDesignTokens.Spacing.md)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: NuvioDesignTokens.Colors.canvasBlack, location: 0),
                        .init(
                            color: NuvioDesignTokens.Colors.canvasBlack.opacity(0.95),
                            location: 0.7
                        ),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .accessibilityAddTraits(.isHeader)
    }
}

/// SeeAllGridCard: a poster-sized elevated card with the arrow glyph.
struct GridSeeAllCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xs) {
                RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.posterRadius)
                    .fill(NuvioDesignTokens.Colors.elevated)
                    .frame(
                        width: GridHomeGeometry.posterSize.width,
                        height: GridHomeGeometry.posterSize.height
                    )
                    .overlay {
                        VStack(spacing: NuvioDesignTokens.Spacing.sm) {
                            Image(systemName: "arrow.forward")
                                .font(.system(size: NuvioDesignTokens.Sizes.Icons.lg))
                                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                            Text("See All")
                                .nuvioTextStyle(.cardTitle)
                                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                        }
                    }
                    .modifier(
                        HomeModeFocusRing(
                            cornerRadius: NuvioDesignTokens.Shapes.posterRadius
                        )
                    )
                // Reserve the label slot so rows align with content cards.
                Text("See All")
                    .nuvioTextStyle(.cardTitle)
                    .foregroundStyle(.clear)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .frame(width: GridHomeGeometry.posterSize.width, alignment: .leading)
            }
        }
        .buttonStyle(HomeModePosterButtonStyle())
        .accessibilityLabel("See All")
        .accessibilityHint("Opens the full catalog")
    }
}

/// GridCollectionFolderCard: folder tile with the poster/landscape/square
/// aspect from its tileShape and an optional title overlay.
struct GridCollectionFolderCard: View {
    let folder: TVCollectionFolder
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RemoteArtwork(
                    urlString: folder.coverImageUrl,
                    systemPlaceholder: "folder.fill"
                )
                .aspectRatio(aspectRatio, contentMode: .fill)

                if !folder.hideTitle {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .aspectRatio(aspectRatio, contentMode: .fill)
                    Text(folder.title.tvSafe)
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(NuvioDesignTokens.Spacing.sm)
                        .frame(maxWidth: .infinity)
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: NuvioDesignTokens.Shapes.collectionRadius,
                    style: .continuous
                )
            )
            .modifier(
                HomeModeFocusRing(
                    cornerRadius: NuvioDesignTokens.Shapes.collectionRadius
                )
            )
        }
        .buttonStyle(HomeModePosterButtonStyle())
        .accessibilityLabel(folder.title.tvSafe)
        .accessibilityHint("Shows this collection")
    }

    private var aspectRatio: CGFloat {
        switch folder.tileShape.lowercased() {
        case "landscape": return NuvioDesignTokens.Media.backdropAspectRatio
        case "square": return 1
        default: return NuvioDesignTokens.Media.posterAspectRatio
        }
    }
}
