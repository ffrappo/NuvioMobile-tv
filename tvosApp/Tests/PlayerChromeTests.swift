import XCTest
@testable import NuvioTV

final class PlayerChromeTests: XCTestCase {
    // MARK: - Helpers

    private func flags(_ keyPath: WritableKeyPath<PlayerChromeFlags, Bool>) -> PlayerChromeFlags {
        var value = PlayerChromeFlags()
        value[keyPath: keyPath] = true
        return value
    }

    private func state(_ keyPath: WritableKeyPath<PlayerChromeFlags, Bool>) -> PlayerChromeState {
        PlayerChromeState(flags: flags(keyPath))
    }

    private var allLayerKeyPaths: [WritableKeyPath<PlayerChromeFlags, Bool>] {
        [
            \.showControls, \.showPauseOverlay, \.showStreamInfoOverlay,
            \.showEpisodesPanel, \.showSourcesPanel, \.showAudioOverlay,
            \.showSubtitleOverlay, \.showSubtitleStylePanel,
            \.showSubtitleDelayOverlay, \.showSubtitleTimingDialog,
            \.showSpeedDialog, \.showMoreDialog, \.hasError,
        ]
    }

    private var panelKeyPaths: [(WritableKeyPath<PlayerChromeFlags, Bool>, PlayerChromeLayer)] {
        [
            (\.showEpisodesPanel, .episodesPanel),
            (\.showSourcesPanel, .sourcesPanel),
            (\.showAudioOverlay, .audioOverlay),
            (\.showSubtitleOverlay, .subtitleOverlay),
            (\.showSubtitleStylePanel, .subtitleStylePanel),
            (\.showSubtitleDelayOverlay, .subtitleDelayOverlay),
            (\.showSpeedDialog, .speedDialog),
        ]
    }

    private var blockingKeyPaths: [WritableKeyPath<PlayerChromeFlags, Bool>] {
        [
            \.hasPendingPreviewSeek, \.showPauseOverlay, \.showStreamInfoOverlay,
            \.showEpisodesPanel, \.showSourcesPanel, \.showAudioOverlay,
            \.showSubtitleOverlay, \.showSubtitleStylePanel,
            \.showSubtitleDelayOverlay, \.showSubtitleTimingDialog,
            \.showSpeedDialog, \.showMoreDialog,
        ]
    }

    private func makeInterval(_ start: Double, _ end: Double, type: String = "intro") -> SkipInterval {
        SkipInterval(startTime: start, endTime: end, type: type, provider: "test")
    }

    // MARK: - Layer precedence

    func testEmptyFlagsResolveToNone() {
        XCTAssertEqual(PlayerChromeState().resolvedLayer, .none)
        XCTAssertFalse(PlayerChromeState().isControlsVisible)
        XCTAssertFalse(PlayerChromeState().blocksPostPlayRecommendation)
    }

    func testSingleFlagResolvesToItsLayer() {
        let expectations: [(WritableKeyPath<PlayerChromeFlags, Bool>, PlayerChromeLayer)] = [
            (\.showControls, .controls),
            (\.showPauseOverlay, .pauseOverlay),
            (\.showStreamInfoOverlay, .streamInfoOverlay),
            (\.showEpisodesPanel, .episodesPanel),
            (\.showSourcesPanel, .sourcesPanel),
            (\.showAudioOverlay, .audioOverlay),
            (\.showSubtitleOverlay, .subtitleOverlay),
            (\.showSubtitleStylePanel, .subtitleStylePanel),
            (\.showSubtitleDelayOverlay, .subtitleDelayOverlay),
            (\.showSubtitleTimingDialog, .subtitleTimingDialog),
            (\.showSpeedDialog, .speedDialog),
            (\.showMoreDialog, .moreDialog),
            (\.hasError, .error),
            // A pending scrub preview blocks post-play but opens no layer.
            (\.hasPendingPreviewSeek, .none),
        ]
        for (keyPath, layer) in expectations {
            XCTAssertEqual(state(keyPath).resolvedLayer, layer, "flag \(keyPath)")
        }
    }

    func testStreamInfoTakesPrecedenceOverPauseAndControls() {
        var value = PlayerChromeFlags()
        value.showControls = true
        value.showPauseOverlay = true
        value.showStreamInfoOverlay = true
        let chrome = PlayerChromeState(flags: value)
        XCTAssertEqual(chrome.resolvedLayer, .streamInfoOverlay)
        XCTAssertTrue(chrome.isStreamInfoOverlayVisible)
        XCTAssertFalse(chrome.isPauseOverlayVisible)
        XCTAssertFalse(chrome.isControlsVisible)
    }

