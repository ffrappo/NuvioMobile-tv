import Foundation

/// Playback sections, part 2: Subtitles, Autoplay, and Buffer & Network,
/// mirroring `PlaybackSubtitleSettings.kt`, `PlaybackAutoPlaySettings.kt`, and
/// `PlaybackBufferNetworkSettings.kt`.
public enum NuvioAutoPlayBufferTree {
    static func playbackSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        [
            subtitleSection(state),
            autoPlaySection(state),
            NuvioBufferTree.bufferNetworkSection(state),
        ]
    }

    // MARK: - Subtitles (PlaybackSubtitleSettings.kt)

    static func subtitleSection(_ state: NuvioSettingsState) -> NuvioSettingsSection {
        var settings: [NuvioSetting] = [
            NuvioSetting(
                id: "playback.preferredSubtitleLanguage",
                title: "Preferred language",
                systemImage: "globe",
                kind: .optionPicker(subtitleLanguagePickerOptions),
                value: .option(state.preferredSubtitleLanguage),
                valueText: preferredSubtitleTitle(state)
            ),
            NuvioSetting(
                id: "playback.secondarySubtitleLanguage",
                title: "Secondary language",
                systemImage: "globe.central.south.asia",
                kind: .optionPicker(subtitleLanguagePickerOptions),
                value: .option(state.secondaryPreferredSubtitleLanguage ?? "none"),
                valueText: NuvioSettingsTree.languageTitle(for: state.secondaryPreferredSubtitleLanguage)
            ),
            NuvioSetting(
                id: "playback.useForcedSubtitles",
                title: "Use forced subtitles",
                subtitle: "Prefer forced tracks for foreign audio",
                systemImage: "captions.bubble",
                kind: .toggle,
                value: .toggle(state.useForcedSubtitles)
            ),
            NuvioSetting(
                id: "playback.showOnlyPreferredSubtitleLanguages",
                title: "Show only preferred languages",
                subtitle: "Hide subtitle tracks outside your languages",
                systemImage: "line.3.horizontal.decrease.circle",
                kind: .toggle,
                value: .toggle(state.showOnlyPreferredSubtitleLanguages)
            ),
            NuvioSetting(
                id: "playback.stripSdh",
                title: "Strip SDH",
                subtitle: "Remove sound and music captions",
                systemImage: "captions.bubble.fill",
                kind: .toggle,
                value: .toggle(state.stripSdh)
            ),
            NuvioSetting(
                id: "playback.subtitleSize",
                title: "Subtitle size",
                systemImage: "textformat.size",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.subtitleSizeRange.lowerBound),
                    maximum: Double(NuvioSettingsLimits.subtitleSizeRange.upperBound),
                    step: Double(NuvioSettingsLimits.subtitleSizeStep)
                )),
                value: .number(Double(state.subtitleSizePercent)),
                valueText: "\(state.subtitleSizePercent)%"
            ),
            NuvioSetting(
                id: "playback.subtitleVerticalOffset",
                title: "Vertical position",
                systemImage: "arrow.up.and.down",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.subtitleVerticalOffsetRange.lowerBound),
                    maximum: Double(NuvioSettingsLimits.subtitleVerticalOffsetRange.upperBound),
                    step: 1
                )),
                value: .number(Double(state.subtitleVerticalOffsetPercent)),
                valueText: "\(state.subtitleVerticalOffsetPercent)%"
            ),
            NuvioSetting(
                id: "playback.subtitleBold",
                title: "Bold",
                subtitle: "Render subtitles with a heavier weight",
                systemImage: "bold",
                kind: .toggle,
                value: .toggle(state.subtitleBold)
            ),
            NuvioSetting(
                id: "playback.subtitleOutline",
                title: "Outline",
                subtitle: "Draw an outline around subtitle text",
                systemImage: "circle.dashed",
                kind: .toggle,
                value: .toggle(state.subtitleOutlineEnabled)
            ),
            NuvioSetting(
                id: "playback.useLibass",
                title: "Libass",
                subtitle: "Render styled subtitles with libass",
                systemImage: "text.badge.star",
                kind: .toggle,
                value: .toggle(state.useLibass)
            ),
        ]
        if state.useLibass {
            settings.append(NuvioSetting(
                id: "playback.libassRenderType",
                title: "Libass render mode",
                subtitle: "How styled subtitles are composited",
                systemImage: "paintbrush",
                kind: .optionPicker([
                    NuvioSettingOption(id: "OVERLAY_OPEN_GL", title: "Overlay (GPU)"),
                    NuvioSettingOption(id: "OVERLAY_CANVAS", title: "Overlay (canvas)"),
                    NuvioSettingOption(id: "EFFECTS_OPEN_GL", title: "Effects (GPU)"),
                    NuvioSettingOption(id: "EFFECTS_CANVAS", title: "Effects (canvas)"),
                    NuvioSettingOption(id: "CUES", title: "Standard cues"),
                ]),
                value: .option(state.libassRenderType.rawValue),
                valueText: libassTitle(state.libassRenderType)
            ))
        }
        return NuvioSettingsSection(
            id: "playback.subtitles",
            category: .playback,
            title: "Subtitles",
            subtitle: "Language and styling",
            settings: settings
        )
    }

    static var subtitleLanguagePickerOptions: [NuvioSettingOption] {
        var options = [NuvioSettingOption(id: "none", title: "Not set")]
        options.append(contentsOf: NuvioSettingsTree.availableLanguages)
        return options
    }

    static func preferredSubtitleTitle(_ state: NuvioSettingsState) -> String {
        if state.isPreferredSubtitleLanguageSystemDefault {
            return "System default"
        }
        return NuvioSettingsTree.languageTitle(for: state.preferredSubtitleLanguage)
    }

    static func libassTitle(_ renderType: NuvioLibassRenderType) -> String {
        switch renderType {
        case .overlayOpenGl: return "Overlay (GPU)"
        case .overlayCanvas: return "Overlay (canvas)"
        case .effectsOpenGl: return "Effects (GPU)"
        case .effectsCanvas: return "Effects (canvas)"
        case .cues: return "Standard cues"
        }
    }

    // MARK: - Autoplay (PlaybackAutoPlaySettings.kt)

    static func autoPlaySection(_ state: NuvioSettingsState) -> NuvioSettingsSection {
        var settings: [NuvioSetting] = [
            NuvioSetting(
                id: "playback.reuseLastLink",
                title: "Reuse last link",
                subtitle: "Play from the cached stream link first",
                systemImage: "clock.arrow.circlepath",
                kind: .toggle,
                value: .toggle(state.streamReuseLastLinkEnabled)
            ),
        ]
        if state.streamReuseLastLinkEnabled {
            settings.append(NuvioSetting(
                id: "playback.reuseLastLinkCacheHours",
                title: "Link cache duration",
                subtitle: "How long cached links stay valid",
                systemImage: "tray.full",
                kind: .optionPicker(
                    NuvioSettingsLimits.reuseLastLinkCacheHourOptions.map {
                        NuvioSettingOption(
                            id: String($0),
                            title: NuvioSettingsLimits.reuseCacheDurationText(hours: $0)
                        )
                    }
                ),
                value: .option(String(state.streamReuseLastLinkCacheHours)),
                valueText: NuvioSettingsLimits.reuseCacheDurationText(
                    hours: state.streamReuseLastLinkCacheHours
                )
            ))
        }
        settings.append(NuvioSetting(
            id: "playback.autoPlayMode",
            title: "Stream selection",
            subtitle: "How a stream is chosen",
            systemImage: "play.circle",
            kind: .optionPicker(NuvioPlaybackTree.autoPlayModeOptions),
            value: .option(state.streamAutoPlayMode.rawValue),
            valueText: NuvioPlaybackTree.autoPlayModeTitle(state.streamAutoPlayMode)
        ))
        settings.append(NuvioSetting(
            id: "playback.autoPlayTimeout",
            title: "Stream timeout",
            subtitle: "How long to wait for a playable stream",
            systemImage: "timer",
            kind: .slider(NuvioSliderSpec(
                minimum: 0,
                maximum: 31,
                step: 1
            )),
            value: .number(timeoutSliderValue(state.streamAutoPlayTimeoutSeconds)),
            valueText: NuvioSettingsLimits.autoPlayTimeoutText(state.streamAutoPlayTimeoutSeconds)
        ))
        settings.append(NuvioSetting(
            id: "playback.postPlayRecommendations",
            title: "Post-play recommendations",
            subtitle: "Suggest related titles after playback ends",
            systemImage: "sparkles",
            kind: .toggle,
            value: .toggle(state.postPlayRecommendationsEnabled)
        ))
        if state.postPlayRecommendationsEnabled {
            settings.append(NuvioSetting(
                id: "playback.postPlayMovieThreshold",
                title: "Movie completion threshold",
                subtitle: "Watched percentage that counts as finished",
                systemImage: "chart.line.uptrend.xyaxis",
                kind: .slider(NuvioSliderSpec(
                    minimum: Double(NuvioSettingsLimits.minPostPlayMovieThresholdPercent),
                    maximum: Double(NuvioSettingsLimits.maxPostPlayMovieThresholdPercent),
                    step: 1
                )),
                value: .number(Double(state.postPlayMovieThresholdPercent)),
                valueText: "\(state.postPlayMovieThresholdPercent)%"
            ))
        }
        settings.append(NuvioSetting(
            id: "playback.nextEpisode",
            title: "Play next episode",
            subtitle: "Automatically continue the next episode",
            systemImage: "forward.end",
            kind: .toggle,
            value: .toggle(state.streamAutoPlayNextEpisodeEnabled)
        ))
        if state.streamAutoPlayNextEpisodeEnabled {
            if state.streamAutoPlayMode == .manual {
                settings.append(NuvioSetting(
                    id: "playback.nextEpisodeFallback",
                    title: "Fallback to first stream",
                    subtitle: "Use the first stream when no link is cached",
                    systemImage: "arrow.triangle.swap",
                    kind: .toggle,
                    value: .toggle(state.streamAutoPlayNextEpisodeFallbackEnabled)
                ))
            }
            settings.append(NuvioSetting(
                id: "playback.stillWatching",
                title: "Still watching",
                subtitle: "Confirm you are still watching between episodes",
                systemImage: "eye",
                kind: .toggle,
                value: .toggle(state.stillWatchingEnabled)
            ))
            if state.stillWatchingEnabled {
                settings.append(NuvioSetting(
                    id: "playback.stillWatchingThreshold",
                    title: "Episodes before prompt",
                    subtitle: "Consecutive episodes before the prompt",
                    systemImage: "repeat",
                    kind: .slider(NuvioSliderSpec(
                        minimum: Double(NuvioSettingsLimits.minStillWatchingThreshold),
                        maximum: Double(NuvioSettingsLimits.maxStillWatchingThreshold),
                        step: 1
                    )),
                    value: .number(Double(state.stillWatchingEpisodeThreshold)),
                    valueText: String(state.stillWatchingEpisodeThreshold)
                ))
            }
        }
        settings.append(NuvioSetting(
            id: "playback.preferBingeGroup",
            title: "Prefer binge group",
            subtitle: "Continue from the same group of episodes",
            systemImage: "square.stack.3d.up",
            kind: .toggle,
            value: .toggle(state.streamAutoPlayPreferBingeGroupForNextEpisode)
        ))
        if state.streamAutoPlayPreferBingeGroupForNextEpisode {
            settings.append(NuvioSetting(
                id: "playback.reuseBingeGroup",
                title: "Reuse binge group",
                subtitle: "Keep the group selection between sessions",
                systemImage: "square.stack.3d.up.fill",
                kind: .toggle,
                value: .toggle(state.streamAutoPlayReuseBingeGroup)
            ))
        }
        settings.append(NuvioSetting(
            id: "playback.nextEpisodeThresholdMode",
            title: "Threshold mode",
            subtitle: "When the next-episode countdown starts",
            systemImage: "slider.horizontal.3",
            kind: .optionPicker([
                NuvioSettingOption(id: "PERCENTAGE", title: "Percentage", subtitle: "e.g. 99% watched"),
                NuvioSettingOption(id: "MINUTES_BEFORE_END", title: "Minutes before end", subtitle: "e.g. 2 min left"),
            ]),
            value: .option(state.nextEpisodeThresholdMode.rawValue),
            valueText: state.nextEpisodeThresholdMode == .percentage
                ? "Percentage" : "Minutes before end"
        ))
        if state.nextEpisodeThresholdMode == .percentage {
            settings.append(NuvioSetting(
                id: "playback.nextEpisodeThresholdPercent",
                title: "Threshold percentage",
                subtitle: "Watched percentage that triggers autoplay",
                systemImage: "percent",
                kind: .slider(NuvioSliderSpec(
                    minimum: NuvioSettingsLimits.nextEpisodeThresholdPercentRange.lowerBound,
                    maximum: NuvioSettingsLimits.nextEpisodeThresholdPercentRange.upperBound,
                    step: NuvioSettingsLimits.nextEpisodeThresholdStep
                )),
                value: .number(state.nextEpisodeThresholdPercent),
                valueText: "\(NuvioSettingsLimits.halfStepText(state.nextEpisodeThresholdPercent))%"
            ))
        } else {
            settings.append(NuvioSetting(
                id: "playback.nextEpisodeThresholdMinutes",
                title: "Minutes before end",
                subtitle: "Remaining time that triggers autoplay",
                systemImage: "clock",
                kind: .slider(NuvioSliderSpec(
                    minimum: NuvioSettingsLimits.nextEpisodeThresholdMinutesRange.lowerBound,
                    maximum: NuvioSettingsLimits.nextEpisodeThresholdMinutesRange.upperBound,
                    step: NuvioSettingsLimits.nextEpisodeThresholdStep
                )),
                value: .number(state.nextEpisodeThresholdMinutesBeforeEnd),
                valueText: "\(NuvioSettingsLimits.halfStepText(state.nextEpisodeThresholdMinutesBeforeEnd)) min"
            ))
        }
        if state.streamAutoPlayMode != .manual {
            settings.append(NuvioSetting(
                id: "playback.autoPlaySource",
                title: "Source scope",
                subtitle: "Where autoplay may pick streams from",
                systemImage: "scope",
                kind: .optionPicker([
                    NuvioSettingOption(id: "ALL_SOURCES", title: "All sources"),
                    NuvioSettingOption(id: "INSTALLED_ADDONS_ONLY", title: "Installed addons"),
                    NuvioSettingOption(id: "ENABLED_PLUGINS_ONLY", title: "Enabled plugins"),
                ]),
                value: .option(state.streamAutoPlaySource.rawValue),
                valueText: autoPlaySourceTitle(state.streamAutoPlaySource)
            ))
        }
        if state.streamAutoPlayMode == .regexMatch {
            settings.append(NuvioSetting(
                id: "playback.autoPlayRegex",
                title: "Regex",
                subtitle: state.streamAutoPlayRegex.isEmpty
                    ? "Matches every title" : state.streamAutoPlayRegex,
                systemImage: "number",
                kind: .navigation,
                value: .text(state.streamAutoPlayRegex),
                valueText: state.streamAutoPlayRegex.isEmpty ? "All files" : state.streamAutoPlayRegex
            ))
        }
        return NuvioSettingsSection(
            id: "playback.autoplay",
            category: .playback,
            title: "Autoplay",
            subtitle: "Stream selection and next episode",
            settings: settings
        )
    }

    /// The Android slider exposes the discrete timeout list; position 31 stands
    /// for the unlimited entry (beyond the bounded 30s maximum).
    static func timeoutSliderValue(_ seconds: Int) -> Double {
        seconds == NuvioSettingsLimits.streamAutoPlayTimeoutUnlimited
            ? 31 : Double(seconds)
    }

    static func autoPlaySourceTitle(_ source: NuvioStreamAutoPlaySource) -> String {
        switch source {
        case .allSources: return "All sources"
        case .installedAddonsOnly: return "Installed addons"
        case .enabledPluginsOnly: return "Enabled plugins"
        }
    }
}
