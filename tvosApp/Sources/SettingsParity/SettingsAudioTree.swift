import Foundation

/// Audio section, mirroring `PlaybackAudioSettings.kt`.
public enum NuvioAudioTree {
    // MARK: - Audio (PlaybackAudioSettings.kt)

    static func audioSection(_ state: NuvioSettingsState) -> NuvioSettingsSection {
        var settings: [NuvioSetting] = [
            NuvioSetting(
                id: "playback.preferredAudioLanguage",
                title: "Preferred audio language",
                systemImage: "speaker.wave.2",
                kind: .optionPicker(languagePickerOptions),
                value: .option(state.preferredAudioLanguage),
                valueText: NuvioSettingsTree.languageTitle(for: state.preferredAudioLanguage)
            ),
            NuvioSetting(
                id: "playback.secondaryAudioLanguage",
                title: "Secondary audio language",
                systemImage: "speaker.wave.1",
                kind: .optionPicker(languagePickerOptions),
                value: .option(state.secondaryPreferredAudioLanguage ?? "none"),
                valueText: NuvioSettingsTree.languageTitle(for: state.secondaryPreferredAudioLanguage)
            ),
            NuvioSetting(
                id: "playback.skipSilence",
                title: "Skip silence",
                subtitle: "Fast-forward through silent audio",
                systemImage: "waveform.slash",
                kind: .toggle,
                value: .toggle(state.skipSilence)
            ),
            NuvioSetting(
                id: "playback.rememberAudioDelayPerDevice",
                title: "Remember audio delay per device",
                subtitle: "Store audio offset separately for each TV",
                systemImage: "clock.arrow.2.circlepath",
                kind: .toggle,
                value: .toggle(state.rememberAudioDelayPerDevice)
            ),
            NuvioSetting(
                id: "playback.audioDecoderPriority",
                title: "Decoder priority",
                subtitle: "Prefer the built-in decoder pipeline",
                systemImage: "cpu",
                kind: .optionPicker([
                    NuvioSettingOption(id: "0", title: "Off"),
                    NuvioSettingOption(id: "1", title: "On"),
                    NuvioSettingOption(id: "2", title: "Prefer app decoder"),
                ]),
                value: .option(String(state.audioDecoderPriority.rawValue)),
                valueText: decoderPriorityTitle(state.audioDecoderPriority)
            ),
            NuvioSetting(
                id: "playback.audioDownmix",
                title: "Enable downmix",
                subtitle: "Fold multichannel audio into stereo",
                systemImage: "waveform",
                kind: .toggle,
                value: .toggle(state.downmixEnabled)
            ),
        ]
        if state.downmixEnabled {
            settings.append(NuvioSetting(
                id: "playback.audioChannelCount",
                title: "Number of channels",
                subtitle: "Target channel count when downmixing",
                systemImage: "hifispeaker.2",
                kind: .optionPicker([
                    NuvioSettingOption(id: "0", title: "Auto"),
                    NuvioSettingOption(id: "2", title: "Stereo (2)"),
                    NuvioSettingOption(id: "6", title: "5.1 (6)"),
                    NuvioSettingOption(id: "8", title: "7.1 (8)"),
                ]),
                value: .option(String(state.audioOutputChannelCount)),
                valueText: channelCountTitle(state.audioOutputChannelCount)
            ))
            settings.append(NuvioSetting(
                id: "playback.audioMaintainOriginalOnDownmix",
                title: "Maintain original audio on downmix",
                subtitle: "Keep the original stream and downmix at output",
                systemImage: "waveform.badge.minus",
                kind: .toggle,
                value: .toggle(state.maintainOriginalAudioOnDownmix)
            ))
        }
        settings.append(NuvioSetting(
            id: "playback.audioTunneled",
            title: "Tunneled playback",
            subtitle: "Route audio and video through the system pipeline",
            systemImage: "tunnel",
            kind: .toggle,
            value: .toggle(state.tunneledAudioEnabled)
        ))
        settings.append(NuvioSetting(
            id: "playback.audioForceOpticalPassthrough",
            title: "Force optical passthrough",
            subtitle: "Always send compressed audio to the receiver",
            systemImage: "cable.connector",
            kind: .toggle,
            value: .toggle(state.forceOpticalPassthrough)
        ))
        settings.append(NuvioSetting(
            id: "playback.dv7Handling",
            title: "Dolby Vision handling",
            subtitle: "How DV profile 7 streams are presented",
            systemImage: "sparkles.tv",
            kind: .optionPicker([
                NuvioSettingOption(id: "AUTO", title: "Auto"),
                NuvioSettingOption(id: "HDR10_BASE_LAYER", title: "HDR10 base layer"),
                NuvioSettingOption(id: "DV81_LIBDOVI", title: "DV 8.1 (libdovi)"),
                NuvioSettingOption(id: "STRIP_DV", title: "Strip DV"),
                NuvioSettingOption(id: "OFF", title: "Off"),
            ]),
            value: .option(state.dv7HandlingMode.rawValue),
            valueText: dv7Title(state.dv7HandlingMode)
        ))
        settings.append(NuvioSetting(
            id: "playback.dv7PreserveMapping",
            title: "Preserve mapping on DV 8.1",
            subtitle: "Keep DV metadata mapping during conversion",
            systemImage: "map",
            kind: .toggle,
            value: .toggle(state.dv7ToDv81PreserveMappingEnabled)
        ))
        settings.append(NuvioSetting(
            id: "playback.dv5ToDv81",
            title: "Convert DV 5 to DV 8.1",
            subtitle: "Convert profile 5 streams for broader compatibility",
            systemImage: "arrow.triangle.2.circlepath",
            kind: .toggle,
            value: .toggle(state.dv5ToDv81Enabled)
        ))
        settings.append(NuvioSetting(
            id: "playback.stripHdr10Plus",
            title: "Strip HDR10+",
            subtitle: "Remove dynamic HDR metadata from streams",
            systemImage: "wand.and.stars",
            kind: .toggle,
            value: .toggle(state.stripHdr10PlusSei)
        ))
        settings.append(NuvioSetting(
            id: "playback.mpvHwdec",
            title: "mpv hardware decode",
            subtitle: "Hardware decode strategy for the mpv engine",
            systemImage: "memorychip",
            kind: .optionPicker([
                NuvioSettingOption(id: "LEGACY_DIRECT_COPY", title: "Legacy direct copy"),
                NuvioSettingOption(id: "AUTO_SAFE", title: "Auto safe"),
                NuvioSettingOption(id: "HARDWARE_COPY", title: "Hardware copy"),
                NuvioSettingOption(id: "HARDWARE_DIRECT", title: "Hardware direct"),
                NuvioSettingOption(id: "DISABLED", title: "Disabled"),
            ]),
            value: .option(state.mpvHardwareDecodeMode.rawValue),
            valueText: mpvHwdecTitle(state.mpvHardwareDecodeMode)
        ))
        return NuvioSettingsSection(
            id: "playback.audio",
            category: .playback,
            title: "Audio",
            subtitle: "Tracks, decoders, and Dolby Vision",
            settings: settings
        )
    }

