import Foundation

/// Android parity: hero previews enrich with metadata details (logo, IMDb
/// rating, runtime) fetched on demand from the metadata addon. The store
/// caches results per content key and collapses concurrent requests.
@MainActor
final class HeroEnrichmentStore: ObservableObject {
    struct Enrichment: Equatable, Sendable {
        let titleLogoURL: String?
        let imdbRating: String?
        let runtimeMinutes: Int?

        init(titleLogoURL: String?, imdbRating: String?, runtimeMinutes: Int?) {
            self.titleLogoURL = titleLogoURL
            self.imdbRating = imdbRating
            self.runtimeMinutes = runtimeMinutes
        }

        init(detail: MetaDetail) {
            self.init(
                titleLogoURL: detail.logo?.trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmptyValue,
                imdbRating: detail.imdbRating?.trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmptyValue,
                runtimeMinutes: HeroEnrichmentStore.runtimeMinutes(from: detail.runtime)
            )
        }
    }

    @Published private(set) var cache: [String: Enrichment] = [:]

    private var inFlight: [String: Task<Void, Never>] = [:]
    private let fetchDetails: (String, String, String?) async throws -> MetaDetail

    init(
        fetchDetails: @escaping (String, String, String?) async throws -> MetaDetail = {
            type, id, baseURL in
            try await StremioService().details(
                type: type,
                id: id,
                baseURL: baseURL ?? StremioService.cinemetaBaseURL.absoluteString
            )
        }
    ) {
        self.fetchDetails = fetchDetails
    }

    func enrich(_ summary: MetaSummary) {
        let key = Self.contentKey(type: summary.type, id: summary.id)
        guard cache[key] == nil, inFlight[key] == nil else { return }
        inFlight[key] = Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight[key] = nil }
            do {
                let detail = try await self.fetchDetails(
                    summary.type,
                    summary.id,
                    summary.metadataBaseURL
                )
                self.cache[key] = Enrichment(detail: detail)
            } catch {
                // Failed lookups stay uncached so a later focus can retry.
            }
        }
    }

    /// True when the content key already carries enrichment data.
    func hasEnrichment(forKey key: String) -> Bool {
        cache[key] != nil
    }

    func hasInFlightWork() -> Bool {
        !inFlight.isEmpty
    }

    /// Merges cached enrichment into a hero item without overwriting fields
    /// the presentation already populated.
    func heroItem(byMerging base: HeroItem) -> HeroItem {
        guard let enrichment = cache[base.id] else { return base }
        return HeroItem(
            id: base.id,
            title: base.title,
            titleLogoURL: base.titleLogoURL ?? enrichment.titleLogoURL,
            backdropURL: base.backdropURL,
            overview: base.overview,
            year: base.year,
            runtimeMinutes: base.runtimeMinutes ?? enrichment.runtimeMinutes,
            genres: base.genres,
            classification: base.classification,
            imdbRating: base.imdbRating ?? enrichment.imdbRating,
            badges: base.badges
        )
    }

    static func contentKey(type: String, id: String) -> String {
        "\(type):\(id)"
    }

    /// Stremio addons report runtime as minutes ("118"); tolerate
    /// decorated forms such as "118 min" or "1h 58m".
    nonisolated static func runtimeMinutes(from value: String?) -> Int? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue?.lowercased()
        else { return nil }
        if let plain = Int(value) {
            return plain
        }
        if value.hasSuffix(" min") {
            return Int(value.dropLast(4).trimmingCharacters(in: .whitespaces))
        }
        let pattern = try? NSRegularExpression(pattern: #"(\d+)\s*h(?:\s*(\d+)\s*m)?"#)
        if let match = pattern?.firstMatch(
            in: value, range: NSRange(value.startIndex..., in: value)
        ), let hours = capture(value, match, 1) {
            let minutes = capture(value, match, 2) ?? 0
            return hours * 60 + minutes
        }
        return nil
    }

    nonisolated private static func capture(_ value: String, _ match: NSTextCheckingResult, _ group: Int) -> Int? {
        guard match.range(at: group).location != NSNotFound,
              let range = Range(match.range(at: group), in: value)
        else { return nil }
        return Int(value[range])
    }
}

private extension String {
    var nonEmptyValue: String? { isEmpty ? nil : self }
}
