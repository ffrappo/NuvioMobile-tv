import Foundation

/// Playback sections, part 1: General, Player, Audio, and Subtitles,
/// mirroring `PlaybackSettingsSections.kt`, `PlaybackAudioSettings.kt`, and
/// `PlaybackSubtitleSettings.kt`.
public enum NuvioPlaybackTree {
    static let autoPlayModeOptions = [
        NuvioSettingOption(id: "MANUAL", title: "Manual", subtitle: "Pick a stream yourself"),
        NuvioSettingOption(id: "FIRST_STREAM", title: "First stream", subtitle: "Auto-play the first result"),
        NuvioSettingOption(id: "REGEX_MATCH", title: "Regex match", subtitle: "Auto-play the first match"),
    ]

    static func autoPlayModeTitle(_ mode: NuvioStreamAutoPlayMode) -> String {
        autoPlayModeOptions.first { $0.id == mode.rawValue }?.title ?? "Manual"
    }

    static func playbackSections(_ state: NuvioSettingsState) -> [NuvioSettingsSection] {
        [
            generalSection(state),
            NuvioAudioTree.audioSection(state),
        ]
    }

    // MARK: - General (PlaybackSettingsSections.kt)

    static func generalSection(_ state: NuvioSettingsState) -> NuvioSettingsSection {
        var settings: [NuvioSetting] = [
            NuvioSetting(
                id: "playback.loadingOverlay",
                title: "Loading overlay",
                subtitle: "Show a backdrop while the stream opens",
                systemImage: "photo",
                kind: .toggle,
                value: .toggle(state.loadingOverlayEnabled)
            ),
            NuvioSetting(
                id: "playback.pauseOverlay",
                title: "Pause overlay",
                subtitle: "Dim artwork while playback is paused",
                systemImage: "pause.circle",
                kind: .toggle,
                value: .toggle(state.pauseOverlayEnabled)
            ),
            NuvioSetting(
                id: "playback.osdClock",
                title: "Show clock",
                subtitle: "Display the wall clock in the player overlay",
                systemImage: "clock",
                kind: .toggle,
                value: .toggle(state.osdClockEnabled)
            ),
            NuvioSetting(
                id: "playback.skipIntroButton",
                title: "Skip intro button",
                subtitle: "Offer a skip button during opening sequences",
                systemImage: "forward.end",
                kind: .toggle,
                value: .toggle(state.skipIntroEnabled)
            ),
            NuvioSetting(
                id: "playback.parentalGuide",
                title: "Parental guide",
                subtitle: "Show content advisories before playback",
                systemImage: "shield.lefthalf.filled",
                kind: .toggle,
                value: .toggle(state.parentalGuideEnabled)
            ),
        ]
        settings.append(autoSkipRow(
            id: "playback.autoSkipIntro",
            title: "Auto-skip intro",
            subtitle: "Skip detected intro segments automatically",
            segment: .intro,
            state: state
        ))
        settings.append(autoSkipRow(
            id: "playback.autoSkipRecap",
            title: "Auto-skip recap",
            subtitle: "Skip detected recap segments automatically",
            segment: .recap,
            state: state
        ))
        settings.append(autoSkipRow(
            id: "playback.autoSkipOutro",
            title: "Auto-skip outro",
            subtitle: "Skip detected outro segments automatically",
            segment: .outro,
            state: state
        ))
        settings.append(NuvioSetting(
            id: "playback.playerPreference",
            title: "Player",
            subtitle: "Choose where streams are played",
            systemImage: "play.rectangle",
            kind: .optionPicker([
                NuvioSettingOption(id: "INTERNAL", title: "Internal player"),
                NuvioSettingOption(id: "EXTERNAL", title: "External player"),
            ]),
            value: .option(state.playerPreference.rawValue),
            valueText: state.playerPreference == .internalPlayer ? "Internal player" : "External player"
        ))
        if state.playerPreference == .external {
            settings.append(NuvioSetting(
                id: "playback.externalForwardSubtitles",
                title: "Forward subtitles",
                subtitle: "Pass subtitle streams to the external player",
                systemImage: "captions.bubble",
                kind: .toggle,
                value: .toggle(state.externalPlayerForwardSubtitles)
            ))
            settings.append(NuvioSetting(
                id: "playback.externalSendSkipSegments",
                title: "Send skip segments",
                subtitle: "Forward detected skip markers to the external player",
                systemImage: "forward",
                kind: .toggle,
                value: .toggle(state.externalPlayerSendSkipSegments)
            ))
        }
        if state.playerPreference == .internalPlayer {
            settings.append(NuvioSetting(
                id: "playback.internalPlayerEngine",
                title: "Internal player engine",
                subtitle: "Decoder used by the internal player",
                systemImage: "cpu",
                kind: .optionPicker([
                    NuvioSettingOption(id: "EXOPLAYER", title: "ExoPlayer"),
                    NuvioSettingOption(id: "MVP_PLAYER", title: "mpv"),
                    NuvioSettingOption(id: "AUTO", title: "Automatic"),
                ]),
                value: .option(state.internalPlayerEngine.rawValue),
                valueText: engineTitle(state.internalPlayerEngine)
            ))
            settings.append(NuvioSetting(
                id: "playback.autoSwitchInternalPlayerOnError",
                title: "Switch engine on error",
                subtitle: "Fall back to the other engine if playback fails",
                systemImage: "arrow.2.squarepath",
                kind: .toggle,
                value: .toggle(state.autoSwitchInternalPlayerOnError)
            ))
        }
        settings.append(NuvioSetting(
            id: "playback.frameRateMatching",
            title: "Frame rate matching",
            subtitle: "Match the display refresh rate to the video",
            systemImage: "rectangle.and.text.magnifyingglass",
            kind: .optionPicker([
                NuvioSettingOption(id: "OFF", title: "Off"),
                NuvioSettingOption(id: "START", title: "On start"),
                NuvioSettingOption(id: "START_STOP", title: "On start & stop"),
            ]),
            value: .option(state.frameRateMatchingMode.rawValue),
            valueText: frameRateTitle(state.frameRateMatchingMode)
        ))
        if state.frameRateMatchingMode != .off {
            settings.append(NuvioSetting(
                id: "playback.resolutionMatching",
                title: "Resolution matching",
                subtitle: "Also match the display resolution",
                systemImage: "aspectratio",
                kind: .toggle,
                value: .toggle(state.resolutionMatchingEnabled)
            ))
        }
        settings.append(NuvioSetting(
            id: "playback.showLoadingStatus",
            title: "Show loading status",
            subtitle: "Display stream resolution details while loading",
            systemImage: "info.circle",
            kind: .toggle,
            value: .toggle(state.showPlayerLoadingStatus)
        ))
        settings.append(NuvioSetting(
            id: "playback.hideTorrentStats",
            title: "Hide torrent stats",
            subtitle: "Hide peers and seeds during torrent playback",
            systemImage: "eye.slash",
            kind: .toggle,
            value: .toggle(state.hideTorrentStats)
        ))
        return NuvioSettingsSection(
            id: "playback.general",
            category: .playback,
            title: "General",
            subtitle: "Player essentials",
            settings: settings
        )
    }

    static func autoSkipRow(
        id: String,
        title: String,
        subtitle: String,
        segment: NuvioAutoSkipSegmentType,
        state: NuvioSettingsState
    ) -> NuvioSetting {
        NuvioSetting(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: "forward.fill",
            kind: .toggle,
            value: .toggle(state.autoSkipSegmentTypes.contains(segment))
        )
    }

    static func engineTitle(_ engine: NuvioInternalPlayerEngine) -> String {
        switch engine {
        case .exoplayer: return "ExoPlayer"
        case .mpvPlayer: return "mpv"
        case .auto: return "Automatic"
        }
    }

    static func frameRateTitle(_ mode: NuvioFrameRateMatchingMode) -> String {
        switch mode {
        case .off: return "Off"
        case .start: return "On start"
        case .startStop: return "On start & stop"
        }
    }
}
