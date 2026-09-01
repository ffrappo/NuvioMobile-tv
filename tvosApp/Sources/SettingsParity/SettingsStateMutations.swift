import Foundation

/// Applies `NuvioSettingsChange` values with the same clamps the Android view
/// models enforce. The integration layer may use this directly or keep its own
/// persistence and only read the tree for display.
public extension NuvioSettingsState {
    mutating func apply(_ change: NuvioSettingsChange) {
        switch change.settingID {
        // Layout
        case "layout.homeLayout":
            if case .option(let raw) = change.value,
               let layout = NuvioHomeLayout(rawValue: raw) {
                homeLayout = layout
            }
        case "layout.modernLandscapePosters":
            applyToggle(change, to: \.modernLandscapePostersEnabled)
        case "layout.modernHeroFullScreenBackdrop":
            applyToggle(change, to: \.modernHeroFullScreenBackdropEnabled)
        case "layout.classicFocusGradient":
            applyToggle(change, to: \.classicFocusGradientEnabled)
        case "layout.theme":
            if case .option(let raw) = change.value,
               let resolvedTheme = NuvioAppTheme(rawValue: raw) {
                theme = resolvedTheme
            }

        // Playback: general
        case "playback.playerPreference":
            if case .option(let raw) = change.value,
               let preference = NuvioPlayerPreference(rawValue: raw) {
                playerPreference = preference
            }
        case "playback.internalPlayerEngine":
            if case .option(let raw) = change.value,
               let engine = NuvioInternalPlayerEngine(rawValue: raw) {
                internalPlayerEngine = engine
            }
        case "playback.autoSwitchInternalPlayerOnError":
            applyToggle(change, to: \.autoSwitchInternalPlayerOnError)
        case "playback.loadingOverlay":
            applyToggle(change, to: \.loadingOverlayEnabled)
        case "playback.showLoadingStatus":
            applyToggle(change, to: \.showPlayerLoadingStatus)
        case "playback.pauseOverlay":
            applyToggle(change, to: \.pauseOverlayEnabled)
        case "playback.osdClock":
            applyToggle(change, to: \.osdClockEnabled)
        case "playback.skipIntroButton":
            applyToggle(change, to: \.skipIntroEnabled)
        case "playback.parentalGuide":
            applyToggle(change, to: \.parentalGuideEnabled)
        case "playback.autoSkipIntro", "playback.autoSkipRecap", "playback.autoSkipOutro":
            if case .toggle(let on) = change.value {
                let suffix = String(change.settingID.dropFirst("playback.autoSkip".count)).lowercased()
                let segment: NuvioAutoSkipSegmentType?
                switch suffix {
                case "intro": segment = .intro
                case "recap": segment = .recap
                case "outro": segment = .outro
                default: segment = nil
                }
                if let segment {
                    if on {
                        autoSkipSegmentTypes.insert(segment)
                    } else {
                        autoSkipSegmentTypes.remove(segment)
                    }
                }
            }
        case "playback.externalForwardSubtitles":
            applyToggle(change, to: \.externalPlayerForwardSubtitles)
        case "playback.externalSendSkipSegments":
            applyToggle(change, to: \.externalPlayerSendSkipSegments)
        case "playback.frameRateMatching":
            if case .option(let raw) = change.value,
               let mode = NuvioFrameRateMatchingMode(rawValue: raw) {
                frameRateMatchingMode = mode
            }
        case "playback.resolutionMatching":
            applyToggle(change, to: \.resolutionMatchingEnabled)
        case "playback.hideTorrentStats":
            applyToggle(change, to: \.hideTorrentStats)

        // Audio
        case "playback.preferredAudioLanguage":
            if case .option(let code) = change.value { preferredAudioLanguage = code }
        case "playback.secondaryAudioLanguage":
            if case .option(let code) = change.value {
                secondaryPreferredAudioLanguage = code == "none" ? nil : code
            }
        case "playback.skipSilence":
            applyToggle(change, to: \.skipSilence)
        case "playback.rememberAudioDelayPerDevice":
            applyToggle(change, to: \.rememberAudioDelayPerDevice)
        case "playback.audioDecoderPriority":
            if case .option(let raw) = change.value,
               let priority = NuvioAudioDecoderPriority(rawValue: Int(raw) ?? 1) {
                audioDecoderPriority = priority
            }
        case "playback.audioDownmix":
            applyToggle(change, to: \.downmixEnabled)
        case "playback.audioChannelCount":
            if case .option(let raw) = change.value {
                audioOutputChannelCount = Int(raw) ?? 0
            }
        case "playback.audioMaintainOriginalOnDownmix":
            applyToggle(change, to: \.maintainOriginalAudioOnDownmix)
        case "playback.audioTunneled":
            applyToggle(change, to: \.tunneledAudioEnabled)
        case "playback.audioForceOpticalPassthrough":
            applyToggle(change, to: \.forceOpticalPassthrough)
        case "playback.dv7Handling":
            if case .option(let raw) = change.value,
               let mode = NuvioDv7HandlingMode(rawValue: raw) {
                dv7HandlingMode = mode
            }
        case "playback.dv7PreserveMapping":
            applyToggle(change, to: \.dv7ToDv81PreserveMappingEnabled)
        case "playback.dv5ToDv81":
            applyToggle(change, to: \.dv5ToDv81Enabled)
        case "playback.stripHdr10Plus":
            applyToggle(change, to: \.stripHdr10PlusSei)
        case "playback.mpvHwdec":
            if case .option(let raw) = change.value,
               let mode = NuvioMpvHardwareDecodeMode(rawValue: raw) {
                mpvHardwareDecodeMode = mode
            }

        // Subtitles
        case "playback.preferredSubtitleLanguage":
            if case .option(let code) = change.value { preferredSubtitleLanguage = code }
        case "playback.secondarySubtitleLanguage":
            if case .option(let code) = change.value {
                secondaryPreferredSubtitleLanguage = code == "none" ? nil : code
            }
        case "playback.useForcedSubtitles":
            applyToggle(change, to: \.useForcedSubtitles)
        case "playback.showOnlyPreferredSubtitleLanguages":
            applyToggle(change, to: \.showOnlyPreferredSubtitleLanguages)
        case "playback.stripSdh":
            applyToggle(change, to: \.stripSdh)
        case "playback.subtitleSize":
            if case .number(let value) = change.value {
                subtitleSizePercent = clampInt(
                    value, NuvioSettingsLimits.subtitleSizeRange, NuvioSettingsLimits.subtitleSizeStep
                )
            }
        case "playback.subtitleVerticalOffset":
            if case .number(let value) = change.value {
                subtitleVerticalOffsetPercent = clampInt(
                    value, NuvioSettingsLimits.subtitleVerticalOffsetRange, 1
                )
            }
        case "playback.subtitleBold":
            applyToggle(change, to: \.subtitleBold)
        case "playback.subtitleOutline":
            applyToggle(change, to: \.subtitleOutlineEnabled)
        case "playback.useLibass":
            applyToggle(change, to: \.useLibass)
        case "playback.libassRenderType":
            if case .option(let raw) = change.value,
               let renderType = NuvioLibassRenderType(rawValue: raw) {
                libassRenderType = renderType
            }

        // Autoplay
        case "playback.reuseLastLink":
            applyToggle(change, to: \.streamReuseLastLinkEnabled)
        case "playback.reuseLastLinkCacheHours":
            if case .option(let raw) = change.value,
               let hours = Int(raw) {
                streamReuseLastLinkCacheHours =
                    NuvioSettingsLimits.reuseLastLinkCacheHourOptions.min { abs($0 - hours) < abs($1 - hours) } ?? 24
            }
        case "playback.autoPlayMode":
            if case .option(let raw) = change.value,
               let mode = NuvioStreamAutoPlayMode(rawValue: raw) {
                streamAutoPlayMode = mode
            }
        case "playback.autoPlayTimeout":
            if case .number(let value) = change.value {
                // Slider position 31 (beyond the bounded 30s maximum) is the
                // unlimited entry of the Android discrete value list.
                if value >= 31 {
                    streamAutoPlayTimeoutSeconds = NuvioSettingsLimits.streamAutoPlayTimeoutUnlimited
                } else {
                    streamAutoPlayTimeoutSeconds = NuvioSettingsLimits.normalizedAutoPlayTimeout(Int(value))
                }
            }
        case "playback.postPlayRecommendations":
            applyToggle(change, to: \.postPlayRecommendationsEnabled)
        case "playback.postPlayMovieThreshold":
            if case .number(let value) = change.value {
                postPlayMovieThresholdPercent = Swift.min(
                    Swift.max(Int(value.rounded()), NuvioSettingsLimits.minPostPlayMovieThresholdPercent),
                    NuvioSettingsLimits.maxPostPlayMovieThresholdPercent
                )
            }
        case "playback.nextEpisode":
            applyToggle(change, to: \.streamAutoPlayNextEpisodeEnabled)
        case "playback.nextEpisodeFallback":
            applyToggle(change, to: \.streamAutoPlayNextEpisodeFallbackEnabled)
        case "playback.stillWatching":
            applyToggle(change, to: \.stillWatchingEnabled)
        case "playback.stillWatchingThreshold":
            if case .number(let value) = change.value {
                stillWatchingEpisodeThreshold = Swift.min(
                    Swift.max(Int(value.rounded()), NuvioSettingsLimits.minStillWatchingThreshold),
                    NuvioSettingsLimits.maxStillWatchingThreshold
                )
            }
        case "playback.preferBingeGroup":
            applyToggle(change, to: \.streamAutoPlayPreferBingeGroupForNextEpisode)
        case "playback.reuseBingeGroup":
            applyToggle(change, to: \.streamAutoPlayReuseBingeGroup)
        case "playback.nextEpisodeThresholdMode":
            if case .option(let raw) = change.value,
               let mode = NuvioNextEpisodeThresholdMode(rawValue: raw) {
                nextEpisodeThresholdMode = mode
            }
        case "playback.nextEpisodeThresholdPercent":
            if case .number(let value) = change.value {
                nextEpisodeThresholdPercent = clampHalfStep(
                    value, NuvioSettingsLimits.nextEpisodeThresholdPercentRange
                )
            }
        case "playback.nextEpisodeThresholdMinutes":
            if case .number(let value) = change.value {
                nextEpisodeThresholdMinutesBeforeEnd = clampHalfStep(
                    value, NuvioSettingsLimits.nextEpisodeThresholdMinutesRange
                )
            }
        case "playback.autoPlaySource":
            if case .option(let raw) = change.value,
               let source = NuvioStreamAutoPlaySource(rawValue: raw) {
                streamAutoPlaySource = source
            }
        case "playback.autoPlayRegex":
            if case .text(let raw) = change.value { streamAutoPlayRegex = raw }

        // Buffer and network
        case "playback.nuvioPerformanceMode":
            applyToggle(change, to: \.nuvioPerformanceModeEnabled)
        case "playback.bufferEngine":
            applyToggle(change, to: \.bufferEngineEnabled)
        case "playback.bufferMin":
            if case .number(let value) = change.value {
                minBufferSeconds = bufferDurationClamp(
                    value, step: nuvioPerformanceModeEnabled
                        ? NuvioSettingsLimits.bufferDurationStepPerformance
                        : NuvioSettingsLimits.bufferDurationStepStandard
                )
                maxBufferSeconds = Swift.max(maxBufferSeconds, minBufferSeconds)
            }
        case "playback.bufferMax":
            if case .number(let value) = change.value {
                maxBufferSeconds = Swift.max(
                    bufferDurationClamp(
                        value, step: nuvioPerformanceModeEnabled
                            ? NuvioSettingsLimits.bufferDurationStepPerformance
                            : NuvioSettingsLimits.bufferDurationStepStandard
                    ),
                    minBufferSeconds
                )
            }
        case "playback.bufferInitial":
            if case .number(let value) = change.value {
                bufferForPlaybackSeconds = clampInt(
                    value, NuvioSettingsLimits.bufferForPlaybackRange, 1
                )
            }
        case "playback.bufferAfterRebuffer":
            if case .number(let value) = change.value {
                bufferForPlaybackAfterRebufferSeconds = clampInt(
                    value, NuvioSettingsLimits.bufferAfterRebufferRange, 1
                )
            }
        case "playback.bufferBack":
            if case .number(let value) = change.value {
                backBufferSeconds = clampInt(
                    value, NuvioSettingsLimits.backBufferRange, NuvioSettingsLimits.backBufferStep
                )
            }
        case "playback.bufferBudgetManaged":
            applyToggle(change, to: \.bufferBudgetManaged)
        case "playback.bufferTargetSizeMb":
            if case .number(let value) = change.value {
                let overhead = parallelNetworkEnabled && useParallelConnections
                    ? NuvioSettingsLimits.parallelOverheadMb(
                        connections: parallelConnectionCount,
                        chunkSizeMb: (parallelChunkSizeKb + 1023) / 1024
                    )
                    : 0
                let maxMb = NuvioMemoryBudget.maxBufferMbWithOverride(
                    parallelOverheadMb: overhead,
                    allowLargeTargetBuffer: allowLargeTargetBuffer,
                    maxHeapMb: deviceMaxHeapMb
                )
                let stepped = (Int(value) / NuvioSettingsLimits.bufferStepMb)
                    * NuvioSettingsLimits.bufferStepMb
                targetBufferSizeMb = Swift.min(Swift.max(stepped, NuvioSettingsLimits.minBufferMb), maxMb)
            }
        case "playback.bufferAllowLarge":
            applyToggle(change, to: \.allowLargeTargetBuffer)
        case "playback.vodCacheEnabled":
            applyToggle(change, to: \.vodCacheEnabled)
        case "playback.vodCacheAuto":
            if case .toggle(let on) = change.value {
                vodCacheSizeMode = on ? .auto : .manual
            }
        case "playback.vodCacheSizeMb":
            if case .number(let value) = change.value {
                vodCacheSizeMb = Swift.min(
                    Swift.max(Int(value), NuvioSettingsLimits.minVodCacheSizeMb),
                    NuvioSettingsLimits.maxVodCacheSizeMb
                )
            }
        case "playback.parallelNetwork":
            applyToggle(change, to: \.parallelNetworkEnabled)
        case "playback.http2":
            applyToggle(change, to: \.enableHttp2)
        case "playback.parallelConnections":
            applyToggle(change, to: \.useParallelConnections)
        case "playback.parallelConnectionCount":
            if case .number(let value) = change.value {
                let maxCount = nuvioPerformanceModeEnabled
                    ? NuvioSettingsLimits.maxConnectionsPerformance
                    : NuvioSettingsLimits.maxConnections
                parallelConnectionCount = Swift.min(
                    Swift.max(Int(value), NuvioSettingsLimits.minConnections), maxCount
                )
            }
        case "playback.parallelChunkSizeKb":
            if case .option(let raw) = change.value, let kb = Int(raw) {
                parallelChunkSizeKb = kb
            }

        // Advanced / network
        case "network.fastHorizontalNavigation":
            applyToggle(change, to: \.fastHorizontalNavigationEnabled)
        case "network.nuvioFocusScroll":
            applyToggle(change, to: \.nuvioFocusScrollEnabled)
        case "network.rememberLastProfile":
            applyToggle(change, to: \.rememberLastProfileEnabled)
        case "network.confirmExit":
            applyToggle(change, to: \.confirmExitEnabled)
        case "diagnostics.sentryReports":
            applyToggle(change, to: \.sentryReportsEnabled)
        case "diagnostics.playbackIssueReports":
            applyToggle(change, to: \.playbackIssueReportsEnabled)
        case "diagnostics.playerStatsHud":
            applyToggle(change, to: \.playerStatsHudEnabled)

        // About
        case "about.updateChannel":
            if case .option(let raw) = change.value,
               let channel = NuvioUpdateChannel(rawValue: raw) {
                updateChannel = channel
            }
        case "about.updateBanner":
            applyToggle(change, to: \.updateBannerEnabled)

        default:
            break
        }
    }

