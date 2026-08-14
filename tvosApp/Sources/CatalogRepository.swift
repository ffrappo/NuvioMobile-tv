import Foundation

actor CatalogRepository {
    static let shared = CatalogRepository()

    private struct CachedPage {
        let page: CatalogPage
        let storedAt: Date
    }

    private let service: StremioService
    private let cacheLifetime: TimeInterval
    private var cache: [String: CachedPage] = [:]
    private var inFlight: [String: Task<CatalogPage, Error>] = [:]

    init(
        service: StremioService = StremioService(),
        cacheLifetime: TimeInterval = 10 * 60
    ) {
        self.service = service
        self.cacheLifetime = cacheLifetime
    }

    func firstPage(
        of descriptor: CatalogDescriptor,
        query: String? = nil,
        ignoringCache: Bool = false
    ) async throws -> CatalogPage {
        try await page(of: descriptor, skip: 0, query: query, ignoringCache: ignoringCache)
    }

    func searchPage(
        of descriptor: CatalogDescriptor,
        query: String
    ) async throws -> CatalogPage {
        try Task.checkCancellation()
        let key = cacheKey(descriptor: descriptor, skip: 0, query: query)
        if let cached = cache[key],
           Date().timeIntervalSince(cached.storedAt) < cacheLifetime {
            return cached.page
        }
        let result = try await loadPage(descriptor: descriptor, skip: 0, query: query)
        cache[key] = CachedPage(page: result, storedAt: Date())
        return result
    }

    func nextPage(of listing: CatalogListing) async throws -> CatalogPage? {
        guard let skip = listing.nextSkip else { return nil }
        return try await page(of: listing.descriptor, skip: skip)
    }

    func clearCache() {
        cache.removeAll()
    }

    private func page(
        of descriptor: CatalogDescriptor,
        skip: Int,
        query: String? = nil,
        ignoringCache: Bool = false
    ) async throws -> CatalogPage {
        try Task.checkCancellation()
        let key = cacheKey(descriptor: descriptor, skip: skip, query: query)
        if !ignoringCache,
           let cached = cache[key],
           Date().timeIntervalSince(cached.storedAt) < cacheLifetime {
            return cached.page
        }
        if let task = inFlight[key] { return try await task.value }

        let task = Task<CatalogPage, Error> { [self] in
            try await loadPage(descriptor: descriptor, skip: skip, query: query)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        do {
            let result = try await task.value
            cache[key] = CachedPage(page: result, storedAt: Date())
            return result
        } catch {
            throw error
        }
    }

    private func loadPage(
        descriptor: CatalogDescriptor,
        skip: Int,
        query: String?
    ) async throws -> CatalogPage {
        let rawItems = try await service.catalog(
            baseURL: descriptor.baseURL,
            type: descriptor.type,
            id: descriptor.catalogID,
            query: query,
            genre: descriptor.genre,
            skip: skip > 0 ? skip : nil
        )
        try Task.checkCancellation()
        let items = rawItems.map { $0.withMetadataBaseURL(descriptor.baseURL) }
        let nextSkip = Self.nextSkip(
            currentSkip: skip,
            supportsPagination: descriptor.supportsPagination,
            receivedCount: items.count
        )
        return CatalogPage(items: items, nextSkip: nextSkip)
    }

    private func cacheKey(
        descriptor: CatalogDescriptor,
        skip: Int,
        query: String?
    ) -> String {
        "\(descriptor.id)|skip=\(skip)|query=\(query ?? "")"
    }

    static func nextSkip(
        currentSkip: Int,
        supportsPagination: Bool,
        receivedCount: Int
    ) -> Int? {
        guard supportsPagination, receivedCount > 0 else { return nil }
        return currentSkip + receivedCount
    }
}
