import Foundation

/// Grid layout geometry and paging math ported from GridHomeContent.kt and
/// HomeViewModelCatalogPipeline.kt.
enum GridHomeGeometry {
    /// "We use 8 as safe max columns (widest known config) to avoid cutting
    /// too early" (HomeViewModelCatalogPipeline.kt).
    static let safeMaxColumns = 8
    /// contentPadding start xxxl + end xl.
    static let horizontalPadding: CGFloat =
        NuvioDesignTokens.Spacing.xxxl + NuvioDesignTokens.Spacing.xl
    /// horizontalArrangement spacedBy md.
    static let itemSpacing: CGFloat = NuvioDesignTokens.Spacing.md
    /// verticalArrangement spacedBy lg.
    static let rowSpacing: CGFloat = NuvioDesignTokens.Spacing.lg
    static let posterSize = NuvioDesignTokens.Sizes.Cards.poster
    /// gridRowCount: 2 rows for compact posters, 3 otherwise.
    static let compactPosterWidthThreshold: CGFloat = 104

    static func rowsPerSection(posterWidth: CGFloat) -> Int {
        posterWidth <= compactPosterWidthThreshold ? 2 : 3
    }

    /// Upper bound of displayed items per section: safeMaxColumns * rowCount.
    static func maxDisplaySlots(posterWidth: CGFloat) -> Int {
        safeMaxColumns * rowsPerSection(posterWidth: posterWidth)
    }

    /// GridCells.Adaptive column count for an available container width.
    static func columns(
        containerWidth: CGFloat,
        posterWidth: CGFloat = posterSize.width
    ) -> Int {
        let usable = containerWidth - horizontalPadding
        guard usable > 0 else { return 1 }
        let raw = (usable + itemSpacing) / (posterWidth + itemSpacing)
        return max(1, Int(raw.rounded(.down)))
    }

    /// The Composable-layer trim: cap content so the See All card never ends
    /// up alone on a trailing row. Mirrors trimmedPostItems in
    /// GridHomeContent.kt (only applied when more than one column fits).
    static func trimmedContentCount(
        contentCount: Int,
        showsSeeAll: Bool,
        columns: Int,
        rowsPerSection: Int
    ) -> Int {
        guard columns > 1 else { return contentCount }
        let maxItems = columns * rowsPerSection
        guard showsSeeAll else { return min(contentCount, maxItems) }
        let capped = min(contentCount, maxItems - 1)
        let totalWithSeeAll = capped + 1
        let lastRowCount = totalWithSeeAll % columns
        if lastRowCount == 1 && capped >= columns {
            return capped - 1
        }
        return capped
    }
}

/// A cell of the grid section body.
enum GridHomeItem: Identifiable, Equatable {
    case content(RailItem)
    case seeAll(sectionID: String)
    case collectionFolder(TVCollectionFolder, collectionID: String)

    var id: String {
        switch self {
        case .content(let item): return "grid_\(item.id)"
        case .seeAll(let sectionID): return "see_all_\(sectionID)"
        case .collectionFolder(let folder, let collectionID):
            return "col_folder_\(collectionID)_\(folder.id)"
        }
    }
}

/// One titled section of the grid: a catalog divider with its poster page,
/// or a collection header with folder tiles.
struct GridHomeSection: Identifiable, Equatable {
    let id: String
    let headerTitle: String
    let collectionID: String?
    let contentItems: [RailItem]
    let hasSeeAll: Bool
    let folderItems: [TVCollectionFolder]

    var isCollection: Bool { collectionID != nil }

    init(
        id: String,
        headerTitle: String,
        collectionID: String? = nil,
        contentItems: [RailItem] = [],
        hasSeeAll: Bool = false,
        folderItems: [TVCollectionFolder] = []
    ) {
        self.id = id
        self.headerTitle = headerTitle
        self.collectionID = collectionID
        self.contentItems = contentItems
        self.hasSeeAll = hasSeeAll
        self.folderItems = folderItems
    }

    /// Total slots the section occupies in the flattened grid item list:
    /// the header plus its visible cells.
    var visibleItemCount: Int {
        if isCollection { return folderItems.count }
        return contentItems.count + (hasSeeAll ? 1 : 0)
    }
}

/// Sticky section header lookup over the flattened grid item list, ported
/// from buildSectionMapping/SectionMapping.findSectionForIndex.
struct GridSectionMapping: Equatable {
    struct Entry: Equatable, Sendable {
        let startIndex: Int
        let title: String

        init(startIndex: Int, title: String) {
            self.startIndex = startIndex
            self.title = title
        }
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries.sorted { $0.startIndex < $1.startIndex }
    }