    static var languagePickerOptions: [NuvioSettingOption] {
        var options = [NuvioSettingOption(id: "device", title: "System default")]
        options.append(contentsOf: NuvioSettingsTree.availableLanguages)
        return options
    }

    static func decoderPriorityTitle(_ priority: NuvioAudioDecoderPriority) -> String {
        switch priority {
        case .off: return "Off"
        case .on: return "On"
        case .prefer: return "Prefer app decoder"
        }
    }

    static func channelCountTitle(_ count: Int) -> String {
        switch count {
        case 0: return "Auto"
        case 2: return "Stereo (2)"
        case 6: return "5.1 (6)"
        case 8: return "7.1 (8)"
        default: return String(count)
        }
    }

    static func dv7Title(_ mode: NuvioDv7HandlingMode) -> String {
        switch mode {
        case .auto: return "Auto"
        case .hdr10BaseLayer: return "HDR10 base layer"
        case .dv81Libdovi: return "DV 8.1 (libdovi)"
        case .stripDv: return "Strip DV"
        case .off: return "Off"
        }
    }

    static func mpvHwdecTitle(_ mode: NuvioMpvHardwareDecodeMode) -> String {
        switch mode {
        case .legacyDirectCopy: return "Legacy direct copy"
        case .autoSafe: return "Auto safe"
        case .hardwareCopy: return "Hardware copy"
        case .hardwareDirect: return "Hardware direct"
        case .disabled: return "Disabled"
        }
    }
}
