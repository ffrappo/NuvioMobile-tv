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
    var items: [MetaSummary]
    var nextSkip: Int?
    var id: String { definition.id }
    var title: String { definition.catalogName }

    init(definition: HomeCatalogDefinition, items: [MetaSummary], nextSkip: Int? = nil) {
        self.definition = definition
        self.items = items
        self.nextSkip = nextSkip
    }
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

    var syncJSONObject: [String: Any] {
        [
            "show_catalog_type": showCatalogType,
            "hide_unreleased_content": hideUnreleasedContent,
            "items": items.map { item in
                [
                    "addon_id": item.key.split(separator: ":").first.map(String.init) ?? "",
                    "type": item.key.split(separator: ":").dropFirst().first.map(String.init) ?? "",
                    "catalog_id": item.key.split(separator: ":").dropFirst(2).first.map(String.init) ?? "",
                    "enabled": item.enabled,
                    "order": item.order,
                    "custom_title": item.customTitle,
                    "is_collection": item.key.hasPrefix("collection_"),
                    "collection_id": item.key.hasPrefix("collection_") ? String(item.key.dropFirst("collection_".count)) : "",
                    "key": item.key,
                ] as [String: Any]
            },
        ]
    }

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
    var watchedContentKeys: Set<String> = []
    var loadingSectionIDs: Set<String> = []

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

struct TVCollection: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
    let backdropImageUrl: String?
    let pinToTop: Bool
    let folders: [TVCollectionFolder]

    private enum CodingKeys: String, CodingKey {
        case id, title, backdropImageUrl, pinToTop, folders
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Collection"
        backdropImageUrl = try values.decodeIfPresent(String.self, forKey: .backdropImageUrl)
        pinToTop = try values.decodeIfPresent(Bool.self, forKey: .pinToTop) ?? false
        folders = try values.decodeIfPresent([TVCollectionFolder].self, forKey: .folders) ?? []
    }
}

struct TVCollectionFolder: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
    let coverImageUrl: String?
    let tileShape: String
    let hideTitle: Bool
    let sources: [TVCollectionSource]

    private enum CodingKeys: String, CodingKey {
        case id, title, coverImageUrl, tileShape, hideTitle, sources, catalogSources
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Folder"
        coverImageUrl = try values.decodeIfPresent(String.self, forKey: .coverImageUrl)
        tileShape = try values.decodeIfPresent(String.self, forKey: .tileShape) ?? "poster"
        hideTitle = try values.decodeIfPresent(Bool.self, forKey: .hideTitle) ?? false
        sources = try values.decodeIfPresent([TVCollectionSource].self, forKey: .sources)
            ?? values.decodeIfPresent([TVCollectionSource].self, forKey: .catalogSources)
            ?? []
    }
}

struct TVCollectionSource: Decodable, Equatable, Hashable {
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

    private enum CodingKeys: String, CodingKey {
        case provider, addonId, type, catalogId, genre, title, tmdbSourceType
        case tmdbId, traktListId, mediaType, sortBy, sortHow
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        provider = try values.decodeIfPresent(String.self, forKey: .provider) ?? "addon"
        addonId = try values.decodeIfPresent(String.self, forKey: .addonId)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        catalogId = try values.decodeIfPresent(String.self, forKey: .catalogId)
        genre = try values.decodeIfPresent(String.self, forKey: .genre)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        tmdbSourceType = try values.decodeIfPresent(String.self, forKey: .tmdbSourceType)
        tmdbId = try values.decodeIfPresent(Int.self, forKey: .tmdbId)
        traktListId = try values.decodeFlexibleInt64IfPresent(forKey: .traktListId)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        sortBy = try values.decodeIfPresent(String.self, forKey: .sortBy)
        sortHow = try values.decodeIfPresent(String.self, forKey: .sortHow)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt64IfPresent(forKey key: Key) throws -> Int64? {
        if let value = try? decode(Int64.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Int64(value) }
        return nil
    }
}

/// Full profile schema (`SupabaseProfile`): fields beyond the original
/// tvOS subset fall back to the Android data-class defaults.
struct TVProfile: Decodable, Equatable, Identifiable {
    static let maxProfiles = 6
    static let primaryProfileID = 1

    let id: String
    let profileIndex: Int
    var name: String
    var avatarColorHex: String
    var avatarID: String?
    var avatarURL: String?
    var profileBackgroundID: String?
    var profileBackgroundURL: String?
    var usesPrimaryAddons: Bool
    var usesPrimaryPlugins: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case profileIndex = "profile_index"
        case avatarColorHex = "avatar_color_hex"
        case avatarID = "avatar_id"
        case avatarURL = "avatar_url"
        case profileBackgroundID = "profile_background_id"
        case profileBackgroundURL = "profile_background_url"
        case usesPrimaryAddons = "uses_primary_addons"
        case usesPrimaryPlugins = "uses_primary_plugins"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
        profileIndex = try values.decodeIfPresent(Int.self, forKey: .profileIndex) ?? 1
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Profile"
        avatarColorHex = try values.decodeIfPresent(String.self, forKey: .avatarColorHex) ?? "#1E88E5"
        avatarID = try values.decodeIfPresent(String.self, forKey: .avatarID)
        avatarURL = try values.decodeIfPresent(String.self, forKey: .avatarURL)
        profileBackgroundID = try values.decodeIfPresent(String.self, forKey: .profileBackgroundID)
        profileBackgroundURL = try values.decodeIfPresent(String.self, forKey: .profileBackgroundURL)
        usesPrimaryAddons = try values.decodeIfPresent(Bool.self, forKey: .usesPrimaryAddons) ?? false
        usesPrimaryPlugins = try values.decodeIfPresent(Bool.self, forKey: .usesPrimaryPlugins) ?? false
    }

    init(
        id: String = "",
        profileIndex: Int,
        name: String,
        avatarColorHex: String = "#1E88E5",
        avatarID: String? = nil,
        avatarURL: String? = nil,
        profileBackgroundID: String? = nil,
        profileBackgroundURL: String? = nil,
        usesPrimaryAddons: Bool = false,
        usesPrimaryPlugins: Bool = false
    ) {
        self.id = id
        self.profileIndex = profileIndex
        self.name = name
        self.avatarColorHex = avatarColorHex
        self.avatarID = avatarID
        self.avatarURL = avatarURL
        self.profileBackgroundID = profileBackgroundID
        self.profileBackgroundURL = profileBackgroundURL
        self.usesPrimaryAddons = usesPrimaryAddons
        self.usesPrimaryPlugins = usesPrimaryPlugins
    }

    var isPrimary: Bool { profileIndex == Self.primaryProfileID }
}
