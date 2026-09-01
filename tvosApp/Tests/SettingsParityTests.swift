import XCTest
@testable import NuvioTV

final class SettingsParityTests: XCTestCase {

    private func row(_ id: String, in sections: [NuvioSettingsSection]) -> NuvioSetting {
        sections.flatMap(\.settings).first { $0.id == id }!
    }
    private func rows(_ state: NuvioSettingsState) -> [NuvioSetting] {
        NuvioSettingsTree.sections(for: state).flatMap(\.settings)
    }

    // MARK: - Tree completeness

    func testTreeContainsEveryAndroidCategory() {
        let categories = Set(NuvioSettingsTree.sections(for: NuvioSettingsState()).map(\.category))
        XCTAssertEqual(categories, Set(NuvioSettingsCategory.allCases))
    }

    func testPlaybackTreeHasAllAndroidSubsections() {
        let ids = NuvioSettingsTree.sections(in: .playback, state: NuvioSettingsState()).map(\.id)
        XCTAssertEqual(ids, [
            "playback.general", "playback.audio", "playback.subtitles",
            "playback.autoplay", "playback.bufferNetwork"])
    }

    func testIntegrationSectionMirrorsAndroidIntegrationHub() {
        let section = NuvioSettingsTree.sections(in: .integrations, state: NuvioSettingsState())[0]
        XCTAssertEqual(section.settings.map(\.id), [
            "integrations.hub", "integrations.debrid",
            "integrations.tmdb", "integrations.mdblist", "integrations.animeSkip"])
    }

    func testLayoutSectionMirrorsLayoutSettingsScreen() {
        let sections = NuvioSettingsTree.sections(in: .layout, state: NuvioSettingsState())
        XCTAssertEqual(sections.map(\.id), ["layout.home", "layout.theme"])
        let home = sections[0]
        XCTAssertEqual(home.settings.first?.id, "layout.homeLayout")
        XCTAssertTrue(home.settings.contains { $0.id == "layout.modernLandscapePosters" })
        XCTAssertTrue(home.settings.contains { $0.id == "layout.modernHeroFullScreenBackdrop" })
        XCTAssertFalse(home.settings.contains { $0.id == "layout.classicFocusGradient" }) }

    func testThemeOptionsCoverAllAndroidThemes() {
        XCTAssertEqual(NuvioSettingsTree.themeOptions.count, 12, "AppTheme.kt defines twelve themes")
        XCTAssertTrue(NuvioSettingsTree.themeOptions.contains { $0.id == "WHITE" && $0.title == "White" }) }

    // MARK: - Value and display mapping

    func testEveryRowValueReflectsStateAndIdsAreUnique() {
        var seen = Set<String>()
        for setting in rows(NuvioSettingsState()) {
            XCTAssertFalse(seen.contains(setting.id), "duplicate setting id \(setting.id)")
            seen.insert(setting.id)
            switch setting.kind {
            case .toggle: XCTAssertTrue(isToggle(setting.value), "\(setting.id) needs a toggle value")
            case .optionPicker, .segmented: XCTAssertTrue(isOption(setting.value), "\(setting.id) needs an option value")
            case .slider: XCTAssertTrue(isNumber(setting.value), "\(setting.id) needs a number value")
            case .info, .navigation, .action: break
            }
        }
        XCTAssertGreaterThan(seen.count, 60)
    }

    private func isToggle(_ v: NuvioSettingValue) -> Bool { if case .toggle = v { return true }; return false }
    private func isOption(_ v: NuvioSettingValue) -> Bool { if case .option = v { return true }; return false }
    private func isNumber(_ v: NuvioSettingValue) -> Bool { if case .number = v { return true }; return false }

