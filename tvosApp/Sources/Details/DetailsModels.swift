import Foundation

/// Episode lookup key matching Android's `Pair<Int, Int>` season/episode maps.
public struct DetailsEpisodeKey: Hashable, Sendable {
    public let season: Int
    public let episode: Int

    public init(season: Int, episode: Int) {
        self.season = season
        self.episode = episode
    }
}

/// Input data for a trailer entry. `MetaDetail` does not carry trailers, so the
/// integrator supplies them; the presentation only projects displayable rows.
public struct DetailsTrailerInput: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let sourceName: String?
    public let languageCode: String?
    public let url: String?
    public let ytID: String?

    public init(
        id: String,
        title: String? = nil,
        sourceName: String? = nil,
        languageCode: String? = nil,
        url: String? = nil,
        ytID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.languageCode = languageCode
        self.url = url
        self.ytID = ytID
    }
}

/// Company / network logo entry (MetaDetail does not carry these).
public struct DetailsCompanyItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let logoURLString: String?

    public init(id: String? = nil, name: String, logoURLString: String? = nil) {
        self.id = id ?? name
        self.name = name
        self.logoURLString = logoURLString
    }
}
// MARK: - Section models

public struct DetailsHeroModel: Equatable, Sendable {
    public let title: String
    public let logoURLString: String?
    public let backdropURLString: String?
    public let posterURLString: String?
    public let overview: String?
    /// Leading primary row: content type + first localized genre.
    public let primaryLeadingTexts: [String]
    /// Trailing primary row: runtime + year.
    public let primaryTrailingTexts: [String]
    public let imdbRatingText: String?
    public let secondaryHighlightText: String?
    public let ageRatingText: String?
    public let statusBadgeText: String?
    public let languageText: String?
    public let yearText: String?
    public let runtimeText: String?

    public var hasSecondaryMeta: Bool {
        secondaryHighlightText != nil || ageRatingText != nil ||
            statusBadgeText != nil || languageText != nil
    }
}

public struct DetailsCastMemberModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let roleLabel: String?
    public let photoURLString: String?

    public var initials: String {
        String(name.prefix(1)).uppercased()
    }
}

public struct DetailsCastSectionModel: Equatable, Sendable {
    public let leadingMembers: [DetailsCastMemberModel]
    public let castMembers: [DetailsCastMemberModel]
    public let directorNames: [String]
    public let writerNames: [String]

    public var isVisible: Bool {
        !leadingMembers.isEmpty || !castMembers.isEmpty
    }
}

public struct DetailsPosterItemModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let posterURLString: String?
    public let backdropURLString: String?
}

public struct DetailsRailSectionModel: Equatable, Sendable {
    public let title: String
    public let sourceLabel: String?
    public let items: [DetailsPosterItemModel]

    public var isVisible: Bool { !items.isEmpty }
}

public struct DetailsCollectionSectionModel: Equatable, Sendable {
    public let title: String
    public let items: [DetailsPosterItemModel]

    public var isVisible: Bool { !items.isEmpty }
}

public struct DetailsTrailerItemModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let thumbnailURLString: String?
    public let url: String
}

public struct DetailsCommentsHeaderModel: Equatable, Sendable {
    public let title: String
    public let subtitle: String
}

public struct DetailsSeasonTab: Identifiable, Equatable, Sendable {
    public let season: Int
    public let label: String
    public let episodeCount: Int

    public var id: Int { season }
}

public struct DetailsEpisodeItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let season: Int
    public let episode: Int
    public let title: String
    public let overview: String?
    public let thumbnailURLString: String?
    public let airDateText: String?
    public let runtimeMinutes: Int?
    public let isWatched: Bool
    public let progressFraction: Double?
    public let imdbRatingText: String?
    public let isContinueTarget: Bool
}
