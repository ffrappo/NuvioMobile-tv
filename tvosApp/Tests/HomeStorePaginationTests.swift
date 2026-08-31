import XCTest
@testable import NuvioTV

@MainActor
final class HomeStorePaginationTests: XCTestCase {
    private var suiteName: String!
    private var suite: UserDefaults!
    private var counter: RequestCounter!

    override func setUp() {
        super.setUp()
        suiteName = "HomeStorePaginationTests-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        counter = RequestCounter()
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        super.tearDown()
    }

    func testLoadMoreAppendsPagesDeduplicatesAndStopsAtRepetition() async throws {
        TestURLProtocol.setHandler { [weak counter] request in
            guard let counter else { fatalError("counter released") }
            counter.increment()
            // Stremio addons encode pagination as a path segment: skip=N.json
            let segment = request.url?.path.split(separator: "/").last.map(String.init) ?? ""
            let skip = segment.hasPrefix("skip=")
                ? String(segment.dropFirst("skip=".count)).replacingOccurrences(of: ".json", with: "")
                : nil
            let metas: String
            switch skip {
            case nil:
                metas = #"[{"id":"tt1","type":"movie","name":"One"},{"id":"tt2","type":"movie","name":"Two"}]"#
            case "2":
                metas = #"[{"id":"tt3","type":"movie","name":"Three"},{"id":"tt4","type":"movie","name":"Four"}]"#
            default:
                // The catalog repeats; dedup must end pagination here.
                metas = #"[{"id":"tt1","type":"movie","name":"One"},{"id":"tt2","type":"movie","name":"Two"}]"#
            }
            return .init(
                statusCode: 200,
                data: Data(#"{"metas":\#(metas)}"#.utf8),
                delay: .zero
            )
        }
        let store = makeStore()
        await store.load(addons: [addon()], auth: AuthStore(defaults: suite), profileID: 1)
        let sectionID = try XCTUnwrap(store.snapshot.sections.first?.id)
        XCTAssertEqual(
            store.snapshot.sections.first?.items.map(\.name),
            ["One", "Two"]
        )
        XCTAssertEqual(store.snapshot.sections.first?.nextSkip, 2)

        await store.loadMore(sectionID: sectionID)
        XCTAssertEqual(
            store.snapshot.sections.first?.items.map(\.name),
            ["One", "Two", "Three", "Four"]
        )
        XCTAssertEqual(store.snapshot.sections.first?.nextSkip, 4)

        // The repeating page contributes nothing new, so pagination ends.
        await store.loadMore(sectionID: sectionID)
        XCTAssertEqual(
            store.snapshot.sections.first?.items.map(\.name),
            ["One", "Two", "Three", "Four"]
        )
        XCTAssertNil(store.snapshot.sections.first?.nextSkip)
        XCTAssertFalse(store.snapshot.loadingSectionIDs.contains(sectionID))

        let requestsAfterEnd = counter.value
        await store.loadMore(sectionID: sectionID)
        XCTAssertEqual(counter.value, requestsAfterEnd, "Ended sections must not fetch again")
    }

    func testLoadMoreIgnoresInFlightDuplicates() async throws {
        TestURLProtocol.setHandler { [weak counter] request in
            guard let counter else { fatalError("counter released") }
            counter.increment()
            let path = request.url?.path ?? ""
            let metas = path.contains("/skip=")
                ? #"{"metas":[{"id":"tt3","type":"movie","name":"Three"},{"id":"tt4","type":"movie","name":"Four"}]}"#
                : #"{"metas":[{"id":"tt1","type":"movie","name":"One"},{"id":"tt2","type":"movie","name":"Two"}]}"#
            return .init(
                statusCode: 200,
                data: Data(metas.utf8),
                delay: .milliseconds(80)
            )
        }
        let store = makeStore()
        await store.load(addons: [addon()], auth: AuthStore(defaults: suite), profileID: 1)
        let sectionID = try XCTUnwrap(store.snapshot.sections.first?.id)

        let first = Task { await store.loadMore(sectionID: sectionID) }
        let second = Task { await store.loadMore(sectionID: sectionID) }
        _ = await (first.value, second.value)

        XCTAssertEqual(
            store.snapshot.sections.first?.items.map(\.name),
            ["One", "Two", "Three", "Four"]
        )
        XCTAssertEqual(counter.value, 2, "Duplicate concurrent prefetch must coalesce to one page request")
    }

    private func makeStore() -> HomeStore {
        let repository = CatalogRepository(
            service: StremioService(session: TestURLProtocol.session()),
            cacheLifetime: 0
        )
        return HomeStore(
            preferences: HomePreferencesStore(defaults: suite),
            progress: WatchProgressStore(defaults: suite),
            collections: CollectionStore(repository: repository),
            repository: repository
        )
    }

    private func addon() -> HomeAddon {
        let manifest = try! JSONDecoder().decode(
            AddonManifest.self,
            from: Data("""
            {"id":"catalog","name":"Catalog","catalogs":[
              {"type":"movie","id":"popular","name":"Popular","extra":[{"name":"skip"}]}
            ]}
            """.utf8)
        )
        return HomeAddon(baseURL: "https://catalog.example", name: "Catalog", manifest: manifest)
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
