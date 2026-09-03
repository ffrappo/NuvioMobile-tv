import Foundation

/// Reads the NuvioSettingsStore persistence format for the few playback
/// settings consumed outside the settings UI.
enum PersistedPlaybackSetting {
    private static let prefix = "nuvio.tv.settings.v2."

    static func toggle(
        _ settingID: String, default defaultValue: Bool, defaults: UserDefaults = .standard
    ) -> Bool {
        guard let raw = defaults.string(forKey: prefix + settingID),
              raw.hasPrefix("t:") else { return defaultValue }
        return raw == "t:1"
    }

    static func number(_ settingID: String, defaults: UserDefaults = .standard) -> Double? {
        guard let raw = defaults.string(forKey: prefix + settingID),
              raw.hasPrefix("n:"),
              let value = Double(raw.dropFirst(2)) else { return nil }
        return value
    }

    /// The buffer configuration applied at MPV setup (Android
    /// `PlaybackBufferNetworkSettings.kt`): readahead seconds and the
    /// demuxer byte budget.
    static func bufferConfiguration(
        defaults: UserDefaults = .standard
    ) -> (readaheadSeconds: Int, maxBytes: Int) {
        let readahead = number("playback.bufferMax", defaults: defaults).map { Int($0) } ?? 45
        let megabytes = number("playback.bufferTargetSizeMb", defaults: defaults).map { Int($0) } ?? 150
        // Android clamps: buffer seconds 5...120 (1200 in performance
        // mode), memory budget 25...4096 MB (`MemoryBudget.kt`).
        let clampedReadahead = min(
            max(readahead, NuvioSettingsLimits.minBufferSeconds),
            NuvioSettingsLimits.maxBufferSecondsStandard
        )
        let clampedMegabytes = min(
            max(megabytes, NuvioSettingsLimits.minBufferMb),
            NuvioSettingsLimits.maxBufferMb
        )
        return (clampedReadahead, clampedMegabytes * 1_024 * 1_024)
    }
}
