import Foundation

/// One row of a Stremio addon `subtitles` response.
struct AddonSubtitleEntry: Decodable, Sendable {
    let id: String?
    let url: String?
    let lang: String?

    enum CodingKeys: String, CodingKey { case id, url, lang, language }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        url = try values.decodeIfPresent(String.self, forKey: .url)
        lang = try values.decodeIfPresent(String.self, forKey: .lang)
            ?? values.decodeIfPresent(String.self, forKey: .language)
    }
}

struct AddonSubtitlesResponse: Decodable, Sendable {
    let subtitles: [AddonSubtitleEntry]?
}

/// Fetches external subtitles from installed Stremio addons that declare a
/// `subtitles` resource (Android `SubtitleRepositoryImpl`): one request per
/// addon at `{base}/subtitles/{type}/{videoID}.json`.
struct AddonSubtitleRepository {
    private let service: StremioService

    init(service: StremioService = StremioService()) {
        self.service = service
    }

    /// Returns external track rows across all matching addons, in addon
    /// order, tagged with the addon name like the Android overlay.
    func externalTracks(
        type: String,
        id: String,
        videoID: String?,
        addons: [AddonEndpoint]
    ) async -> [SubtitleExternalTrack] {
        let targetID = videoID?.isEmpty == false ? videoID! : id
        var tracks: [SubtitleExternalTrack] = []
        for addon in addons {
            guard addon.manifest.map(Self.providesSubtitles) == true else { continue }
            guard Self.matches(addon: addon, type: type, id: targetID) else { continue }
            do {
                let url = try AddonTransport.resourceURL(
                    baseURL: addon.baseURL,
                    resource: "subtitles",
                    type: type,
                    id: targetID
                )
                let response: AddonSubtitlesResponse = try await service.request(url)
                for entry in response.subtitles ?? [] {
                    guard let entryURL = entry.url, !entryURL.isEmpty else { continue }
                    let language = entry.lang?.isEmpty == false ? entry.lang! : "und"
                    let externalID = entry.id?.isEmpty == false ? entry.id! : "\(language)-\(entryURL.hashValue)"
                    tracks.append(SubtitleExternalTrack(
                        addonName: addon.name,
                        language: language,
                        externalID: externalID,
                        url: entryURL,
                        isSelected: false
                    ))
                }
            } catch {
                // A single addon failing must not break the rest.
                AppLog.provider.debug(
                    "Addon subtitles failed addon=\(addon.name, privacy: .public) detail=\(AppLog.safeDescription(error), privacy: .public)"
                )
            }
        }
        return tracks
    }

    /// `isSubtitleResource` + type/idPrefix matching.
    static func providesSubtitles(_ manifest: AddonManifest) -> Bool {
        manifest.resources.contains { resource in
            resource.name.lowercased() == "subtitles" || resource.name.lowercased() == "subtitle"
        }
    }

    private static func matches(addon: AddonEndpoint, type: String, id: String) -> Bool {
        guard let manifest = addon.manifest else { return false }
        let resource = manifest.resources.first {
            $0.name.lowercased() == "subtitles" || $0.name.lowercased() == "subtitle"
        }
        if let resource, !resource.types.isEmpty {
            let normalized = type.lowercased()
            let isSeries = normalized == "series"
            let matchesType = resource.types.contains { entry in
                let candidate = entry.lowercased()
                return candidate == normalized || (isSeries && candidate == "tv")
                    || (!isSeries && normalized == "tv" && candidate == "movie")
            }
            if !matchesType { return false }
        }
        let prefixes = (resource?.idPrefixes.isEmpty == false ? resource?.idPrefixes : manifest.idPrefixes) ?? []
        if !prefixes.isEmpty, !prefixes.contains(where: { id.hasPrefix($0) }) {
            return false
        }
        return true
    }
}
