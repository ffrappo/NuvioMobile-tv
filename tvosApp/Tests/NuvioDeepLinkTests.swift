import XCTest
@testable import NuvioTV

final class NuvioDeepLinkTests: XCTestCase {
    func testDetailsRoundTripPreservesTypeAndID() throws {
        let url = try XCTUnwrap(NuvioDeepLink.detailsURL(type: "series", id: "tt11198330"))
        let link = try XCTUnwrap(NuvioDeepLink(url: url))
        XCTAssertEqual(link.destination, .details(type: "series", id: "tt11198330"))
    }

    func testRejectsUnknownSchemeOrDestination() {
        XCTAssertNil(NuvioDeepLink(url: URL(string: "https://example.com/details?id=tt1")!))
        XCTAssertNil(NuvioDeepLink(url: URL(string: "nuvio://search?id=tt1")!))
    }

    func testRejectsMissingDetailsParameters() {
        XCTAssertNil(NuvioDeepLink(url: URL(string: "nuvio://details?type=movie")!))
        XCTAssertNil(NuvioDeepLink(url: URL(string: "nuvio://details?id=tt1")!))
    }
}