    /// Floor search: the section whose start index is the greatest one that
    /// does not exceed the given flattened item index.
    func title(forItemIndex index: Int) -> String? {
        guard !entries.isEmpty else { return nil }
        var low = 0
        var high = entries.count - 1
        var result: Entry?
        while low <= high {
            let mid = (low + high) / 2
            if entries[mid].startIndex <= index {
                result = entries[mid]
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result?.title
    }
}

/// Presentation mapping for the Grid layout.
struct GridHomePresentation: Equatable {
    let heroes: [HeroItem]
    let continueWatching: [ContinueWatchingCard]
    let upcoming: [ContinueWatchingCard]
    let sections: [GridHomeSection]
    let collections: [TVCollection]
    let summariesByItemID: [String: MetaSummary]
    let summariesByHeroID: [String: MetaSummary]
    let sectionsByID: [String: HomeCatalogSection]
    /// Poster width the section capping was computed with.
    let posterWidth: CGFloat

    static func build(
        snapshot: HomeSnapshot,
        preferences: HomePreferences,
        posterWidth: CGFloat = GridHomeGeometry.posterSize.width
    ) -> GridHomePresentation {
        let mapped = HomeModeRailMapping.map(snapshot: snapshot, preferences: preferences)
        let slots = GridHomeGeometry.maxDisplaySlots(posterWidth: posterWidth)
        let sectionsByID = Dictionary(
            uniqueKeysWithValues: snapshot.sections.map { ($0.id, $0) }
        )

        var sections: [GridHomeSection] = []
        for rail in mapped.sections where !rail.items.isEmpty {
            // Grid layout: skip loading placeholder rows entirely.
            let showsSeeAll = rail.hasMore || rail.items.count > slots
            let rawMax = showsSeeAll ? slots - 1 : slots
            let type = sectionsByID[rail.id]?.definition.type ?? ""
            sections.append(
                GridHomeSection(
                    id: rail.id,
                    headerTitle: Self.sectionTitle(
                        catalogName: rail.title,
                        type: type,
                        showsTypeSuffix: preferences.showCatalogType
                    ),
                    contentItems: Array(rail.items.prefix(rawMax)),
                    hasSeeAll: showsSeeAll
                )
            )
        }
        for collection in snapshot.collections where !collection.folders.isEmpty {
            sections.append(
                GridHomeSection(
                    id: "collection_\(collection.id)",
                    headerTitle: collection.title.capitalizingFirstLetter,
                    collectionID: collection.id,
                    folderItems: collection.folders
                )
            )
        }

        return GridHomePresentation(
            heroes: HomeModeRailMapping.heroItems(snapshot),
            continueWatching: snapshot.continueWatching,
            upcoming: snapshot.upcoming,
            sections: sections,
            collections: snapshot.collections,
            summariesByItemID: mapped.summariesByRailID,
            summariesByHeroID: mapped.summariesByHeroID,
            sectionsByID: sectionsByID,
            posterWidth: posterWidth
        )
    }

    /// SectionDivider display name: catalog name with an optional
    /// " - Movie"/" - Series" type suffix, capitalized like Android.
    static func sectionTitle(
        catalogName: String,
        type: String,
        showsTypeSuffix: Bool
    ) -> String {
        let base = catalogName.capitalizingFirstLetter
        guard showsTypeSuffix else { return base }
        let label = typeLabel(type)
        return label.isEmpty ? base : "\(base) - \(label)"
    }

    static func typeLabel(_ type: String) -> String {
        switch type.lowercased() {
        case "movie": return "Movie"
        case "series": return "Series"
        default: return type.capitalizingFirstLetter
        }
    }

    /// The cells a section renders for a concrete column count: the trimmed
    /// content plus its See All card.
    func visibleItems(
        in section: GridHomeSection,
        columns: Int
    ) -> [GridHomeItem] {
        if section.isCollection, let collectionID = section.collectionID {
            return section.folderItems.map {
                .collectionFolder($0, collectionID: collectionID)
            }
        }
        let count = GridHomeGeometry.trimmedContentCount(
            contentCount: section.contentItems.count,
            showsSeeAll: section.hasSeeAll,
            columns: columns,
            rowsPerSection: GridHomeGeometry.rowsPerSection(posterWidth: posterWidth)
        )
        var items = section.contentItems.prefix(count).map(GridHomeItem.content)
        if section.hasSeeAll {
            items.append(.seeAll(sectionID: section.id))
        }
        return items
    }

    func summary(for item: GridHomeItem) -> MetaSummary? {
        guard case .content(let railItem) = item else { return nil }
        return summariesByItemID[railItem.id]
    }

    func summary(for hero: HeroItem) -> MetaSummary? {
        summariesByHeroID[hero.id]
    }

    /// Flat-index mapping for the sticky header, offset by hero, Continue
    /// Watching, and Upcoming rows exactly like the LazyGrid item list.
    func sectionMapping() -> GridSectionMapping {
        var entries: [GridSectionMapping.Entry] = []
        var index = 0
        if !heroes.isEmpty { index += 1 }
        if !continueWatching.isEmpty { index += 1 }
        if !upcoming.isEmpty { index += 1 }
        for section in sections {
            entries.append(
                GridSectionMapping.Entry(startIndex: index, title: section.headerTitle)
            )
            index += 1 + section.visibleItemCount
        }
        return GridSectionMapping(entries: entries)
    }
}

extension String {
    /// Kotlin replaceFirstChar { uppercase } equivalent.
    var capitalizingFirstLetter: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
