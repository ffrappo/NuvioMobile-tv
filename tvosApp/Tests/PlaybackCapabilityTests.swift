import XCTest
@testable import NuvioTV

final class PlaybackCapabilityTests: XCTestCase {
    func testStreamMetadataIsParsedDuringDecode() throws {
        let fixture = #"""
        {
          "name": "UHD 4K HEVC HDR10+ Atmos English",
          "url": "https://video.example/movie.mkv",
          "behaviorHints": {
            "videoSize": 16106127360,
            "filename": "Movie.2160p.DV.x265.5.1.mkv"
          }
        }
        """#.data(using: .utf8)!

        let stream = try JSONDecoder().decode(StremioStream.self, from: fixture)
        XCTAssertEqual(stream.displayInfo.quality, "4K")
        XCTAssertEqual(stream.displayInfo.hdr, "DV")
        XCTAssertEqual(stream.displayInfo.codec, "HEVC")
        XCTAssertEqual(stream.displayInfo.audio, ["Atmos", "5.1"])
        XCTAssertEqual(stream.displayInfo.languages, ["English"])
        XCTAssertEqual(stream.displayInfo.size, "15.0 GB")
    }

    func testAppleTVHDRejectsUnsupportedDirectVideoProfiles() {
        let capabilities = TVPlaybackCapabilities(modelIdentifier: "AppleTV5,3")
        XCTAssertEqual(
            capabilities.compatibility(for: StreamDisplayInfo(quality: "4K")).issue,
            "Requires Apple TV 4K"
        )
        XCTAssertEqual(
            capabilities.compatibility(for: StreamDisplayInfo(quality: "1080p", hdr: "HDR")).issue,
            "Requires Apple TV 4K"
        )
        XCTAssertEqual(
            capabilities.compatibility(for: StreamDisplayInfo(quality: "1080p", codec: "AV1")).issue,
            "Requires newer Apple TV hardware"
        )
        XCTAssertNil(
            capabilities.compatibility(for: StreamDisplayInfo(quality: "1080p", codec: "HEVC")).issue
        )
    }

    func testAppleTV4KKeepsAllParsedProfilesAvailable() {
        let capabilities = TVPlaybackCapabilities(modelIdentifier: "AppleTV14,1")
        XCTAssertNil(
            capabilities.compatibility(
                for: StreamDisplayInfo(quality: "4K", hdr: "DV", codec: "HEVC")
            ).issue
        )
    }

}
