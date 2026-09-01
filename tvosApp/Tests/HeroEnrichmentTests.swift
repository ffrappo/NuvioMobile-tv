import XCTest
@testable import NuvioTV

@MainActor
final class HeroEnrichmentTests: XCTestCase {
    func testRuntimeMinutesParsesStremioForms() {
        XCTAssertEqual(HeroEnrichmentStore.runtimeMinutes(from: "118"), 118)
        XCTAssertEqual(HeroEnrichmentStore.runtimeMinutes(from: " 98 "), 98)
        XCTAssertEqual(HeroEnrichmentStore.runtimeMinutes(from: "118 min"), 118)
        XCTAssertEqual(HeroEnrichmentStore.runtimeMinutes(from: "1h 58m"), 118)
        XCTAssertEqual(HeroEnrichmentStore.runtimeMinutes(from: "2h"), 120)
        XCTAssertNil(HeroEnrichmentStore.runtimeMinutes(from: nil))
        XCTAssertNil(HeroEnrichmentStore.runtimeMinutes(from: ""))
        XCTAssertNil(HeroEnrichmentStore.runtimeMinutes(from: "soon"))
    }

    func testMergeFillsMissingFieldsWithoutOverwriting() async {
        let base = HeroItem(
            id: "movie:tt1",
            title: "Kept",
            titleLogoURL: "https://example.test/kept-logo.png",
            runtimeMinutes: 101,
            badges: ["Movie"]
        )
        let store = HeroEnrichmentStore(fetchDetails: { _, _, _ in
            MetaDetail.fixture(
                id: "tt1",
                logo: "https://example.test/detail-logo.png",
                imdbRating: "7.8",
                runtime: "118"
            )
        })
        store.enrich(MetaSummary(id: "tt1", type: "movie", name: "Kept"))
        await awaitStoreIdle(store)

        let merged = store.heroItem(byMerging: base)
        XCTAssertEqual(merged.titleLogoURL, "https://example.test/kept-logo.png")
        XCTAssertEqual(merged.runtimeMinutes, 101)
        XCTAssertEqual(merged.imdbRating, "7.8")
    }

    func testEnrichCachesAndSkipsRepeatFetches() async throws {
        let stub = FetchStub(
            result: .success(
                MetaDetail.fixture(id: "tt1", logo: "https://example.test/logo.png", imdbRating: "8.1", runtime: "120")
            )
        )
        let store = HeroEnrichmentStore(fetchDetails: { type, id, _ in try await stub.fetch(type: type, id: id) })
        let summary = MetaSummary(id: "tt1", type: "movie", name: "One")

        store.enrich(summary)
        store.enrich(summary)
        await awaitStoreIdle(store)
        store.enrich(summary)
        await awaitStoreIdle(store)

        let callCount = await stub.callCount()
        XCTAssertEqual(callCount, 1, "Cached and in-flight keys must not refetch")
        XCTAssertEqual(store.cache["movie:tt1"]?.imdbRating, "8.1")
        XCTAssertTrue(store.hasEnrichment(forKey: "movie:tt1"))
    }

    func testFailedLookupStaysUncachedForRetry() async throws {
        let stub = FetchStub(result: .failure(URLError(.badServerResponse)))
        let store = HeroEnrichmentStore(fetchDetails: { type, id, _ in try await stub.fetch(type: type, id: id) })
        let summary = MetaSummary(id: "tt1", type: "movie", name: "One")

        store.enrich(summary)
        await awaitStoreIdle(store)
        XCTAssertFalse(store.hasEnrichment(forKey: "movie:tt1"))

        await stub.setResult(.success(
            MetaDetail.fixture(id: "tt1", logo: nil, imdbRating: "6.5", runtime: nil)
        ))
        store.enrich(summary)
        await awaitStoreIdle(store)
        XCTAssertEqual(store.cache["movie:tt1"]?.imdbRating, "6.5")
    }

    /// Awaits until all in-flight enrichment tasks have settled.
    private func awaitStoreIdle(_ store: HeroEnrichmentStore) async {
        while store.hasInFlightWork() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
        await Task.yield()
    }
}

private actor FetchStub {
    enum Result {
        case success(MetaDetail)
        case failure(Error)
    }

    var result: Result
    private(set) var calls: [(type: String, id: String)] = []

    init(result: Result) {
        self.result = result
    }

    func callCount() -> Int { calls.count }

    func setResult(_ newResult: Result) {
        result = newResult
    }

    func fetch(type: String, id: String) async throws -> MetaDetail {
        calls.append((type, id))
        try? await Task.sleep(for: .milliseconds(10))
        switch result {
        case .success(let detail): return detail
        case .failure(let error): throw error
        }
    }
}

extension MetaDetail {
    static func fixture(
        id: String,
        logo: String?,
        imdbRating: String?,
        runtime: String?
    ) -> MetaDetail {
        let json = """
        {"id":"\(id)","type":"movie","name":"Fixture","logo":"\(logo ?? "")",
         "imdbRating":"\(imdbRating ?? "")","runtime":"\(runtime ?? "")"}
        """
        return try! JSONDecoder().decode(MetaDetail.self, from: Data(json.utf8))
    }
}
