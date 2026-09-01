import Foundation

// MARK: - Presentation

/// Immutable, SwiftUI-free projection of an Android `MetaDetailsScreen`.
public struct DetailsPresentation {
    public let hero: DetailsHeroModel
    public let seasons: [DetailsSeasonTab]
    public let continueTargetEpisodeID: String?
    public let castSection: DetailsCastSectionModel?
    public let similarSection: DetailsRailSectionModel?
    public let collectionSection: DetailsCollectionSectionModel?
    public let networkCompanies: [DetailsCompanyItem]
    public let productionCompanies: [DetailsCompanyItem]
    public let commentsHeader: DetailsCommentsHeaderModel
    public let trailerItems: [DetailsTrailerItemModel]
    public let isSeries: Bool

    private let episodesBySeason: [Int: [DetailsEpisodeItem]]

    /// Internal because `MetaDetail` is module-internal; the integrator
    /// composes this library from inside the app module.
    init(
        meta: MetaDetail,
        watchedEpisodeIDs: Set<String> = [],
        completedEpisodeIDs: Set<String> = [],
        progressByEpisodeID: [String: Double] = [:],
        episodeRatings: [DetailsEpisodeKey: Double] = [:],
        ageRating: String? = nil,
        status: String? = nil,
        highlightText: String? = nil,
        similar: [MetaSummary] = [],
        collectionName: String? = nil,
        collection: [MetaSummary] = [],
        networks: [DetailsCompanyItem] = [],
        productionCompanies: [DetailsCompanyItem] = [],
        trailers: [DetailsTrailerInput] = [],
        showFullReleaseDate: Bool = true
    ) {
        let isSeries = DetailsMetaFormatter.isSeriesType(meta.type)
        self.isSeries = isSeries

        let runtimeText = DetailsMetaFormatter.formatRuntime(meta.runtime)
        let yearText = DetailsMetaFormatter.yearText(
            type: meta.type,
            releaseInfo: meta.releaseInfo,
            released: meta.released,
            showFullReleaseDate: showFullReleaseDate
        )
        let imdbText = meta.imdbRating?
            .trimmingCharacters(in: .whitespaces)
        hero = DetailsHeroModel(
            title: meta.name,
            logoURLString: Self.nonBlank(meta.logo),
            backdropURLString: Self.nonBlank(meta.background) ?? Self.nonBlank(meta.poster),
            posterURLString: Self.nonBlank(meta.poster),
            overview: Self.nonBlank(meta.description),
            primaryLeadingTexts: Self.primaryLeadingTexts(meta: meta),
            primaryTrailingTexts: [runtimeText, yearText].compactMap { $0 },
            imdbRatingText: imdbText?.isEmpty == false ? imdbText : nil,
            secondaryHighlightText: Self.nonBlank(highlightText),
            ageRatingText: Self.nonBlank(ageRating),
            statusBadgeText: DetailsStatusMapper.badge(status: status, isSeries: isSeries),
            languageText: Self.nonBlank(meta.language)?.uppercased(),
            yearText: yearText,
            runtimeText: runtimeText
        )

        let (seasons, episodesBySeason, continueTarget) = Self.buildEpisodes(
            videos: meta.videos,
            watchedEpisodeIDs: watchedEpisodeIDs,
            completedEpisodeIDs: completedEpisodeIDs,
            progressByEpisodeID: progressByEpisodeID,
            episodeRatings: episodeRatings
        )
        self.seasons = seasons
        self.episodesBySeason = episodesBySeason
        self.continueTargetEpisodeID = continueTarget

        castSection = Self.buildCast(meta: meta)
        similarSection = Self.buildRail(
            title: "More like this",
            sourceLabel: nil,
            items: similar
        )
        collectionSection = Self.buildCollection(name: collectionName, items: collection)
        networkCompanies = networks
        self.productionCompanies = productionCompanies
        commentsHeader = DetailsCommentsHeaderModel(title: "Comments", subtitle: "Reviews from Trakt")
        trailerItems = trailers.compactMap(Self.trailerItem)
    }

    public func episodes(season: Int) -> [DetailsEpisodeItem] {
        episodesBySeason[season] ?? []
    }

    // MARK: builders

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func primaryLeadingTexts(meta: MetaDetail) -> [String] {
        var texts: [String] = []
        let contentType = DetailsMetaFormatter.contentTypeLabel(meta.type)
        if !contentType.isEmpty { texts.append(contentType) }
        if let genre = meta.genres.first, !genre.trimmingCharacters(in: .whitespaces).isEmpty {
            texts.append(DetailsGenreLabels.label(for: genre))
        }
        return texts
    }

