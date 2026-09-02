import Foundation
import SwiftUI

/// Owns the subtitle style preference: loads the Android DataStore key/value
/// form from UserDefaults, applies style changes to the live MPV session,
/// and persists every change for the next playback.
@MainActor
final class SubtitleStyleSettingsStore: ObservableObject {
    @Published private(set) var options: SubtitleStyleOptions

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let values = SubtitleStylePersistenceKey.allCases.reduce(into: [String: Any]()) { dict, key in
            if let value = defaults.object(forKey: key.rawValue) {
                dict[key.rawValue] = value
            }
        }
        options = SubtitleStylePersistence.load(from: values)
    }

    func update(to newOptions: SubtitleStyleOptions) {
        options = newOptions
        persist()
    }

    func toggleSdhFilter(_ enabled: Bool) {
        options.stripSdh = enabled
        persist()
    }

    private func persist() {
        for (key, value) in SubtitleStylePersistence.persistedValues(of: options) {
            defaults.set(value, forKey: key)
        }
    }
}

extension MPVPlaybackSession {
    /// Applies a subtitle style to playback: the size percent maps onto the
    /// MPV point scale (50 percent to 24 pt, 200 percent to 96 pt).
    func applySubtitleStyle(_ options: SubtitleStyleOptions) {
        let fraction = Double(options.sizePercent - SubtitleStyleOptions.sizeRange.lowerBound)
            / Double(SubtitleStyleOptions.sizeRange.upperBound - SubtitleStyleOptions.sizeRange.lowerBound)
        let fontSize = Int((24 + fraction * (96 - 24)).rounded())
        setSubtitleFontSize(fontSize)
    }
}
