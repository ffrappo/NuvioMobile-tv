import Foundation

actor DetailsRepository {
    static let shared = DetailsRepository()

    private struct Entry {
        let detail: MetaDetail
        let storedAt: Date
    }

    private let service: StremioService
    private let lifetime: TimeInterval
    private var cache: [String: Entry] = [:]
    private var inFlight: [String: Task<MetaDetail, Error>] = [:]

    init(service: StremioService = StremioService(), lifetime: TimeInterval = 15 * 60) {
        self.service = service
        self.lifetime = lifetime
    }

    func detail(for summary: MetaSummary, ignoringCache: Bool = false) async throws -> MetaDetail {
        let baseURL = summary.metadataBaseURL ?? StremioService.cinemetaBaseURL.absoluteString
        let key = "\(baseURL)|\(summary.type)|\(summary.id)"
        if !ignoringCache,
           let cached = cache[key],
           Date().timeIntervalSince(cached.storedAt) < lifetime {
            return cached.detail
        }
        if let task = inFlight[key] { return try await task.value }
        let task = Task<MetaDetail, Error> { [service] in
            try await service.details(type: summary.type, id: summary.id, baseURL: baseURL)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let detail = try await task.value
        cache[key] = Entry(detail: detail, storedAt: Date())
        return detail
    }
}
