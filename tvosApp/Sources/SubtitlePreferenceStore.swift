import Foundation

struct SubtitleTrackPreference: Codable, Equatable {
    enum Selection: String, Codable {
        case disabled
        case internalTrack
    }

    let selection: Selection
    let trackID: Int64?
    let language: String?
    let name: String?

    static let disabled = SubtitleTrackPreference(
        selection: .disabled,
        trackID: nil,
        language: nil,
        name: nil
    )

    init(track: PlaybackTrack?) {
        guard let track else {
            self = .disabled
            return
        }
        selection = .internalTrack
        trackID = track.id
        language = track.language?.trimmedNonEmpty
        name = track.title.trimmedNonEmpty
    }

    private init(
        selection: Selection,
        trackID: Int64?,
        language: String?,
        name: String?
    ) {
        self.selection = selection
        self.trackID = trackID
        self.language = language
        self.name = name
    }
}

struct SubtitleAppearancePreference: Codable, Equatable {
    static let defaultFontSize = 52
    static let defaultDelayMilliseconds = 0

    let fontSize: Int
    let delayMilliseconds: Int

    init(fontSize: Int, delayMilliseconds: Int) {
        self.fontSize = min(max(fontSize, 24), 96)
        self.delayMilliseconds = min(max(delayMilliseconds, -60_000), 60_000)
    }
}

final class SubtitlePreferenceStore {
    private let defaults: UserDefaults
    private let selectionPrefix = "nuvio.tv.subtitle.selection.v1"
    private let fontSizePrefix = "nuvio.tv.subtitle.fontSize.v1"
    private let delayPrefix = "nuvio.tv.subtitle.delay.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selection(contentID: String, profileID: Int) -> SubtitleTrackPreference? {
        decode(SubtitleTrackPreference.self, key: selectionKey(contentID, profileID))
    }

    func saveSelection(
        _ preference: SubtitleTrackPreference,
        contentID: String,
        profileID: Int
    ) {
        encode(preference, key: selectionKey(contentID, profileID))
    }

    func appearance(profileID: Int, videoID: String) -> SubtitleAppearancePreference {
        let fontKey = fontSizeKey(profileID)
        let delayKey = delayKey(videoID, profileID)
        let fontSize = defaults.object(forKey: fontKey) == nil
            ? SubtitleAppearancePreference.defaultFontSize
            : defaults.integer(forKey: fontKey)
        let delay = defaults.object(forKey: delayKey) == nil
            ? SubtitleAppearancePreference.defaultDelayMilliseconds
            : defaults.integer(forKey: delayKey)
        return SubtitleAppearancePreference(fontSize: fontSize, delayMilliseconds: delay)
    }

    func saveAppearance(
        _ preference: SubtitleAppearancePreference,
        profileID: Int,
        videoID: String
    ) {
        defaults.set(preference.fontSize, forKey: fontSizeKey(profileID))
        defaults.set(preference.delayMilliseconds, forKey: delayKey(videoID, profileID))
    }

    func clear(profileID: Int) {
        defaults.removeObject(forKey: fontSizeKey(profileID))
        let prefixes = [
            "\(selectionPrefix).\(profileID).",
            "\(delayPrefix).\(profileID).",
        ]
        defaults.dictionaryRepresentation().keys
            .filter { key in prefixes.contains { key.hasPrefix($0) } }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    static func matchingTrack(
        for preference: SubtitleTrackPreference,
        in tracks: [PlaybackTrack]
    ) -> PlaybackTrack? {
        guard preference.selection == .internalTrack else { return nil }
        if let id = preference.trackID, let match = tracks.first(where: { $0.id == id }) {
            return match
        }
        if let language = preference.language?.normalizedLanguage,
           let match = tracks.first(where: { $0.language?.normalizedLanguage == language }) {
            return match
        }
        if let name = preference.name,
           let match = tracks.first(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
            return match
        }
        return nil
    }

    private func selectionKey(_ contentID: String, _ profileID: Int) -> String {
        let encoded = Data(contentID.utf8).base64EncodedString()
        return "\(selectionPrefix).\(profileID).\(encoded)"
    }

    private func fontSizeKey(_ profileID: Int) -> String {
        "\(fontSizePrefix).\(profileID)"
    }

    private func delayKey(_ videoID: String, _ profileID: Int) -> String {
        let encoded = Data(videoID.utf8).base64EncodedString()
        return "\(delayPrefix).\(profileID).\(encoded)"
    }

    private func decode<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

private extension String {
    var normalizedLanguage: String {
        lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init) ?? lowercased()
    }
}
