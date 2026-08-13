import XCTest
@testable import NuvioTV

final class RepositoryConcurrencyTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.clear()
        super.tearDown()
    }

    func testCatalogRepositoryCoalescesConcurrentPages() async throws {
        let count = LockedCounter()
        TestURLProtocol.setHandler { _ in
            count.increment()
            return .init(
                statusCode: 200,
                data: Data(#"{"metas":[{"id":"tt1","type":"movie","name":"One"}]}"#.utf8),
                delay: .milliseconds(80)
            )
        }
        let repository = CatalogRepository(
            service: StremioService(session: TestURLProtocol.session()),
            cacheLifetime: 600
        )
        let descriptor = descriptor()
        async let first = repository.firstPage(of: descriptor)
        async let second = repository.firstPage(of: descriptor)
        let pages = try await [first, second]
        XCTAssertEqual(pages.map(\.items.count), [1, 1])
        XCTAssertEqual(count.value, 1)
    }

    func testCatalogRepositoryUsesAndClearsCache() async throws {
        let count = LockedCounter()
        TestURLProtocol.setHandler { _ in
            count.increment()
            return .init(
                statusCode: 200,
                data: Data(#"{"metas":[{"id":"tt1","type":"movie","name":"One"}]}"#.utf8),
                delay: .zero
            )
        }
        let repository = CatalogRepository(
            service: StremioService(session: TestURLProtocol.session()),
            cacheLifetime: 600
        )
        _ = try await repository.firstPage(of: descriptor())
        _ = try await repository.firstPage(of: descriptor())
        XCTAssertEqual(count.value, 1)
        await repository.clearCache()
        _ = try await repository.firstPage(of: descriptor())
        XCTAssertEqual(count.value, 2)
    }

    private func descriptor() -> CatalogDescriptor {
        CatalogDescriptor(
            baseURL: "https://example.test", addonID: "test", addonName: "Test",
            type: "movie", catalogID: "top", catalogName: "Top", genre: nil,
            genres: [], supportsPagination: true
        )
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}


final class CatalogModelTests: XCTestCase {
    func testSearchCatalogDescriptorsUseEveryCompatibleAddonCatalog() throws {
        let first = try manifest(from: #"""
        {"id":"one","name":"One","catalogs":[
          {"type":"movie","id":"searchable","name":"Movies","extra":[{"name":"search","isRequired":true}]},
          {"type":"series","id":"browse","name":"Series","extra":[{"name":"skip"}]}
        ]}
        """#)
        let second = try manifest(from: #"""
        {"id":"two","name":"Two","catalogs":[
          {"type":"series","id":"lookup","name":"Shows","extra":[{"name":"search"}]},
          {"type":"movie","id":"blocked","name":"Blocked","extra":[{"name":"search"},{"name":"token","isRequired":true}]}
        ]}
        """#)
        let descriptors = CatalogDescriptors.search(from: [
            HomeAddon(baseURL: "https://one.example", name: "One", manifest: first),
            HomeAddon(baseURL: "https://two.example", name: "Two", manifest: second),
        ])
        XCTAssertEqual(descriptors.map(\.catalogID), ["searchable", "lookup"])
        XCTAssertEqual(descriptors.map(\.type), ["movie", "series"])
    }

    func testSearchCatalogDescriptorsFallBackToCinemeta() {
        let descriptors = CatalogDescriptors.search(from: [])
        XCTAssertEqual(descriptors.map(\.addonName), ["Cinemeta", "Cinemeta"])
        XCTAssertEqual(descriptors.map(\.type), ["movie", "series"])
        XCTAssertTrue(descriptors.allSatisfy { !$0.supportsPagination })
    }

    func testBrowseCatalogDescriptorsResolveRequiredGenre() throws {
        let manifest = try manifest(from: #"""
        {"id":"browse","name":"Browse","catalogs":[
          {"type":"movie","id":"popular","name":"Popular","extra":[{"name":"skip"}]},
          {"type":"series","id":"genre","name":"By Genre","extra":[{"name":"genre","isRequired":true,"options":["Drama","Comedy"]}]},
          {"type":"movie","id":"search-only","name":"Search","extra":[{"name":"search","isRequired":true}]},
          {"type":"movie","id":"token","name":"Token","extra":[{"name":"token","isRequired":true}]}
        ]}
        """#)
        let descriptors = CatalogDescriptors.browse(from: [
            HomeAddon(baseURL: "https://browse.example", name: "Browse", manifest: manifest),
        ])
        XCTAssertEqual(descriptors.map(\.catalogID), ["popular", "genre"])
        XCTAssertEqual(descriptors.map(\.genre), [nil, "Drama"])
        XCTAssertEqual(descriptors.last?.genres, ["Drama", "Comedy"])
        XCTAssertEqual(descriptors.map(\.supportsPagination), [true, false])
    }

    func testCatalogURLCarriesSkipAfterGenre() throws {
        let url = try AddonTransport.catalogURL(
            baseURL: "https://example.com/addon",
            type: "movie",
            id: "popular",
            genre: "Science Fiction",
            skip: 40
        )
        XCTAssertEqual(
            url.absoluteString,
            "https://example.com/addon/catalog/movie/popular/genre=Science%20Fiction&skip=40.json"
        )
    }

    func testCatalogPaginationAdvancesByActualPageSize() {
        XCTAssertEqual(
            CatalogRepository.nextSkip(currentSkip: 40, supportsPagination: true, receivedCount: 17),
            57
        )
        XCTAssertNil(CatalogRepository.nextSkip(
            currentSkip: 40,
            supportsPagination: false,
            receivedCount: 17
        ))
        XCTAssertNil(CatalogRepository.nextSkip(
            currentSkip: 40,
            supportsPagination: true,
            receivedCount: 0
        ))
    }

    func testCatalogListingPreservesProviderIdentity() {
        let descriptor = CatalogDescriptor(
            baseURL: "https://example.com/addon", addonID: "addon", addonName: "Example",
            type: "movie", catalogID: "popular", catalogName: "Popular", genre: nil,
            genres: [], supportsPagination: true
        )
        let listing = CatalogListing(
            descriptor: descriptor,
            items: [MetaSummary(id: "tt1", type: "movie", name: "One")],
            nextSkip: 1
        )
        XCTAssertEqual(listing.metadataBaseURL, "https://example.com/addon")
        XCTAssertEqual(listing.displaySubtitle, "Example · Movie")
        XCTAssertTrue(listing.canLoadMore)
    }

    private func manifest(from fixture: String) throws -> AddonManifest {
        try JSONDecoder().decode(AddonManifest.self, from: Data(fixture.utf8))
    }
}
