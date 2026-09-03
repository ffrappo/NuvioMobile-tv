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

    /// Android `canonicalSubtitleType`: "tv" canonicalizes to "series".
    static func canonicalType(_ raw: String) -> String {
        raw.lowercased() == "tv" ? "series" : raw.lowercased()
    }

    /// Returns external track rows across all matching addons, in addon
    /// order, tagged with the addon name like the Android overlay. Addons
    /// are queried in parallel with a 20 s per-addon bound, and the
    /// filename/videoSize extras from the playing stream are forwarded
    /// (`buildExtraParams`) for hash/size-based subtitle addons.
    func externalTracks(
        type rawType: String,
        id: String,
        videoID: String?,
        addons: [AddonEndpoint],
        filename: String? = nil,
        videoSize: Int64? = nil
    ) async -> [SubtitleExternalTrack] {
        let type = Self.canonicalType(rawType)
        let targetID = videoID?.isEmpty == false ? videoID! : id

        let matching = addons.filter { addon in
            addon.manifest.map(Self.providesSubtitles) == true
                && Self.matches(addon: addon, type: type, id: targetID)
        }

        // One child task per addon with a 20 s bound, like the Android
        // parallel fetch; each result comes back tagged with its addon
        // position so completion order does not shuffle the rows.
        let outcomes = await withTaskGroup(
            of: AddonSubtitleOutcome.self
        ) { group in
            for (index, addon) in matching.enumerated() {
                group.addTask { [service] in
                    let tracks = await Self.withTimeout(seconds: 20) {
                        try await Self.fetch(
                            service: service,
                            addon: addon,
                            type: type,
                            targetID: targetID,
                            filename: filename,
                            videoSize: videoSize
                        )
                    } ?? []
                    return AddonSubtitleOutcome(index: index, tracks: tracks)
                }
            }
            var results: [AddonSubtitleOutcome] = []
            for await outcome in group {
                results.append(outcome)
            }
            return results
        }
        // Preserve addon order regardless of completion order.
        return outcomes
            .sorted { $0.index < $1.index }
            .flatMap(\.tracks)
    }

    private struct AddonSubtitleOutcome: Sendable {
        let index: Int
        let tracks: [SubtitleExternalTrack]
    }

    private static func fetch(
        service: StremioService,
        addon: AddonEndpoint,
        type: String,
        targetID: String,
        filename: String?,
        videoSize: Int64?
    ) async throws -> [SubtitleExternalTrack] {
        var extra: [String] = []
        if let videoSize {
            extra.append("videoSize=\(videoSize)")
        }
        if let filename, !filename.isEmpty {
            let encoded = filename.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            )?.replacingOccurrences(of: "+", with: "%20") ?? filename
            extra.append("filename=\(encoded)")
        }
        let url = try AddonTransport.resourceURL(
            baseURL: addon.baseURL,
            resource: "subtitles",
            type: type,
            id: targetID,
            extra: extra
        )
        let response: AddonSubtitlesResponse = try await service.request(url)
        return (response.subtitles ?? []).compactMap { entry in
            guard let entryURL = entry.url, !entryURL.isEmpty else { return nil }
            let language = entry.lang?.isEmpty == false ? entry.lang! : "und"
            let externalID = entry.id?.isEmpty == false ? entry.id! : "\(language)-\(entryURL.hashValue)"
            return SubtitleExternalTrack(
                addonName: addon.name,
                language: language,
                externalID: externalID,
                url: entryURL,
                isSelected: false
            )
        }
    }

    /// `isSubtitleResource` + type/idPrefix matching.
    static func providesSubtitles(_ manifest: AddonManifest) -> Bool {
        manifest.resources.contains { resource in
            resource.name.lowercased() == "subtitles" || resource.name.lowercased() == "subtitle"
        }
    }

    /// Races the operation against a deadline; nil on timeout or error.
    private static func withTimeout<T: Sendable>(
        seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { try? await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func matches(addon: AddonEndpoint, type: String, id: String) -> Bool {
        guard let manifest = addon.manifest else { return false }
        let resource = manifest.resources.first {
            $0.name.lowercased() == "subtitles" || $0.name.lowercased() == "subtitle"
        }
        if let resource, !resource.types.isEmpty {
            let matchesType = resource.types.contains { entry in
                canonicalType(entry) == type
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
