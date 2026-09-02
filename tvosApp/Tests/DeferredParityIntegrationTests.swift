import SwiftUI
import XCTest
@testable import NuvioTV

/// Regression tests for the deferred-parity integration pass: profile RPC
/// payload mapping, theme palettes, autoplay settings, subtitle matching,
/// catalog-order key mapping, and persisted playback settings.
@MainActor
final class DeferredParityIntegrationTests: XCTestCase {
    // MARK: - Profile push mapping

    func testProfilePushEntryPrefersCustomAvatarURL() {
        let profile = TVProfile(
            profileIndex: 2,
            name: "Kids",
            avatarColorHex: "#22D37C",
            avatarID: "avatar-cat",
            avatarURL: "https://example.com/custom.png",
            profileBackgroundID: "bg-forest",
            profileBackgroundURL: "  ",
            usesPrimaryAddons: true,
            usesPrimaryPlugins: false
        )
        let entry = ProfilePushEntry(profile: profile)
        XCTAssertNil(entry.avatarID, "custom URL wins, avatar id drops to null")
        XCTAssertEqual(entry.avatarURL, "https://example.com/custom.png")
        XCTAssertNil(entry.profileBackgroundURL, "blank background URL becomes null")
        XCTAssertEqual(entry.profileBackgroundID, "bg-forest")
        XCTAssertEqual(entry.name, "Kids")
        XCTAssertEqual(entry.profileIndex, 2)
    }

    func testProfilePushEntryKeepsAvatarIDWithoutURL() {
        let profile = TVProfile(profileIndex: 3, name: "Guest", avatarID: "avatar-dog")
        let entry = ProfilePushEntry(profile: profile)
        XCTAssertEqual(entry.avatarID, "avatar-dog")
        XCTAssertNil(entry.avatarURL)
    }

    // MARK: - Theme palettes

    func testThemedPaletteAppliesAndroidAccents() {
        let gold = NuvioThemePalette.themed(.gold, contrast: .standard, reduceTransparency: false)
        XCTAssertEqual(gold.accent, Color(red: 0xE8 / 255.0, green: 0xA9 / 255.0, blue: 0x1C / 255.0))

        let crimson = NuvioThemePalette.themed(.crimson, contrast: .standard, reduceTransparency: false)
        XCTAssertEqual(crimson.accent, Color(red: 0xE5 / 255.0, green: 0x39 / 255.0, blue: 0x35 / 255.0))
    }

    func testIncreasedContrastUsesBrightAccent() {
        let palette = NuvioThemePalette.themed(.gold, contrast: .increased, reduceTransparency: false)
        XCTAssertEqual(palette.background, .black)
        XCTAssertEqual(palette.accent, Color(red: 0xFF / 255.0, green: 0xD4 / 255.0, blue: 0x5C / 255.0))
    }

    func testAppThemeParsesPersistedSetting() {
        XCTAssertEqual(NuvioAppTheme(parsedSetting: "o:GOLD"), .gold)
        XCTAssertEqual(NuvioAppTheme(parsedSetting: "GOLD"), .gold)
        XCTAssertEqual(NuvioAppTheme(parsedSetting: " o:jade "), .jade)
        XCTAssertNil(NuvioAppTheme(parsedSetting: ""))
        XCTAssertNil(NuvioAppTheme(parsedSetting: "t:1"))
    }

    // MARK: - Next-episode autoplay

    func testAutoplaySettingsParsePersistedValues() {
        let suite = "autoplay-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(NextEpisodeAutoplaySettings.isEnabled(defaults: defaults))
        XCTAssertEqual(NextEpisodeAutoplaySettings.timeoutSeconds(defaults: defaults), 3)
        XCTAssertEqual(NextEpisodeAutoplaySettings.triggerFraction(defaults: defaults), 0.99)

        defaults.set("t:1", forKey: "nuvio.tv.settings.v2.playback.streamAutoPlayNextEpisode")
        defaults.set("n:10", forKey: "nuvio.tv.settings.v2.playback.streamAutoPlayTimeoutSeconds")
        defaults.set("n:95", forKey: "nuvio.tv.settings.v2.playback.nextEpisodeThresholdPercent")

        XCTAssertTrue(NextEpisodeAutoplaySettings.isEnabled(defaults: defaults))
        XCTAssertEqual(NextEpisodeAutoplaySettings.timeoutSeconds(defaults: defaults), 10)
        XCTAssertEqual(NextEpisodeAutoplaySettings.triggerFraction(defaults: defaults), 0.95)
    }

