import XCTest
@testable import NuvioTV

final class PlayerFeatureTests: XCTestCase {
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

    func testTimelineScrubbingScalesWithLongContent() {
        XCTAssertEqual(
            TimelineScrubModel.destination(
                current: 0, duration: 7_200, direction: 1, heldFor: 0
            ),
            60
        )
        XCTAssertEqual(
            TimelineScrubModel.destination(
                current: 60, duration: 7_200, direction: 1, heldFor: 1.5
            ),
            360
        )
        XCTAssertEqual(
            TimelineScrubModel.destination(
                current: 360, duration: 7_200, direction: 1, heldFor: 3
            ),
            960
        )
    }

    func testTimelineSwipeMapsToDurationAndClamps() {
        XCTAssertEqual(
            TimelineScrubModel.position(start: 3_600, duration: 7_200, normalizedTranslation: 0.5),
            7_200
        )
        XCTAssertEqual(
            TimelineScrubModel.position(start: 300, duration: 7_200, normalizedTranslation: -0.5),
            0
        )
        XCTAssertEqual(
            TimelineScrubModel.position(start: 900, duration: 7_200, normalizedTranslation: 0.25),
            2_700
        )
    }

    func testEpisodeFixtureDecodesAndroidParityFields() throws {
        let fixture = #"""
        {"meta":{"id":"tt1","type":"series","name":"Show","videos":[{
          "id":"tt1:2:3","title":"Third","season":2,"episode":3,
          "overview":"Episode overview","thumbnail":"https://example.com/episode.jpg",
          "seasonPoster":"https://example.com/season.jpg","runtime":47,"available":false
        }]}}
        """#.data(using: .utf8)!

        let video = try XCTUnwrap(
            JSONDecoder().decode(MetaResponse.self, from: fixture).meta.videos.first
        )
        XCTAssertEqual(video.name, "Third")
        XCTAssertEqual(video.description, "Episode overview")
        XCTAssertEqual(video.seasonPoster, "https://example.com/season.jpg")
        XCTAssertEqual(video.runtime, 47)
        XCTAssertFalse(video.isAvailable)
    }

    func testEpisodeFixtureAcceptsSnakeCaseSeasonPoster() throws {
        let fixture = #"""
        {"meta":{"id":"tt1","type":"series","name":"Show","videos":[{
          "id":"tt1:1:1","name":"First","season_poster_path":"https://example.com/s1.jpg"
        }]}}
        """#.data(using: .utf8)!

        let video = try XCTUnwrap(
            JSONDecoder().decode(MetaResponse.self, from: fixture).meta.videos.first
        )
        XCTAssertEqual(video.seasonPoster, "https://example.com/s1.jpg")
        XCTAssertTrue(video.isAvailable)
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

    func testStreamDecodesProxyResponseHeadersSeparately() throws {
        let fixture = #"""
        {
          "name": "Protected source",
          "url": "https://video.example/movie.m3u8",
          "behaviorHints": {
            "proxyHeaders": {
              "request": {"Referer": "https://example.com"},
              "response": {"Content-Type": "application/vnd.apple.mpegurl"}
            }
          }
        }
        """#.data(using: .utf8)!

        let stream = try JSONDecoder().decode(StremioStream.self, from: fixture)
        XCTAssertEqual(stream.requestHeaders["Referer"], "https://example.com")
        XCTAssertEqual(stream.responseHeaders["Content-Type"], "application/vnd.apple.mpegurl")
        XCTAssertNil(stream.requestHeaders["Content-Type"])
    }

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

    func testSubtitlePreferenceRestoresByIDThenLanguageThenName() throws {
        let tracks = [
            PlaybackTrack(
                id: 7,
                kind: .subtitle,
                title: "English SDH",
                language: "en-US",
                isSelected: false
            ),
            PlaybackTrack(
                id: 8,
                kind: .subtitle,
                title: "Italian",
                language: "it",
                isSelected: false
            ),
        ]
        let exact = SubtitleTrackPreference(track: tracks[1])
        XCTAssertEqual(SubtitlePreferenceStore.matchingTrack(for: exact, in: tracks)?.id, 8)

        let encoded = try JSONEncoder().encode(exact)
        let moved = try JSONDecoder().decode(SubtitleTrackPreference.self, from: encoded)
        let differentIDs = tracks.map { track in
            PlaybackTrack(
                id: track.id + 100,
                kind: track.kind,
                title: track.title,
                language: track.language,
                isSelected: false
            )
        }
        XCTAssertEqual(
            SubtitlePreferenceStore.matchingTrack(for: moved, in: differentIDs)?.language,
            "it"
        )

        let byName = SubtitleTrackPreference(track: PlaybackTrack(
            id: 99,
            kind: .subtitle,
            title: "English SDH",
            language: nil,
            isSelected: false
        ))
        XCTAssertEqual(
            SubtitlePreferenceStore.matchingTrack(for: byName, in: differentIDs)?.title,
            "English SDH"
        )
    }

    func testSubtitlePreferenceStorePersistsSelectionAndAppearancePerProfile() {
        let defaults = isolatedDefaults()
        let store = SubtitlePreferenceStore(defaults: defaults)
        let track = PlaybackTrack(id: 4, kind: .subtitle, title: "Italian", language: "it", isSelected: true)
        store.saveSelection(SubtitleTrackPreference(track: track), contentID: "tt1", profileID: 2)
        store.saveAppearance(
            SubtitleAppearancePreference(fontSize: 68, delayMilliseconds: -300),
            profileID: 2,
            videoID: "tt1:1:1"
        )

        XCTAssertEqual(store.selection(contentID: "tt1", profileID: 2)?.trackID, 4)
        XCTAssertEqual(store.appearance(profileID: 2, videoID: "tt1:1:1").fontSize, 68)
        XCTAssertEqual(
            store.appearance(profileID: 2, videoID: "tt1:1:1").delayMilliseconds,
            -300
        )
        XCTAssertEqual(
            store.appearance(profileID: 2, videoID: "tt1:1:2").delayMilliseconds,
            0
        )
        XCTAssertEqual(
            store.appearance(profileID: 2, videoID: "tt1:1:2").fontSize,
            68
        )
        XCTAssertNil(store.selection(contentID: "tt1", profileID: 1))
    }

    func testDisabledSubtitlePreferencePersists() {
        let defaults = isolatedDefaults()
        let store = SubtitlePreferenceStore(defaults: defaults)
        store.saveSelection(.disabled, contentID: "tt1", profileID: 1)
        XCTAssertEqual(store.selection(contentID: "tt1", profileID: 1)?.selection, .disabled)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "PlayerFeatureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testPlayerExitCoordinatorUsesOneStepBackOrder() {
        let coordinator = PlayerExitCoordinator()
        XCTAssertEqual(
            coordinator.action(panelPresented: true, controlsVisible: true),
            .closePanel
        )
        XCTAssertEqual(
            coordinator.action(panelPresented: false, controlsVisible: true),
            .hideControls
        )
        XCTAssertEqual(
            coordinator.action(panelPresented: false, controlsVisible: false),
            .leavePlayer
        )
    }

    func testPlayerPressRouterConsumesOnlyMenuAndWakesForControls() {
        XCTAssertTrue(PlayerPressRouter.isMenu(.menu))
        XCTAssertFalse(PlayerPressRouter.isMenu(.playPause))
        XCTAssertTrue(PlayerPressRouter.wakesControls(.downArrow))
        XCTAssertTrue(PlayerPressRouter.wakesControls(.select))
        XCTAssertTrue(PlayerPressRouter.wakesControls(.playPause))
        XCTAssertFalse(PlayerPressRouter.wakesControls(.menu))
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