    private static func buildEpisodes(
        videos: [StremioVideo],
        watchedEpisodeIDs: Set<String>,
        completedEpisodeIDs: Set<String>,
        progressByEpisodeID: [String: Double],
        episodeRatings: [DetailsEpisodeKey: Double]
    ) -> (seasons: [DetailsSeasonTab], bySeason: [Int: [DetailsEpisodeItem]], continueTarget: String?) {
        var seen = Set<String>()
        let ordered = videos.filter { video in
            guard video.season != nil, video.episode != nil, !seen.contains(video.id) else { return false }
            seen.insert(video.id)
            return true
        }.sorted { lhs, rhs in
            if lhs.season != rhs.season { return (lhs.season ?? 0) < (rhs.season ?? 0) }
            return (lhs.episode ?? 0) < (rhs.episode ?? 0)
        }

        // EpisodeWatchedProjection parity: watched episodes keep their marker;
        // the first unwatched episode becomes the continue target.
        let continueTarget = ordered.first { video in
            guard (video.season ?? 0) > 0 else { return false }
            return !(watchedEpisodeIDs.contains(video.id) || completedEpisodeIDs.contains(video.id))
        }?.id

        var bySeason: [Int: [DetailsEpisodeItem]] = [:]
        for video in ordered {
            guard let season = video.season, let episode = video.episode else { continue }
            let watched = watchedEpisodeIDs.contains(video.id) || completedEpisodeIDs.contains(video.id)
            let rawProgress = progressByEpisodeID[video.id]
            let progress: Double? = {
                guard !watched, let rawProgress, rawProgress > 0 else { return nil }
                return min(max(rawProgress, 0), 1)
            }()
            let rating = episodeRatings[DetailsEpisodeKey(season: season, episode: episode)]
            bySeason[season, default: []].append(DetailsEpisodeItem(
                id: video.id,
                season: season,
                episode: episode,
                title: video.name,
                overview: nonBlank(video.description),
                thumbnailURLString: nonBlank(video.thumbnail),
                airDateText: DetailsMetaFormatter.episodeDateText(video.released),
                runtimeMinutes: (video.runtime ?? 0) > 0 ? video.runtime : nil,
                isWatched: watched,
                progressFraction: progress,
                imdbRatingText: rating.map { String(format: "%.1f", $0) },
                isContinueTarget: video.id == continueTarget
            ))
        }

        let seasonNumbers = bySeason.keys.sorted { lhs, rhs in
            if lhs == 0 { return false }
            if rhs == 0 { return true }
            return lhs < rhs
        }
        let tabs = seasonNumbers.map { season in
            DetailsSeasonTab(
                season: season,
                label: season == 0 ? "Specials" : "Season \(season)",
                episodeCount: bySeason[season]?.count ?? 0
            )
        }
        return (tabs, bySeason, continueTarget)
    }

    private static func buildCast(meta: MetaDetail) -> DetailsCastSectionModel? {
        let directors = meta.director.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let writers = meta.writer.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let leadingRole = !directors.isEmpty ? "Director" : (!writers.isEmpty ? "Writer" : nil)
        let leadingNames = !directors.isEmpty ? directors : writers
        let leading = leadingNames.map { name in
            DetailsCastMemberModel(id: "leading|\(name.lowercased())", name: name, roleLabel: leadingRole, photoURLString: nil)
        }
        let leadingKeys = Set(leadingNames.map { $0.lowercased() })
        let castNames = meta.cast
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !leadingKeys.contains($0.lowercased()) }
        let cast = castNames.enumerated().map { index, name in
            DetailsCastMemberModel(id: "cast|\(index)|\(name.lowercased())", name: name, roleLabel: nil, photoURLString: nil)
        }
        let model = DetailsCastSectionModel(
            leadingMembers: leading,
            castMembers: cast,
            directorNames: directors,
            writerNames: writers
        )
        return model.isVisible ? model : nil
    }

    private static func posterItem(_ meta: MetaSummary) -> DetailsPosterItemModel {
        DetailsPosterItemModel(
            id: meta.id,
            title: meta.name,
            subtitle: meta.releaseInfo,
            posterURLString: meta.poster,
            backdropURLString: meta.background ?? meta.poster
        )
    }

    private static func buildRail(title: String, sourceLabel: String?, items: [MetaSummary]) -> DetailsRailSectionModel? {
        guard !items.isEmpty else { return nil }
        return DetailsRailSectionModel(
            title: title,
            sourceLabel: sourceLabel,
            items: items.map(posterItem)
        )
    }

    private static func buildCollection(name: String?, items: [MetaSummary]) -> DetailsCollectionSectionModel? {
        guard !items.isEmpty else { return nil }
        return DetailsCollectionSectionModel(
            title: name?.isEmpty == false ? name! : "Collection",
            items: items.map(posterItem)
        )
    }

    private static func trailerItem(_ input: DetailsTrailerInput) -> DetailsTrailerItemModel? {
        let url = nonBlank(input.url) ?? input.ytID.map { "https://www.youtube.com/watch?v=\($0)" }
        guard let url else { return nil }
        let thumbnail = input.ytID.map { "https://img.youtube.com/vi/\($0)/hqdefault.jpg" }
        var subtitleParts: [String] = []
        if let sourceName = nonBlank(input.sourceName) { subtitleParts.append(sourceName) }
        if let language = nonBlank(input.languageCode) { subtitleParts.append(language.uppercased()) }
        return DetailsTrailerItemModel(
            id: input.ytID ?? input.id,
            title: nonBlank(input.title) ?? "Trailer",
            subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " • "),
            thumbnailURLString: thumbnail,
            url: url
        )
    }
}
