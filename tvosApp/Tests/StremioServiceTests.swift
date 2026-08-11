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

    func testSidebarFocusRouterEntersContentOnlyWhenMovingRight() {
        XCTAssertTrue(SidebarFocusRouter.shouldEnterContent(.right))
        XCTAssertFalse(SidebarFocusRouter.shouldEnterContent(.left))
        XCTAssertFalse(SidebarFocusRouter.shouldEnterContent(.up))
        XCTAssertFalse(SidebarFocusRouter.shouldEnterContent(.down))
    }
}