    func testDisplayValueMappingForCustomizedState() {
        var state = NuvioSettingsState()
        state.theme = .ocean
        state.frameRateMatchingMode = .startStop
        state.streamAutoPlayMode = .regexMatch
        state.streamAutoPlayTimeoutSeconds = NuvioSettingsLimits.streamAutoPlayTimeoutUnlimited
        state.streamReuseLastLinkEnabled = true
        state.streamReuseLastLinkCacheHours = 72
        state.bufferEngineEnabled = true
        state.subtitleSizePercent = 200
        state.postPlayMovieThresholdPercent = 95
        state.targetBufferSizeMb = 150
        state.preferredAudioLanguage = "de"
        state.updateChannel = .beta
        state.appVersion = "0.8.10-beta"
        state.connectionType = .ethernet

        let sections = NuvioSettingsTree.sections(for: state)
        XCTAssertEqual(row("layout.theme", in: sections).valueText, "Ocean")
        XCTAssertEqual(row("playback.frameRateMatching", in: sections).valueText, "On start & stop")
        XCTAssertEqual(row("playback.autoPlayMode", in: sections).valueText, "Regex match")
        XCTAssertEqual(row("playback.autoPlayTimeout", in: sections).valueText, "Unlimited")
        XCTAssertEqual(row("playback.reuseLastLinkCacheHours", in: sections).valueText, "3 days")
        XCTAssertEqual(row("playback.subtitleSize", in: sections).valueText, "200%")
        XCTAssertEqual(row("playback.postPlayMovieThreshold", in: sections).valueText, "95%")
        XCTAssertEqual(row("playback.preferredAudioLanguage", in: sections).valueText, "German")
        XCTAssertEqual(row("about.updateChannel", in: sections).valueText, "Beta")
        XCTAssertEqual(row("about.version", in: sections).valueText, "0.8.10-beta")
        XCTAssertEqual(row("network.connectionStatus", in: sections).valueText, "Ethernet")
        let target = row("playback.bufferTargetSizeMb", in: sections)
        if case .slider(let spec) = target.kind {
            XCTAssertEqual(spec.step, 25)
            XCTAssertEqual(spec.minimum, 25)
        } else {
            XCTFail("buffer target must be a slider")
        }
        XCTAssertEqual(target.valueText, "150 MB")
    }

    func testEveryToggleAndOptionChangeRoundTripsThroughState() {
        let nonMutating: Set<String> = [
            "network.speedTest", "network.streamSpeedTest", "network.clearContinueWatchingCache",
            "about.checkUpdates", "about.privacyPolicy", "about.supportersContributors",
            "about.licensesAttributions", "about.version", "playback.autoPlayRegex",
            "integrations.hub", "integrations.debrid", "integrations.tmdb",
            "integrations.mdblist", "integrations.animeSkip", "network.connectionStatus",
            "network.speedTestLatency", "network.speedTestDownload",
            "network.streamSpeedTestLatency", "network.streamSpeedTestDownload",
        ]
        var state = NuvioSettingsState()
        for _ in 0..<2 {
            for setting in rows(state) where !nonMutating.contains(setting.id) {
                let change: NuvioSettingsChange
                switch setting.value {
                case .toggle(let on):
                    change = NuvioSettingsChange(settingID: setting.id, value: .toggle(!on))
                case .option(let current):
                    guard case .optionPicker(let options) = setting.kind,
                          let other = options.first(where: { $0.id != current })?.id else { continue }
                    change = NuvioSettingsChange(settingID: setting.id, value: .option(other))
                default:
                    continue
                }
                state.apply(change)
                // The row either changed its value or became hidden behind a
                // conditional-visibility rule (parent toggle off keeps the
                // child's stored value, like the Android screens).
                let after = rows(state).first { $0.id == setting.id }
                if let after {
                    XCTAssertNotEqual(after.value, setting.value, "\(setting.id) did not reflect its own change")
                }
            }
        }
    }

    // MARK: - Layout picker selection