    private mutating func applyToggle(
        _ change: NuvioSettingsChange,
        to path: WritableKeyPath<NuvioSettingsState, Bool>
    ) {
        if case .toggle(let on) = change.value {
            self[keyPath: path] = on
        }
    }

    private func bufferDurationClamp(_ value: Double, step: Int) -> Int {
        let maxDuration = nuvioPerformanceModeEnabled
            ? NuvioSettingsLimits.maxBufferSecondsPerformance
            : NuvioSettingsLimits.maxBufferSecondsStandard
        let clamped = Swift.min(Swift.max(Int(value), NuvioSettingsLimits.minBufferSeconds), maxDuration)
        return (clamped / step) * step
    }
}

func clampInt(_ value: Double, _ range: ClosedRange<Int>, _ step: Int) -> Int {
    let lower = Double(range.lowerBound)
    let upper = Double(range.upperBound)
    let clamped = Swift.min(Swift.max(value, lower), upper)
    let stepped = (Int(clamped) / step) * step
    return Swift.min(Swift.max(stepped, range.lowerBound), range.upperBound)
}

func clampHalfStep(_ value: Double, _ range: ClosedRange<Double>) -> Double {
    let clamped = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    let step = NuvioSettingsLimits.nextEpisodeThresholdStep
    return (clamped / step).rounded() * step
}