    func testNextEpisodeAfterCurrent() {
        let episodes = [
            PlayerEpisodeOption(id: "e1", title: "One", seasonNumber: 1, episodeNumber: 1),
            PlayerEpisodeOption(id: "e2", title: "Two", seasonNumber: 1, episodeNumber: 2),
        ]
        let route = PlayerRoute(
            url: URL(string: "https://example.com/v")!,
            contentID: "e1",
            imdbID: "tt1",
            title: "Show",
            sourceName: "src",
            summary: MetaSummary.placeholder(id: "tt1", type: "series"),
            videoID: "e1",
            seasonNumber: 1,
            episodeNumber: 1,
            episodeTitle: nil,
            availableSources: [],
            episodes: episodes,
            onSelectEpisode: { _ in }
        )
        XCTAssertEqual(PlayerView.nextEpisode(after: route)?.id, "e2")
    }

    // MARK: - Addon subtitles

    func testManifestProvidesSubtitles() throws {
        let json = """
        {"id":"sub.addon","name":"Subs","resources":[{"name":"subtitles","types":["series","movie"],"idPrefixes":["tt"]}],"catalogs":[]}
        """
        let manifest = try JSONDecoder().decode(AddonManifest.self, from: Data(json.utf8))
        XCTAssertTrue(AddonSubtitleRepository.providesSubtitles(manifest))

        let noSubs = """
        {"id":"cat.addon","name":"Cats","resources":[{"name":"catalog","types":["movie"],"idPrefixes":[]}],"catalogs":[]}
        """
        XCTAssertFalse(AddonSubtitleRepository.providesSubtitles(
            try JSONDecoder().decode(AddonManifest.self, from: Data(noSubs.utf8))
        ))
    }

    func testAddonSubtitleEntryDecodesLanguageFallback() throws {
        let json = """
        {"subtitles":[{"id":"s1","url":"https://x/vtt","lang":"it"},{"url":"https://x/2","language":"de"}]}
        """
        let response = try JSONDecoder().decode(
            AddonSubtitlesResponse.self, from: Data(json.utf8)
        )
        // The response type is private; decode through the entries by
        // re-decoding one row to validate the flexible lang/language keys.
        let row = try JSONDecoder().decode(
            AddonSubtitleEntry.self,
            from: Data("{\"url\":\"https://x/2\",\"language\":\"de\"}".utf8)
        )
        XCTAssertEqual(row.lang, "de")
        XCTAssertEqual(response.subtitles?.count, 2)
        XCTAssertEqual(response.subtitles?.first?.lang, "it")
    }

    // MARK: - Catalog order keys

    func testModelKeyMappingRoundTrip() {
        let definitions = [
            CatalogDescriptor(
                baseURL: "https://a", addonID: "com.example", addonName: "Example",
                type: "movie", catalogID: "top", catalogName: "Top",
                genre: nil, genres: [], supportsPagination: true
            ),
        ]
        let modelKey = CatalogOrderSheet.modelKey(
            forDefinitionKey: "com.example:movie:top", valid: definitions
        )
        XCTAssertEqual(modelKey, "com.example_movie_top")
        XCTAssertNil(CatalogOrderSheet.modelKey(
            forDefinitionKey: "com.other:movie:top", valid: definitions
        ))
    }

    // MARK: - Persisted playback settings

    func testBufferConfigurationClamps() {
        let suite = "buffer-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // No settings: Android defaults (45 s readahead, 150 MB budget).
        var buffer = PersistedPlaybackSetting.bufferConfiguration(defaults: defaults)
        XCTAssertEqual(buffer.readaheadSeconds, 45)
        XCTAssertEqual(buffer.maxBytes, 150 * 1_024 * 1_024)

        defaults.set("n:9000", forKey: "nuvio.tv.settings.v2.playback.bufferMax")
        defaults.set("n:2", forKey: "nuvio.tv.settings.v2.playback.bufferTargetSizeMb")
        buffer = PersistedPlaybackSetting.bufferConfiguration(defaults: defaults)
        XCTAssertEqual(buffer.readaheadSeconds, 600, "readahead clamps to 600 s")
        XCTAssertEqual(buffer.maxBytes, 16 * 1_024 * 1_024, "budget clamps to the 16 MB floor")
    }

    func testOSDClockDefaultOn() {
        let suite = "osd-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("t:0", forKey: "nuvio.tv.settings.v2.playback.osdClock")
        XCTAssertFalse(PersistedPlaybackSetting.toggle("playback.osdClock", default: true, defaults: defaults))
        defaults.removeObject(forKey: "nuvio.tv.settings.v2.playback.osdClock")
        XCTAssertTrue(PersistedPlaybackSetting.toggle("playback.osdClock", default: true, defaults: defaults))
    }
}

private extension MetaSummary {
    static func placeholder(id: String, type: String) -> MetaSummary {
        MetaSummary(
            id: id, type: type, name: "Title", poster: nil, background: nil,
            description: nil, releaseInfo: nil, released: nil,
            playbackVideoID: nil, playbackSeason: nil, playbackEpisode: nil,
            metadataBaseURL: nil, genres: []
        )
    }
}