    func testLayoutSelectionForModernClassicAndGrid() {
        for layout in NuvioHomeLayout.allCases {
            var state = NuvioSettingsState()
            state.apply(NuvioSettingsChange(settingID: "layout.homeLayout", value: .option(layout.rawValue)))
            XCTAssertEqual(state.homeLayout, layout)
            let home = NuvioSettingsTree.sections(in: .layout, state: state)[0]
            XCTAssertEqual(home.settings.first?.value, .option(layout.rawValue))
            XCTAssertEqual(home.settings.first?.valueText, layout.displayName)
            XCTAssertEqual(
                home.settings.contains { $0.id == "layout.modernLandscapePosters" }, layout == .modern
            )
            XCTAssertEqual(
                home.settings.contains { $0.id == "layout.classicFocusGradient" }, layout == .classic
            )
        }
    }

    func testLayoutOptionOrderMatchesAndroidRow() {
        XCTAssertEqual(NuvioSettingsTree.layoutOptions.map(\.id), ["MODERN", "GRID", "CLASSIC"])
    }

    func testLayoutPreviewGeometry() {
        let modern = NuvioLayoutPreviewGeometry.modernRects()
        let hero = modern.first { $0.role == .hero }!
        XCTAssertEqual(hero.frame.height, 0.62, accuracy: 0.0001)
        XCTAssertEqual(hero.frame.width, 0.9, accuracy: 0.0001)
        XCTAssertEqual(hero.frame.minY, 0.06, accuracy: 0.0001)
        let firstCard = modern.first { $0.role != .hero }!
        XCTAssertEqual(firstCard.frame.minY, 0.73, accuracy: 0.0001)
        XCTAssertEqual(firstCard.frame.height, 0.24, accuracy: 0.0001)

        let classic = NuvioLayoutPreviewGeometry.classicRects()
        let rowYs = Set(classic.map { ($0.frame.minY * 10_000).rounded() })
        XCTAssertEqual(rowYs.count, 3, "Classic preview draws three rows")
        XCTAssertEqual(classic[0].frame.width, 1.0 / 5.5, accuracy: 0.0001)

        let grid = NuvioLayoutPreviewGeometry.gridRects()
        let firstRowY = grid[0].frame.minY
        XCTAssertEqual(grid.filter { abs($0.frame.minY - firstRowY) < 0.0001 }.count, 5)
        XCTAssertEqual(grid[0].frame.height, grid[0].frame.width * 1.4, accuracy: 0.0001)

        for layout in NuvioHomeLayout.allCases {
            XCTAssertGreaterThan(NuvioLayoutPreviewGeometry.rects(for: layout).count, 0)
            XCTAssertGreaterThan(NuvioLayoutPreviewGeometry.scrollPeriod(for: layout), 0)
        }
    }

    // MARK: - Autoplay clamps

    func testAutoPlayTimeoutNormalization() {
        XCTAssertEqual(
            NuvioSettingsLimits.normalizedAutoPlayTimeout(11), NuvioSettingsLimits.streamAutoPlayTimeoutUnlimited)
        XCTAssertEqual(NuvioSettingsLimits.normalizedAutoPlayTimeout(15), 15)
        XCTAssertEqual(NuvioSettingsLimits.normalizedAutoPlayTimeout(12), 10)
        XCTAssertEqual(NuvioSettingsLimits.normalizedAutoPlayTimeout(27), 25)
        XCTAssertEqual(NuvioSettingsLimits.normalizedAutoPlayTimeout(-5), 0)
        XCTAssertFalse(NuvioSettingsLimits.isBoundedTimeout(0))
        XCTAssertFalse(NuvioSettingsLimits.isBoundedTimeout(Int.max))
        XCTAssertTrue(NuvioSettingsLimits.isBoundedTimeout(3)) }

    func testAutoPlayTimeoutChangeMapsSliderPositions() {
        var state = NuvioSettingsState()
        state.apply(NuvioSettingsChange(settingID: "playback.autoPlayTimeout", value: .number(31)))
        XCTAssertEqual(state.streamAutoPlayTimeoutSeconds, NuvioSettingsLimits.streamAutoPlayTimeoutUnlimited)
        state.apply(NuvioSettingsChange(settingID: "playback.autoPlayTimeout", value: .number(9)))
        XCTAssertEqual(state.streamAutoPlayTimeoutSeconds, 9)
        state.apply(NuvioSettingsChange(settingID: "playback.autoPlayTimeout", value: .number(12)))
        XCTAssertEqual(state.streamAutoPlayTimeoutSeconds, 10)
    }

