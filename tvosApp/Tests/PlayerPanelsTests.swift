import XCTest
@testable import NuvioTV

final class PlayerPanelsTests: XCTestCase {
    // MARK: - Language key normalization

    func testLanguageKeyNormalization() {
        XCTAssertEqual(SubtitleSelectionComposer.languageKey(nil), SubtitleLanguageKey.unknown)
        XCTAssertEqual(SubtitleSelectionComposer.languageKey(""), SubtitleLanguageKey.unknown)
        XCTAssertEqual(SubtitleSelectionComposer.languageKey("en"), "en")
        XCTAssertEqual(SubtitleSelectionComposer.languageKey("en-US"), "en")
        XCTAssertEqual(SubtitleSelectionComposer.languageKey("pt"), "pt")
        // Regional variants survive as full keys, Android parity.
        XCTAssertEqual(SubtitleSelectionComposer.languageKey("pt-BR"), "pt-br")
        XCTAssertEqual(SubtitleSelectionComposer.languageKey("es-419"), "es-419")
    }

    func testTrackLanguageKeyUsesVariantDetection() {
        let track = SubtitleEmbeddedTrack(
            index: 0,
            name: "Portuguese (Brazil)",
            language: "por",
            trackID: nil,
            codec: nil,
            isForced: false,
            isSelected: false
        )
        XCTAssertEqual(SubtitleSelectionComposer.languageKey(forTrack: track), "pt-br")
    }

    func testPreferredLanguageOrderDeduplicatesAndSkipsNone() {
        XCTAssertEqual(
            SubtitleSelectionComposer.preferredLanguageOrder(
                preferredLanguage: "en-US",
                secondaryPreferredLanguage: "en"
            ),
            ["en"]
        )
        XCTAssertEqual(
            SubtitleSelectionComposer.preferredLanguageOrder(
                preferredLanguage: "none",
                secondaryPreferredLanguage: nil
            ),
            []
        )
    }

    // MARK: - Language rail

    func testLanguageRailOffFirstThenPreferredThenLabels() {
        let embedded = [
            SubtitleEmbeddedTrack(
                index: 0, name: "English", language: "eng",
                trackID: nil, codec: nil, isForced: false, isSelected: false
            ),
            SubtitleEmbeddedTrack(
                index: 1, name: "Italiano", language: "ita",
                trackID: nil, codec: nil, isForced: false, isSelected: false
            ),
        ]
        var preferences = SubtitleStyleOptions()
        preferences.preferredLanguage = "it"
        let items = SubtitleSelectionComposer.languageRailItems(
            embeddedTracks: embedded,
            externalTracks: [],
            preferences: preferences,
            currentLanguageKey: "en"
        )
        XCTAssertEqual(items.first?.key, SubtitleLanguageKey.off)
        // Preferred language floats above alphabetical order.
        XCTAssertEqual(items.dropFirst().first?.key, "it")
        XCTAssertEqual(items.map(\.count), [0, 1, 1])
    }

    // MARK: - Default track selection

    func testDefaultSelectionHonorsPreferredAndForced() {
        var preferences = SubtitleStyleOptions()
        preferences.preferredLanguage = "none"
        XCTAssertEqual(
            SubtitleSelectionComposer.defaultTrackSelection(
                embeddedTracks: [],
                preferences: preferences
            ),
            .off,
            "preferred 'none' selects subtitles off"
        )

        preferences.preferredLanguage = "en"
        preferences.useForcedSubtitles = true
        let forced = SubtitleEmbeddedTrack(
            index: 2, name: "English (forced)", language: "eng",
            trackID: nil, codec: nil, isForced: true, isSelected: false
        )
        let regular = SubtitleEmbeddedTrack(
            index: 0, name: "English", language: "eng",
            trackID: nil, codec: nil, isForced: false, isSelected: false
        )
        let selection = SubtitleSelectionComposer.defaultTrackSelection(
            embeddedTracks: [regular, forced],
            preferences: preferences
        )
        guard case .embedded(let track) = selection else {
            return XCTFail("expected embedded selection")
        }
        XCTAssertTrue(track.isForced)
    }

    // MARK: - Style options

    func testStyleOptionClamping() {
        var options = SubtitleStyleOptions()
        options.sizePercent = 10
        options.verticalOffset = 900
        options.outlineWidth = 99
        let adjusted = options.settingOutlineWidth(99)
        XCTAssertEqual(adjusted.outlineWidth, SubtitleStyleOptions.outlineWidthRange.upperBound)
        XCTAssertEqual(SubtitleStyleOptions.opacityStepPercent > 0, true)
    }

    func testStylePersistenceRoundTrip() {
        var options = SubtitleStyleOptions()
        options.preferredLanguage = "en"
        options.sizePercent = 140
        options.bold = true
        options.textColorARGB = 0xFF_12_34_56
        let values = SubtitleStylePersistence.persistedValues(of: options)
        let restored = SubtitleStylePersistence.load(from: values)
        XCTAssertEqual(restored.preferredLanguage, "en")
        XCTAssertEqual(restored.sizePercent, 140)
        XCTAssertEqual(restored.bold, true)
        XCTAssertEqual(restored.textColorARGB, 0xFF_12_34_56)
    }

    func testTextOpacityAdjustmentClamps() {
        var options = SubtitleStyleOptions()
        options.textColorARGB = 0xFF_FF_FF_FF
        let decreased = options.adjustingTextOpacity(
            byPercentStep: -4 * SubtitleStyleOptions.opacityStepPercent
        )
        let alpha = decreased.textColorARGB >> 24
        XCTAssertLessThan(Int(alpha), 255)
    }

    // MARK: - Timing dialog

    func testDelayClampAndReset() {
        var state = SubtitleTimingDialogState(delayMilliseconds: 90_000)
        XCTAssertEqual(state.delayMilliseconds, 90_000, "values inside the range pass through")
        state.adjustDelay(byMilliseconds: 1_000_000)
        XCTAssertEqual(state.delayMilliseconds, SubtitleDelayRange.maxMilliseconds)
        state.resetDelay()
        XCTAssertEqual(state.delayMilliseconds, 0)
    }
}
