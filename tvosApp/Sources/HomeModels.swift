import Foundation

struct HomeCatalogDefinition: Hashable, Identifiable {
    let addonBaseURL: String
    let addonID: String
    let addonName: String
    let type: String
    let catalogID: String
    let catalogName: String
    let supportsPagination: Bool

    var id: String { "\(addonID):\(type):\(catalogID)" }
    var defaultTitle: String { "\(catalogName) - \(type.capitalized)" }
}

struct HomeCatalogSection: Identifiable, Equatable {
    let definition: HomeCatalogDefinition
    let items: [MetaSummary]
    var id: String { definition.id }
    var title: String { definition.catalogName }
}

struct HomeCatalogPreference: Codable, Equatable {
    let key: String
    var enabled: Bool
    var order: Int
    var customTitle: String
}

struct HomePreferences: Codable, Equatable {
    var heroEnabled = true
    var showCatalogType = true
    var hideUnreleasedContent = false
    var items: [HomeCatalogPreference] = []

    func preference(for key: String) -> HomeCatalogPreference? {
        items.first { $0.key == key }
    }
}

struct HomeSnapshot: Equatable {
    var heroItems: [MetaSummary] = []
    var sections: [HomeCatalogSection] = []
    var continueWatching: [ContinueWatchingCard] = []
    var upcoming: [ContinueWatchingCard] = []
    var collections: [TVCollection] = []
    var isLoading = false
    var message: String?
    var isOffline = false

    var hasContent: Bool {
        !heroItems.isEmpty || !sections.isEmpty || !continueWatching.isEmpty ||
            !upcoming.isEmpty || collections.contains { !$0.folders.isEmpty }
    }
}

struct ContinueWatchingCard: Identifiable, Equatable {
    let id: String
    let summary: MetaSummary
    let videoID: String
    let season: Int?
    let episode: Int?
    let episodeTitle: String?
    let episodeThumbnail: String?
    let released: String?
    let positionMilliseconds: Int64
    let durationMilliseconds: Int64
    let lastWatchedMilliseconds: Int64
    let isUpcoming: Bool

    var progress: Double {
        guard durationMilliseconds > 0 else { return 0 }
        return min(max(Double(positionMilliseconds) / Double(durationMilliseconds), 0), 1)
    }
}

struct TVCollection: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let backdropImageUrl: String?
    let pinToTop: Bool
    let folders: [TVCollectionFolder]
}

struct TVCollectionFolder: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let coverImageUrl: String?
    let tileShape: String
    let hideTitle: Bool
    let sources: [TVCollectionSource]
}

struct TVCollectionSource: Codable, Equatable {
    let provider: String
    let addonId: String?
    let type: String?
    let catalogId: String?
    let genre: String?
    let title: String?
    let tmdbSourceType: String?
    let tmdbId: Int?
    let traktListId: Int64?
    let mediaType: String?
    let sortBy: String?
    let sortHow: String?
}

struct TVProfile: Codable, Equatable, Identifiable {
    let id: String
    let profileIndex: Int
    let name: String
    let avatarColorHex: String
    let avatarURL: String?
    let usesPrimaryAddons: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case profileIndex = "profile_index"
        case avatarColorHex = "avatar_color_hex"
        case avatarURL = "avatar_url"
        case usesPrimaryAddons = "uses_primary_addons"
    }
}