    func testPostPlayAndStillWatchingClamps() {
        var state = NuvioSettingsState()
        state.apply(NuvioSettingsChange(settingID: "playback.postPlayMovieThreshold", value: .number(50)))
        XCTAssertEqual(state.postPlayMovieThresholdPercent, 80)
        state.apply(NuvioSettingsChange(settingID: "playback.postPlayMovieThreshold", value: .number(120)))
        XCTAssertEqual(state.postPlayMovieThresholdPercent, 100)
        state.apply(NuvioSettingsChange(settingID: "playback.stillWatchingThreshold", value: .number(0)))
        XCTAssertEqual(state.stillWatchingEpisodeThreshold, 2)
        state.apply(NuvioSettingsChange(settingID: "playback.stillWatchingThreshold", value: .number(99)))
        XCTAssertEqual(state.stillWatchingEpisodeThreshold, 6)
    }

    func testNextEpisodeThresholdClampsToHalfSteps() {
        var state = NuvioSettingsState()
        state.apply(NuvioSettingsChange(settingID: "playback.nextEpisodeThresholdPercent", value: .number(90)))
        XCTAssertEqual(state.nextEpisodeThresholdPercent, 97)
        state.apply(NuvioSettingsChange(settingID: "playback.nextEpisodeThresholdPercent", value: .number(98.7)))
        XCTAssertEqual(state.nextEpisodeThresholdPercent, 98.5)
        state.apply(NuvioSettingsChange(settingID: "playback.nextEpisodeThresholdMinutes", value: .number(1.4)))
        XCTAssertEqual(state.nextEpisodeThresholdMinutesBeforeEnd, 1.5)
        state.apply(NuvioSettingsChange(settingID: "playback.nextEpisodeThresholdMinutes", value: .number(9)))
        XCTAssertEqual(state.nextEpisodeThresholdMinutesBeforeEnd, 3.5)
        XCTAssertEqual(NuvioSettingsLimits.halfStepText(99), "99")
        XCTAssertEqual(NuvioSettingsLimits.halfStepText(98.5), "98.5")
    }

    // MARK: - Buffer clamps

    func testBufferMaxNeverFallsBelowMin() {
        var state = NuvioSettingsState()
        state.bufferEngineEnabled = true
        state.apply(NuvioSettingsChange(settingID: "playback.bufferMin", value: .number(60)))
        XCTAssertEqual(state.minBufferSeconds, 60)
        state.apply(NuvioSettingsChange(settingID: "playback.bufferMax", value: .number(10)))
        XCTAssertEqual(state.maxBufferSeconds, 60, "max clamps up to min")
        state.apply(NuvioSettingsChange(settingID: "playback.bufferMin", value: .number(80)))
        XCTAssertEqual(state.maxBufferSeconds, 80)
    }

    func testBufferDurationStepsFollowPerformanceMode() {
        var state = NuvioSettingsState()
        state.bufferEngineEnabled = true
        state.apply(NuvioSettingsChange(settingID: "playback.bufferMin", value: .number(42)))
        XCTAssertEqual(state.minBufferSeconds, 40, "standard mode snaps to 5s steps")
        state.nuvioPerformanceModeEnabled = true
        state.apply(NuvioSettingsChange(settingID: "playback.bufferMin", value: .number(823)))
        XCTAssertEqual(state.minBufferSeconds, 820, "performance mode allows up to 1200s in 10s steps")
        state.apply(NuvioSettingsChange(settingID: "playback.bufferBack", value: .number(33)))
        XCTAssertEqual(state.backBufferSeconds, 30)
        state.apply(NuvioSettingsChange(settingID: "playback.bufferAfterRebuffer", value: .number(200)))
        XCTAssertEqual(state.bufferForPlaybackAfterRebufferSeconds, 120)
    }