    func testPauseTakesPrecedenceOverControls() {
        var value = PlayerChromeFlags()
        value.showControls = true
        value.showPauseOverlay = true
        let chrome = PlayerChromeState(flags: value)
        XCTAssertEqual(chrome.resolvedLayer, .pauseOverlay)
        XCTAssertTrue(chrome.isPauseOverlayVisible)
        XCTAssertFalse(chrome.isControlsVisible)
    }

    func testErrorSuppressesEveryOtherLayer() {
        for keyPath in allLayerKeyPaths where keyPath != \PlayerChromeFlags.hasError {
            var value = flags(keyPath)
            value.hasError = true
            let chrome = PlayerChromeState(flags: value)
            XCTAssertEqual(chrome.resolvedLayer, .error, "flag \(keyPath)")
            XCTAssertFalse(chrome.isControlsVisible, "flag \(keyPath)")
            XCTAssertFalse(chrome.isPauseOverlayVisible, "flag \(keyPath)")
            XCTAssertFalse(chrome.isStreamInfoOverlayVisible, "flag \(keyPath)")
            XCTAssertFalse(chrome.isEpisodesPanelVisible, "flag \(keyPath)")
            XCTAssertFalse(chrome.isMoreDialogVisible, "flag \(keyPath)")
        }
    }

    func testEveryFlagCombinationClassResolvesDeterministically() {
        // Every pair of distinct layer-opening flags resolves to the higher
        // precedence layer per the Android z-stack order.
        let order: [(WritableKeyPath<PlayerChromeFlags, Bool>, PlayerChromeLayer, Int)] = [
            (\.hasError, .error, 0),
            (\.showStreamInfoOverlay, .streamInfoOverlay, 1),
            (\.showPauseOverlay, .pauseOverlay, 2),
            (\.showMoreDialog, .moreDialog, 3),
            (\.showSubtitleTimingDialog, .subtitleTimingDialog, 4),
            (\.showAudioOverlay, .audioOverlay, 5),
            (\.showSubtitleOverlay, .subtitleOverlay, 6),
            (\.showSubtitleDelayOverlay, .subtitleDelayOverlay, 7),
            (\.showSubtitleStylePanel, .subtitleStylePanel, 8),
            (\.showSpeedDialog, .speedDialog, 9),
            (\.showSourcesPanel, .sourcesPanel, 10),
            (\.showEpisodesPanel, .episodesPanel, 11),
        ]
        for i in 0..<order.count {
            for j in 0..<order.count where i != j {
                var value = PlayerChromeFlags()
                value[keyPath: order[i].0] = true
                value[keyPath: order[j].0] = true
                value.showControls = true
                let expected = order[i].2 < order[j].2 ? order[i].1 : order[j].1
                XCTAssertEqual(
                    PlayerChromeState(flags: value).resolvedLayer, expected,
                    "pair \(order[i].1) + \(order[j].1)"
                )
            }
        }
    }

    // MARK: - Controls suppression

    func testControlsSuppressedUnderPanels() {
        for (keyPath, layer) in panelKeyPaths {
            var value = flags(keyPath)
            value.showControls = true
            let chrome = PlayerChromeState(flags: value)
            XCTAssertFalse(chrome.isControlsVisible, "panel \(layer)")
            XCTAssertEqual(chrome.resolvedLayer, layer, "panel \(layer)")
            XCTAssertTrue(chrome.isPanelOrDialogOpen, "panel \(layer)")
        }
    }

    func testControlsHiddenWhenFlagIsFalse() {
        var value = PlayerChromeFlags()
        value.showControls = false
        for (keyPath, _) in panelKeyPaths { value[keyPath: keyPath] = false }
        XCTAssertFalse(PlayerChromeState(flags: value).isControlsVisible)
        XCTAssertEqual(PlayerChromeState(flags: value).resolvedLayer, .none)
    }

    func testDialogsRenderAboveVisibleControls() {
        // Android keeps the controls AnimatedVisibility on beneath the
        // more-actions and subtitle timing dialogs; they render above.
        var timing = flags(\.showSubtitleTimingDialog)
        timing.showControls = true
        let timingChrome = PlayerChromeState(flags: timing)
        XCTAssertTrue(timingChrome.isControlsVisible)
        XCTAssertEqual(timingChrome.resolvedLayer, .subtitleTimingDialog)

        var more = flags(\.showMoreDialog)
        more.showControls = true
        let moreChrome = PlayerChromeState(flags: more)
        XCTAssertTrue(moreChrome.isControlsVisible)
        XCTAssertEqual(moreChrome.resolvedLayer, .moreDialog)
    }

