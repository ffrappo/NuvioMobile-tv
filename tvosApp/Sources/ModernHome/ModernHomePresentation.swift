import Foundation

struct ModernHomePresentation: Equatable {
    let heroes: [HeroItem]
    let catalogRows: [RailSection]
    let summariesByRailID: [String: MetaSummary]
    let summariesByHeroID: [String: MetaSummary]
    let sectionsByID: [String: HomeCatalogSection]

    static func build(
        snapshot: HomeSnapshot,
        preferences: HomePreferences
    ) -> ModernHomePresentation {
        var summariesByRailID: [String: MetaSummary] = [:]
        var summariesByHeroID: [String: MetaSummary] = [:]
        for summary in snapshot.heroItems + snapshot.sections.flatMap(\.items) {
            summariesByHeroID[heroItemID(summary)] = summary
        }
        let heroItems = Self.heroPages(
            heroItems: snapshot.heroItems,
            sections: snapshot.sections
        )

        let rows = snapshot.sections.map { section in
            let title = preferences.preference(for: section.id)?.customTitle.trimmedNonEmpty
                ?? section.title
            let items = section.items.map { summary in
                let railID = railItemID(sectionID: section.id, summary: summary)
                summariesByRailID[railID] = summary
                return RailItem(
                    id: railID,
                    title: summary.name,
                    year: summary.releaseInfo?.trimmedNonEmpty,
                    overview: summary.description?.trimmedNonEmpty,
                    metadata: [section.definition.addonName, summary.type.capitalized],
                    posterArtwork: artworkSource(summary.poster),
                    backdropArtwork: artworkSource(summary.background ?? summary.poster),
                    status: PosterCardStatus(
                        isWatched: snapshot.watchedContentKeys.contains(
                            "\(summary.type.lowercased()):\(summary.id)"
                        )
                    )
                )
            }
            return RailSection(
                id: section.id,
                title: title,
                items: items,
                hasMore: section.nextSkip != nil,
                isLoading: snapshot.loadingSectionIDs.contains(section.id)
                    || (snapshot.isLoading && items.isEmpty)
            )
        }
        return ModernHomePresentation(
            heroes: heroItems,
            catalogRows: rows,
            summariesByRailID: summariesByRailID,
            summariesByHeroID: summariesByHeroID,
            sectionsByID: Dictionary(uniqueKeysWithValues: snapshot.sections.map { ($0.id, $0) })
        )
    }

    func summary(for item: RailItem) -> MetaSummary? {
        summariesByRailID[item.id]
    }

    func summary(for hero: HeroItem) -> MetaSummary? {
        summariesByHeroID[hero.id]
    }

    func heroPage(for item: RailItem) -> HeroItem? {
        guard let summary = summary(for: item) else { return nil }
        let pageID = Self.heroItemID(summary)
        return heroes.first { $0.id == pageID } ?? HeroItem(summary)
    }

    /// Android parity: the rotating hero set is bounded (the slot shuffle in
    /// HomeViewModelCatalogPipeline caps at 7 pages) so the page indicator
    /// stays compact instead of drawing one dot per catalog item.
    static let heroPageLimit = 7

    private static func heroPages(
        heroItems: [MetaSummary],
        sections: [HomeCatalogSection]
    ) -> [HeroItem] {
        var seen = Set<String>()
        var pages: [HeroItem] = []
        func append(_ summary: MetaSummary) {
            guard pages.count < heroPageLimit,
                  seen.insert(heroItemID(summary)).inserted
            else { return }
            pages.append(HeroItem(summary))
        }

        heroItems.forEach(append)
        let artworkColumns = sections.map { section in
            section.items.filter(\.hasHeroArtwork)
        }
        for round in 0..<(artworkColumns.map(\.count).max() ?? 0) {
            for column in artworkColumns where round < column.count {
                append(column[round])
            }
        }
        if pages.count < heroPageLimit {
            sections.flatMap(\.items).forEach(append)
        }
        return pages
    }

    private static func railItemID(sectionID: String, summary: MetaSummary) -> String {
        "\(sectionID)|\(summary.type)|\(summary.id)"
    }

    private static func heroItemID(_ summary: MetaSummary) -> String {
        "\(summary.type):\(summary.id)"
    }

    private static func artworkSource(_ value: String?) -> PosterArtworkSource {
        guard let value = value?.trimmedNonEmpty, let url = URL(string: value) else {
            return .placeholder(systemName: "film")
        }
        return .url(url)
    }
}

private extension MetaSummary {
    var hasHeroArtwork: Bool {
        guard let background else { return false }
        return background.trimmedNonEmpty != nil
    }
}

private extension HeroItem {
    init(_ summary: MetaSummary) {
        self.init(
            id: "\(summary.type):\(summary.id)",
            title: summary.name,
            backdropURL: summary.background ?? summary.poster,
            overview: summary.description,
            year: summary.releaseInfo?.trimmedNonEmpty,
            genres: summary.genres,
            badges: [summary.type.capitalized]
        )
    }
}