    func testTargetBufferSnapsToMemoryBudget() {
        var state = NuvioSettingsState()
        state.deviceMaxHeapMb = 1024
        state.apply(NuvioSettingsChange(settingID: "playback.bufferTargetSizeMb", value: .number(5000)))
        XCTAssertEqual(state.targetBufferSizeMb, 850)
        state.allowLargeTargetBuffer = true
        state.apply(NuvioSettingsChange(settingID: "playback.bufferTargetSizeMb", value: .number(5000)))
        XCTAssertEqual(state.targetBufferSizeMb, 2048, "large override caps at 2 GB")
        // 256 MB heap: 0.65*256=166, capped at 256-210=46, snapped to 25 MB steps.
        state.deviceMaxHeapMb = 256
        state.allowLargeTargetBuffer = false
        state.apply(NuvioSettingsChange(settingID: "playback.bufferTargetSizeMb", value: .number(5000)))
        XCTAssertEqual(state.targetBufferSizeMb, 25)
    }

    func testParallelConnectionAndChunkClamps() {
        var state = NuvioSettingsState()
        state.apply(NuvioSettingsChange(settingID: "playback.parallelConnectionCount", value: .number(99)))
        XCTAssertEqual(state.parallelConnectionCount, 4)
        state.nuvioPerformanceModeEnabled = true
        state.apply(NuvioSettingsChange(settingID: "playback.parallelConnectionCount", value: .number(12)))
        XCTAssertEqual(state.parallelConnectionCount, 12)

        // 1024 MB heap, 150 MB buffer, 2 connections: (870-150)/4 = 180 -> tier cap 128.
        let options = NuvioSettingsLimits.chunkSizeOptions(
            maxChunkMb: NuvioSettingsLimits.maxChunkMb(bufferMb: 150, connections: 2, maxHeapMb: 1024)
        )
        XCTAssertEqual(options.map(\.id), [
            "256", "512", "1024", "2048", "4096", "8192", "16384",
            "24576", "32768", "49152", "65536", "98304", "131072"])
        // Low-RAM tier: 256 MB heap budgets 46 MB, so (46-25)/4 floors at the
        // 8 MB minimum chunk even though the tier cap is 16 MB.
        let lowRam = NuvioSettingsLimits.maxChunkMb(bufferMb: 25, connections: 2, maxHeapMb: 256)
        XCTAssertEqual(lowRam, 8)
        XCTAssertEqual(NuvioSettingsLimits.chunkSizeOptions(maxChunkMb: lowRam).last?.title, "8 MB")
    }

    func testVodCacheClampAndManualMaximum() {
        var state = NuvioSettingsState()
        state.apply(NuvioSettingsChange(settingID: "playback.vodCacheSizeMb", value: .number(10)))
        XCTAssertEqual(state.vodCacheSizeMb, 100)
        state.apply(NuvioSettingsChange(settingID: "playback.vodCacheSizeMb", value: .number(1_000_000)))
        XCTAssertEqual(state.vodCacheSizeMb, 65_536)
        XCTAssertEqual(NuvioSettingsLimits.maxManualVodCacheMb(freeDiskBytes: 8 * 1024 * 1024 * 1024), 6144)
        XCTAssertEqual(NuvioSettingsLimits.maxManualVodCacheMb(freeDiskBytes: 100 * 1024 * 1024), 100)
    }

    // MARK: - Diagnostics row states