    func testControlsSuppressedUnderStreamInfoAndPause() {
        var streamInfo = flags(\.showStreamInfoOverlay)
        streamInfo.showControls = true
        XCTAssertFalse(PlayerChromeState(flags: streamInfo).isControlsVisible)

        var pause = flags(\.showPauseOverlay)
        pause.showControls = true
        XCTAssertFalse(PlayerChromeState(flags: pause).isControlsVisible)
    }

    // MARK: - blocksPostPlayRecommendation truth table

    func testBlocksPostPlayRecommendationTruthTable() {
        // Every blocking flag alone blocks post-play.
        for keyPath in blockingKeyPaths {
            XCTAssertTrue(state(keyPath).blocksPostPlayRecommendation, "flag \(keyPath)")
        }
        // Non-blocking inputs: all-false, controls alone, error alone,
        // controls + error.
        XCTAssertFalse(PlayerChromeState().blocksPostPlayRecommendation)
        XCTAssertFalse(state(\.showControls).blocksPostPlayRecommendation)
        XCTAssertFalse(state(\.hasError).blocksPostPlayRecommendation)
        var errorControls = flags(\.showControls)
        errorControls.hasError = true
        XCTAssertFalse(PlayerChromeState(flags: errorControls).blocksPostPlayRecommendation)
        // Cleared flags stop blocking.
        var cleared = flags(\.showEpisodesPanel)
        cleared.showEpisodesPanel = false
        XCTAssertFalse(PlayerChromeState(flags: cleared).blocksPostPlayRecommendation)
    }

    // MARK: - Skip intro window math

