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

    private func source(named name: String) throws -> String {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("Sources/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