    func testDiagnosticsEmptyState() {
        let cards = NuvioDiagnosticsBuilder.cards(diagnostics: NuvioPlaybackDiagnostics())
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].id, "diagnostics_empty")
        XCTAssertTrue(cards[0].rows[0].value.contains("Play something"))
    }

    private func populatedDiagnostics() -> NuvioPlaybackDiagnostics {
        var d = NuvioPlaybackDiagnostics()
        d.timestampMs = 1_760_000_000_000
        d.host = "example.addon"
        d.deviceName = "Apple TV 4K"
        d.hdrCapsKnown = true
        d.displayDv = true
        d.codecDv7Supported = true
        d.dv81DecoderName = "dovi.dv81"
        d.bridgeReady = true
        d.dv7ModeRequested = "DV81_LIBDOVI"
        d.dv7ModeEffective = "DV81_LIBDOVI"
        d.dv7AutoDecision = "converted"
        d.dvSourceProfile = "dvhe.07"
        d.dv7DoviSuccess = 8
        d.dv7DoviCalls = 10
        d.dv7DoviSignalRewrites = 2
        d.videoHdrType = "Dolby Vision"
        d.firstFrameMs = 312
        d.rebufferCount = 2
        d.rebufferTotalMs = 540
        d.result = "Played"
        return d
    }

    func testDiagnosticsCardsAndDvGating() {
        let cards = NuvioDiagnosticsBuilder.cards(diagnostics: populatedDiagnostics())
        XCTAssertEqual(cards.map(\.id), ["diagnostics_input", "diagnostics_decision", "diagnostics_outcome"])
        let inputRows = cards[0].rows
        XCTAssertEqual(inputRows.first { $0.id == "input.host" }?.value, "example.addon")
        XCTAssertEqual(inputRows.first { $0.id == "input.display" }?.value, "DV")
        XCTAssertEqual(inputRows.first { $0.id == "input.dvBridge" }?.value, "Ready")
        let decision = cards[1].rows
        XCTAssertEqual(decision.first { $0.id == "decision.conversions" }?.value, "8 of 10")
        XCTAssertEqual(decision.first { $0.id == "decision.signalRewrites" }?.value, "2")
        let outcome = cards[2].rows
        XCTAssertEqual(outcome.first { $0.id == "outcome.rebuffers" }?.value, "2 (540 ms)")
        XCTAssertEqual(outcome.first { $0.id == "outcome.firstFrame" }?.value, "312 ms")
        XCTAssertEqual(outcome.first { $0.id == "outcome.result" }?.tone, .success)
        XCTAssertNil(decision.first { $0.id == "decision.dvModeEffective" })
    }

    func testDvRowsCollapseWhenNotEngaged() {
        var d = populatedDiagnostics()
        // SDR playback: no DV content, so every DV row reads "-".
        d.dv7ModeRequested = "AUTO"
        d.dv7ModeEffective = "OFF"
        d.displayDv = false
        d.videoHdrType = "HDR10"
        d.dvSourceProfile = nil
        d.dv7DoviSuccess = 0
        d.dv7DoviCalls = 0
        d.dv7DoviSignalRewrites = 0
        d.result = "Error: decoder init failed"

        let cards = NuvioDiagnosticsBuilder.cards(diagnostics: d)
        XCTAssertEqual(cards[0].rows.first { $0.id == "input.display" }?.value, "-")
        XCTAssertEqual(cards[0].rows.first { $0.id == "input.dvDecoder" }?.value, "-")
        XCTAssertEqual(cards[2].rows.first { $0.id == "outcome.result" }?.tone, .error)
        XCTAssertNil(cards[1].rows.first { $0.id == "decision.conversions" })
        XCTAssertNil(cards[1].rows.first { $0.id == "decision.dvModeEffective" })
    }

    func testResultToneMatrix() {
        XCTAssertEqual(NuvioDiagnosticsBuilder.resultTone("Played"), .success)
        XCTAssertEqual(NuvioDiagnosticsBuilder.resultTone("Error: timeout"), .error)
        XCTAssertEqual(NuvioDiagnosticsBuilder.resultTone("Stopped"), .normal)
    }

    func testReuseCacheDurationText() {
        XCTAssertEqual(NuvioSettingsLimits.reuseCacheDurationText(hours: 1), "1 hour")
        XCTAssertEqual(NuvioSettingsLimits.reuseCacheDurationText(hours: 6), "6 hours")
        XCTAssertEqual(NuvioSettingsLimits.reuseCacheDurationText(hours: 24), "1 day")
        XCTAssertEqual(NuvioSettingsLimits.reuseCacheDurationText(hours: 48), "2 days")
        XCTAssertEqual(NuvioSettingsLimits.reuseCacheDurationText(hours: 168), "7 days")
    }
}