    func testFindActiveSkipIntervalBeforeDuringAfterWindow() {
        let intervals = [makeInterval(10, 20), makeInterval(30, 40, type: "recap")]
        // Before any window.
        XCTAssertNil(SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 5))
        XCTAssertNil(SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 9.999))
        // Inside the first window (start inclusive).
        XCTAssertEqual(
            SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 10)?.id,
            intervals[0].id
        )
        XCTAssertEqual(
            SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 15)?.id,
            intervals[0].id
        )
        XCTAssertEqual(
            SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 19.999)?.id,
            intervals[0].id
        )
        // End boundary is exclusive: 20 falls in no window.
        XCTAssertNil(SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 20))
        // Inside the second window.
        XCTAssertEqual(
            SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 35)?.id,
            intervals[1].id
        )
        // After every window.
        XCTAssertNil(SkipIntroVisibilityRules.findActiveSkipInterval(intervals, positionSeconds: 45))
        // Empty list never matches.
        XCTAssertNil(SkipIntroVisibilityRules.findActiveSkipInterval([], positionSeconds: 15))
        // nextActiveSkipInterval aliases findActiveSkipInterval.
        XCTAssertEqual(
            SkipIntroVisibilityRules.nextActiveSkipInterval(intervals, positionSeconds: 15)?.id,
            intervals[0].id
        )
    }

    func testAutoHideRemainingMsClamping() {
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 0), 10_000)
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 0.25), 7_500)
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 0.5), 5_000)
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 0.999), 10)
        // Completed and over-completed clamp to a 1 ms minimum duration.
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 1), 1)
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 1.5), 1)
        // Negative progress clamps to a full window.
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: -0.5), 10_000)
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: -1), 10_000)
        // Custom timeout participates in the same math.
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 0.25, totalTimeoutMs: 8_000), 6_000)
        XCTAssertEqual(SkipIntroVisibilityRules.autoHideRemainingMs(progress: 1, totalTimeoutMs: 8_000), 1)
    }

    func testIsSkipIntroButtonVisibleTruthTable() {
        let cases: [(
            hasActive: Bool, dismissed: Bool, controls: Bool, autoHidden: Bool, expected: Bool
        )] = [
            // No active interval: never visible.
            (false, false, false, false, false),
            (false, true, false, false, false),
            (false, false, true, false, false),
            (false, false, false, true, false),
            (false, true, true, true, false),
            // Active interval, nothing dismissed: visible.
            (true, false, false, false, true),
            (true, false, true, false, true),
            // Dismissed: hidden unless controls are visible.
            (true, true, false, false, false),
            (true, true, true, false, true),
            // Auto-hidden: hidden unless controls are visible.
            (true, false, false, true, false),
            (true, false, true, true, true),
            // Both dismissed and auto-hidden: controls still re-reveal.
            (true, true, false, true, false),
            (true, true, true, true, true),
        ]
        for testCase in cases {
            XCTAssertEqual(
                SkipIntroVisibilityRules.isSkipIntroButtonVisible(
                    hasActiveInterval: testCase.hasActive,
                    dismissed: testCase.dismissed,
                    controlsVisible: testCase.controls,
                    autoHidden: testCase.autoHidden
                ),
                testCase.expected,
                "case \(testCase)"
            )
        }
    }

    func testIsSkipIntroCanFocus() {
        XCTAssertTrue(SkipIntroVisibilityRules.isSkipIntroCanFocus(subtitleOverlayVisible: false))
        XCTAssertFalse(SkipIntroVisibilityRules.isSkipIntroCanFocus(subtitleOverlayVisible: true))
    }

    func testSkipLabel() {
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "intro"), "Skip Intro")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "OP"), "Skip Intro")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "mixed-op"), "Skip Intro")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "ed"), "Skip Ending")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "mixed-ed"), "Skip Ending")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "outro"), "Skip Ending")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "credits"), "Skip Ending")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "recap"), "Skip Recap")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: nil), "Skip")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "unknown"), "Skip")
        XCTAssertEqual(SkipIntroVisibilityRules.skipLabel(forType: "  Recap  "), "Skip Recap")
    }

    func testChromeSuppressesSkipIntroUnderPauseOverlay() {
        XCTAssertFalse(PlayerChromeState().suppressesSkipIntro)
        XCTAssertTrue(state(\.showPauseOverlay).suppressesSkipIntro)
        XCTAssertFalse(state(\.showStreamInfoOverlay).suppressesSkipIntro)
    }

    // MARK: - Stream info formatting (Android port)

    func testStreamInfoFormatters() {
        XCTAssertEqual(PlayerStreamInfoFormat.resolution(width: 1920, height: 1080),
                       "1920 × 1080 (1080p)")
        XCTAssertEqual(PlayerStreamInfoFormat.resolution(width: 3840, height: 2160),
                       "3840 × 2160 (4K)")
        XCTAssertEqual(PlayerStreamInfoFormat.resolution(width: 2560, height: 1440),
                       "2560 × 1440 (1440p)")
        XCTAssertEqual(PlayerStreamInfoFormat.resolution(width: 1280, height: 720),
                       "1280 × 720 (720p)")
        XCTAssertEqual(PlayerStreamInfoFormat.resolution(width: 854, height: 480),
                       "854 × 480 (480p)")

        XCTAssertEqual(PlayerStreamInfoFormat.bitrate(1_500_000), "1.5 Mbps")
        XCTAssertEqual(PlayerStreamInfoFormat.bitrate(250_000), "250 kbps")
        XCTAssertEqual(PlayerStreamInfoFormat.bitrate(500), "500 bps")

        XCTAssertEqual(PlayerStreamInfoFormat.fileSize(1_073_741_824), "1.0 GB")
        XCTAssertEqual(PlayerStreamInfoFormat.fileSize(5_242_880), "5.0 MB")
        XCTAssertEqual(PlayerStreamInfoFormat.fileSize(2_048), "2.0 KB")
        XCTAssertEqual(PlayerStreamInfoFormat.fileSize(500), "500 B")

        XCTAssertEqual(PlayerStreamInfoFormat.frameRate(23.976), "23.976 fps")
        XCTAssertEqual(PlayerStreamInfoFormat.sampleRate(48_000), "48 kHz")
    }

    func testStreamInfoSectionsPresenceRules() {
        let empty = PlayerStreamInfoData()
        XCTAssertTrue(PlayerStreamInfoOverlayView.sections(from: empty).isEmpty)

        let full = PlayerStreamInfoData(
            addonName: "Torrentio", streamName: "1080p",
            filename: "movie.mkv", fileSize: 2_000_000_000,
            videoCodec: "hevc", videoWidth: 1920, videoHeight: 1080,
            videoFrameRate: 23.976, fileBitrate: 8_000_000,
            audioCodec: "eac3", audioChannels: "5.1", audioSampleRate: 48_000,
            audioLanguage: "eng", subtitleName: "English",
            playerEngine: "mpv"
        )
        let sections = PlayerStreamInfoOverlayView.sections(from: full)
        XCTAssertEqual(sections.map(\.title), ["SOURCE", "FILE", "VIDEO", "AUDIO", "SUBTITLE"])
        XCTAssertEqual(sections[0].items.first?.label, "Player Engine")
        XCTAssertEqual(sections[1].items[1].value, "1.9 GB")
        // No track bitrate falls back to the whole-file bitrate label.
        XCTAssertEqual(sections[2].items[3].label, "Bitrate (file)")
        XCTAssertEqual(sections[2].items[3].value, "8.0 Mbps")
        XCTAssertEqual(sections[2].items[1].value, "1920 × 1080 (1080p)")
    }
}
