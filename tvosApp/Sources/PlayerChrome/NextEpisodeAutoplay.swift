import Foundation
import SwiftUI

/// Next-episode autoplay (Android `playNextEpisode` + `PostPlayMode.AutoPlay`):
/// when an episode ends naturally and the setting is on, the player finds
/// streams for the next episode, shows a countdown, and switches playback.
struct NextEpisodeAutoplayState: Equatable {
    enum Phase: Equatable {
        case searching
        case countdown(secondsRemaining: Int)
    }

    var episode: PlayerEpisodeOption
    var phase: Phase

    var title: String {
        let base = episode.seasonNumber.map { "S\($0)" }
        let episodePart = episode.episodeNumber.map { "E\($0)" }
        let prefix = [base, episodePart].compactMap { $0 }.joined()
        return prefix.isEmpty ? episode.title : "\(prefix) \(episode.title)"
    }
}

/// Reads the persisted autoplay settings (NuvioSettingsStore format).
enum NextEpisodeAutoplaySettings {
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        readToggle("playback.streamAutoPlayNextEpisode", defaults: defaults)
    }

    static func timeoutSeconds(defaults: UserDefaults = .standard) -> Int {
        guard case .number(let value)? = readValue(
            "playback.streamAutoPlayTimeoutSeconds", defaults: defaults
        ) else { return 3 }
        return Int(value)
    }

    /// The end-of-episode trigger fraction from the threshold mode/percent
    /// settings (Android `nextEpisodeThresholdMode` PERCENTAGE default 99).
    static func triggerFraction(defaults: UserDefaults = .standard) -> Double {
        let mode = readValue("playback.nextEpisodeThresholdMode", defaults: defaults)
        // Time-before-end mode needs the duration at call time; the ended
        // player always satisfies it, so the fraction collapses to 0.
        if case .option("TIME_BEFORE_END")? = mode {
            return 0.0
        }
        guard case .number(let percent)? = readValue(
            "playback.nextEpisodeThresholdPercent", defaults: defaults
        ) else { return 0.99 }
        return min(max(percent, 0), 100) / 100
    }

    private static func readValue(
        _ settingID: String, defaults: UserDefaults
    ) -> NuvioSettingValue? {
        guard let raw = defaults.string(forKey: "nuvio.tv.settings.v2.\(settingID)") else {
            return nil
        }
        guard raw.count >= 2, raw.dropFirst(1).first == ":" else { return nil }
        let payload = String(raw.dropFirst(2))
        switch raw.prefix(1) {
        case "t": return .toggle(payload == "1")
        case "o": return .option(payload)
        case "n": return Double(payload).map { .number($0) }
        case "s": return .text(payload)
        default: return nil
        }
    }

    private static func readToggle(_ settingID: String, defaults: UserDefaults) -> Bool {
        if case .toggle(let on)? = readValue(settingID, defaults: defaults) {
            return on
        }
        return false
    }
}

/// The countdown banner. Cancel keeps the user on the ended player with the
/// post-play recommendations visible.
struct NextEpisodeCountdownView: View {
    let state: NextEpisodeAutoplayState
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Up Next")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(state.title.tvSafe)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                if case .searching = state.phase {
                    ProgressView()
                    Text("Finding sources").font(.callout.weight(.semibold))
                } else if case .countdown(let seconds) = state.phase {
                    Text("Playing in \(seconds)")
                        .font(.callout.weight(.semibold))
                }
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: 560)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
