import Foundation

struct CatalogResponse: Decodable {
    let metas: [MetaSummary]

    private enum CodingKeys: String, CodingKey { case metas }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metas = container.decodeLossyArray(MetaSummary.self, forKey: .metas)
    }
}

struct MetaResponse: Decodable {
    let meta: MetaDetail
}

struct StreamResponse: Decodable {
    let streams: [StremioStream]

    private enum CodingKeys: String, CodingKey { case streams }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decodeLossyArray(StremioStream.self, forKey: .streams)
    }
}

struct MetaSummary: Codable, Hashable, Identifiable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let description: String?
    let releaseInfo: String?
    let released: String?
    let genres: [String]

    private enum CodingKeys: String, CodingKey {
        case id, type, name, poster, background, description, releaseInfo, released, genres, genre
    }

    init(
        id: String,
        type: String,
        name: String,
        poster: String? = nil,
        background: String? = nil,
        description: String? = nil,
        releaseInfo: String? = nil,
        released: String? = nil,
        genres: [String] = []
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.poster = poster
        self.background = background
        self.description = description
        self.releaseInfo = releaseInfo
        self.released = released
        self.genres = genres
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleString(forKey: .id) ?? "unknown"
        type = container.decodeFlexibleString(forKey: .type) ?? "movie"
        name = container.decodeFlexibleString(forKey: .name) ?? "Untitled"
        poster = container.decodeFlexibleString(forKey: .poster)
        background = container.decodeFlexibleString(forKey: .background)
        description = container.decodeFlexibleString(forKey: .description)
        releaseInfo = container.decodeFlexibleString(forKey: .releaseInfo)
        released = container.decodeFlexibleString(forKey: .released)
        genres = container.decodeStringArray(forKeys: [.genres, .genre])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(poster, forKey: .poster)
        try container.encodeIfPresent(background, forKey: .background)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(releaseInfo, forKey: .releaseInfo)
        try container.encodeIfPresent(released, forKey: .released)
        try container.encode(genres, forKey: .genres)
    }
}

struct MetaDetail: Decodable, Identifiable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let description: String?
    let releaseInfo: String?
    let released: String?
    let runtime: String?
    let imdbRating: String?
    let genres: [String]
    let videos: [StremioVideo]

    private enum CodingKeys: String, CodingKey {
        case id, type, name, poster, background, description, releaseInfo
        case released, runtime, imdbRating, genres, genre, videos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleString(forKey: .id) ?? "unknown"
        type = container.decodeFlexibleString(forKey: .type) ?? "movie"
        name = container.decodeFlexibleString(forKey: .name) ?? "Untitled"
        poster = container.decodeFlexibleString(forKey: .poster)
        background = container.decodeFlexibleString(forKey: .background)
        description = container.decodeFlexibleString(forKey: .description)
        releaseInfo = container.decodeFlexibleString(forKey: .releaseInfo)
        released = container.decodeFlexibleString(forKey: .released)
        runtime = container.decodeFlexibleString(forKey: .runtime)
        imdbRating = container.decodeFlexibleString(forKey: .imdbRating)
        genres = container.decodeStringArray(forKeys: [.genres, .genre])
        videos = container.decodeLossyArray(StremioVideo.self, forKey: .videos)
    }

    var summary: MetaSummary {
        MetaSummary(
            id: id,
            type: type,
            name: name,
            poster: poster,
            background: background,
            description: description,
            releaseInfo: releaseInfo,
            released: released,
            genres: genres
        )
    }
}

struct StremioVideo: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let season: Int?
    let episode: Int?
    let released: String?
    let description: String?
    let thumbnail: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, title, season, episode, number, released
        case description, overview, thumbnail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleString(forKey: .id) ?? "unknown-video"
        name = container.decodeFlexibleString(forKey: .name)
            ?? container.decodeFlexibleString(forKey: .title)
            ?? "Episode"
        season = container.decodeFlexibleInt(forKey: .season)
        episode = container.decodeFlexibleInt(forKey: .episode)
            ?? container.decodeFlexibleInt(forKey: .number)
        released = container.decodeFlexibleString(forKey: .released)
        description = container.decodeFlexibleString(forKey: .description)
            ?? container.decodeFlexibleString(forKey: .overview)
        thumbnail = container.decodeFlexibleString(forKey: .thumbnail)
    }

    var label: String {
        if let season, let episode { return "S\(season) E\(episode)  \(name)" }
        return name
    }
}

