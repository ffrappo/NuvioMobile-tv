import XCTest
@testable import NuvioTV

final class StremioServiceTests: XCTestCase {
    func testManifestURLNormalization() throws {
        let base = try StremioService.normalizeManifestURL(
            " https://example.com/config/user/manifest.json?token=ignored "
        )
        XCTAssertEqual(base.absoluteString, "https://example.com/config/user")
    }

    func testBaseURLNormalization() throws {
        let base = try StremioService.normalizeManifestURL("https://example.com/addon/")
        XCTAssertEqual(base.absoluteString, "https://example.com/addon")
    }

    func testBaseURLNormalizationPreservesQueryCredentials() throws {
        let base = try StremioService.normalizeManifestURL("https://example.com/addon/manifest.json?token=secret")
        XCTAssertEqual(base.absoluteString, "https://example.com/addon?token=secret")
    }

    func testAddonTransportBuildsCatalogURLAndPreservesQuery() throws {
        let url = try AddonTransport.catalogURL(
            baseURL: "https://example.com/config/user?token=secret",
            type: "movie",
            id: "top picks",
            genre: "Science Fiction"
        )
        XCTAssertEqual(
            url.absoluteString,
            "https://example.com/config/user/catalog/movie/top%20picks/genre=Science%20Fiction.json?token=secret"
        )
    }

    func testCatalogFixtureToleratesMissingAndMixedFields() throws {
        let fixture = #"""
        {
          "metas": [
            {"id": 42, "name": "Example", "type": "movie", "releaseInfo": 2026, "genre": "Drama"},
            {"id": "tt2", "name": "Second"},
            "malformed entry"
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder().decode(CatalogResponse.self, from: fixture)
        XCTAssertEqual(response.metas.count, 2)
        XCTAssertEqual(response.metas[0].id, "42")
        XCTAssertEqual(response.metas[0].releaseInfo, "2026")
        XCTAssertEqual(response.metas[0].genres, ["Drama"])
        XCTAssertEqual(response.metas[1].type, "movie")
    }

    func testManifestDecodesHomeEligibilityFields() throws {
        let fixture = #"""
        {
          "id": "addon.test", "name": "Test", "types": ["movie"],
          "resources": [{"name":"catalog","types":["movie"],"idPrefixes":["tt"]}],
          "catalogs": [{"type":"movie","id":"top","name":"Top","extra":[{"name":"skip","isRequired":false}]}]
        }
        """#.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(AddonManifest.self, from: fixture)
        XCTAssertEqual(manifest.types, ["movie"])
        XCTAssertEqual(manifest.resources.first?.types, ["movie"])
        XCTAssertEqual(manifest.catalogs.first?.extra.first?.name, "skip")
        XCTAssertFalse(manifest.catalogs.first?.extra.first?.isRequired ?? true)
    }

    func testReleaseFilterRemovesFutureDateAndYear() {
        let now = ISO8601DateFormatter().date(from: "2026-08-11T12:00:00Z")!
        let items = [
            MetaSummary(id: "a", type: "movie", name: "Released", releaseInfo: "2025"),
            MetaSummary(id: "b", type: "movie", name: "Future year", releaseInfo: "2027"),
            MetaSummary(id: "c", type: "movie", name: "Future date", released: "2026-12-01")
        ]
        XCTAssertEqual(HomeReleaseFilter.releasedItems(items, enabled: true, now: now).map(\.id), ["a"])
    }

    func testUpcomingResolverChoosesNextEpisodeAcrossSeasonBoundary() {
        let fixture = #"""
        {"meta":{"id":"tt1","type":"series","name":"Show","videos":[
          {"id":"tt1:1:2","name":"Two","season":1,"episode":2},
          {"id":"tt1:2:1","name":"New Season","season":2,"episode":1}
        ]}}
        """#.data(using: .utf8)!
        let detail = try! JSONDecoder().decode(MetaResponse.self, from: fixture).meta
        let record = WatchProgressRecord(
            contentID: "tt1", contentType: "series", videoID: "tt1:1:2", season: 1, episode: 2,
            position: 900, duration: 1_000, lastWatched: 1, progressKey: "tt1_s1e2",
            summary: detail.summary, episodeTitle: nil, episodeThumbnail: nil
        )
        XCTAssertEqual(HomeUpcomingResolver.nextEpisode(after: record, videos: detail.videos)?.id, "tt1:2:1")
    }

    func testSearchPathPercentEncoding() throws {
        let url = try StremioService.catalogURL(
            type: "movie",
            id: "top",
            query: "The Matrix \u{0026} Neo/Trinity"
        )
        XCTAssertEqual(
            url.absoluteString,
            "https://v3-cinemeta.strem.io/catalog/movie/top/search=The%20Matrix%20%26%20Neo%2FTrinity.json"
        )
    }

    func testSidebarAndContentAreDeclaredAsFocusSections() throws {
        let shell = try source(named: "AppShellView.swift")
        XCTAssertEqual(shell.components(separatedBy: ".focusSection()").count - 1, 2)
        XCTAssertFalse(shell.contains(".onMoveCommand"))
    }

    func testPlaybackProgressResumeRules() {
        XCTAssertNil(PlaybackProgress(position: 10, duration: 100, updatedAt: Date()).resumablePosition)
        XCTAssertEqual(
            PlaybackProgress(position: 25, duration: 100, updatedAt: Date()).resumablePosition,
            25
        )
        XCTAssertNil(PlaybackProgress(position: 95, duration: 100, updatedAt: Date()).resumablePosition)
    }

    func testPlayerTimeFormatter() {
        XCTAssertEqual(PlayerTimeFormatter.string(65), "01:05")
        XCTAssertEqual(PlayerTimeFormatter.string(3_661), "1:01:01")
    }

    func testStreamDecodesProxyRequestHeaders() throws {
        let fixture = #"""
        {
          "name": "Protected source",
          "url": "https://video.example/movie.m3u8",
          "behaviorHints": {
            "proxyHeaders": {
              "request": {"Referer": "https://example.com", "X-Token": "secret"}
            }
          }
        }
        """#.data(using: .utf8)!

        let stream = try JSONDecoder().decode(StremioStream.self, from: fixture)
        XCTAssertEqual(stream.requestHeaders["Referer"], "https://example.com")
        XCTAssertEqual(stream.requestHeaders["X-Token"], "secret")
    }

    private func source(named name: String) throws -> String {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("Sources/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