struct StremioStream: Decodable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let title: String?
    let description: String?
    let url: String?
    let requestHeaders: [String: String]

    private enum CodingKeys: String, CodingKey { case name, title, description, url, behaviorHints }
    private enum BehaviorHintKeys: String, CodingKey { case proxyHeaders }
    private enum ProxyHeaderKeys: String, CodingKey { case request }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = container.decodeFlexibleString(forKey: .name)
            ?? container.decodeFlexibleString(forKey: .title)
            ?? "Unnamed source"
        title = container.decodeFlexibleString(forKey: .title)
        description = container.decodeFlexibleString(forKey: .description)
        url = container.decodeFlexibleString(forKey: .url)
        let hints = try? container.nestedContainer(keyedBy: BehaviorHintKeys.self, forKey: .behaviorHints)
        let proxy = try? hints?.nestedContainer(keyedBy: ProxyHeaderKeys.self, forKey: .proxyHeaders)
        requestHeaders = (try? proxy?.decode([String: String].self, forKey: .request)) ?? [:]
    }

    var directURL: URL? {
        guard let url, let value = URL(string: url), let scheme = value.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return value
    }
}

struct AddonManifest: Decodable {
    let id: String
    let name: String
    let description: String?
    let version: String?
    let resources: [ManifestResource]
    let catalogs: [AddonCatalog]
    let types: [String]
    let idPrefixes: [String]
    let logoURL: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, version, resources, catalogs, types, idPrefixes
        case logoURL = "logo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleString(forKey: .id) ?? "unknown-addon"
        name = container.decodeFlexibleString(forKey: .name) ?? "Unnamed addon"
        description = container.decodeFlexibleString(forKey: .description)
        version = container.decodeFlexibleString(forKey: .version)
        resources = container.decodeLossyArray(ManifestResource.self, forKey: .resources)
        catalogs = container.decodeLossyArray(AddonCatalog.self, forKey: .catalogs)
        types = (try? container.decode([String].self, forKey: .types)) ?? []
        idPrefixes = (try? container.decode([String].self, forKey: .idPrefixes)) ?? []
        logoURL = container.decodeFlexibleString(forKey: .logoURL)
    }

    var providesStreams: Bool {
        resources.contains { $0.name == "stream" }
    }
}

struct ManifestResource: Decodable {
    let name: String
    let types: [String]
    let idPrefixes: [String]

    private enum CodingKeys: String, CodingKey { case name, types, idPrefixes }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            name = value
            types = []
            idPrefixes = []
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeFlexibleString(forKey: .name) ?? "unknown"
        types = (try? container.decode([String].self, forKey: .types)) ?? []
        idPrefixes = (try? container.decode([String].self, forKey: .idPrefixes)) ?? []
    }
}

struct AddonCatalog: Decodable, Hashable {
    let type: String
    let id: String
    let name: String
    let extra: [AddonExtra]

    private enum CodingKeys: String, CodingKey { case type, id, name, extra }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeFlexibleString(forKey: .type) ?? "movie"
        id = container.decodeFlexibleString(forKey: .id) ?? "top"
        name = container.decodeFlexibleString(forKey: .name) ?? "Catalog"
        extra = container.decodeLossyArray(AddonExtra.self, forKey: .extra)
    }
}

struct AddonExtra: Decodable, Hashable {
    let name: String
    let isRequired: Bool
    let options: [String]

    private enum CodingKeys: String, CodingKey { case name, isRequired, options }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeFlexibleString(forKey: .name) ?? ""
        isRequired = (try? container.decode(Bool.self, forKey: .isRequired)) ?? false
        options = (try? container.decode([String].self, forKey: .options)) ?? []
    }
}

struct HomeAddon {
    let baseURL: String
    let name: String
    let manifest: AddonManifest
}

struct AddonEndpoint: Codable, Hashable, Identifiable {
    let baseURL: String
    let name: String
    let detail: String?
    let providesStreams: Bool

    var id: String { baseURL }
}

struct StreamSource: Identifiable, Hashable {
    let addonName: String
    let stream: StremioStream

    var id: UUID { stream.id }
}

struct StreamFetchReport {
    let sources: [StreamSource]
    let failures: [String]
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeStringArray(forKeys keys: [Key]) -> [String] {
        for key in keys {
            if let values = try? decode([String].self, forKey: key) {
                return values
            }
            if let value = try? decode(String.self, forKey: key) {
                return [value]
            }
        }
        return []
    }

    func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        guard let values = try? decode([Lossy<T>].self, forKey: key) else { return [] }
        return values.compactMap(\.value)
    }
}

private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
