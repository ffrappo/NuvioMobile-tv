import Foundation

/// Special language rail keys ported from `SubtitleSelectionOverlay.kt`.
enum SubtitleLanguageKey {
    static let off = "__off__"
    static let unknown = "__unknown__"
}

/// Embedded (container) subtitle track, port of Android `TrackInfo` limited to
/// the fields the selection panel renders.
struct SubtitleEmbeddedTrack: Equatable, Identifiable {
    let index: Int
    let name: String
    let language: String?
    let trackID: String?
    let codec: String?
    let isForced: Bool
    let isSelected: Bool

    var id: String { "internal:\(index)" }
}

/// External (addon-provided) subtitle, port of the Android `Subtitle` domain
/// model fields used by the selection overlay.
struct SubtitleExternalTrack: Equatable, Identifiable {
    let addonName: String
    let language: String
    let externalID: String
    let url: String
    let isSelected: Bool

    /// Port of `addonSubtitleOptionId`: `"addon:{addonName}:{id}:{url}"`.
    var id: String { "addon:\(addonName):\(externalID):\(url)" }
}

/// The currently effective subtitle selection.
enum SubtitleTrackSelection: Equatable {
    case off
    case embedded(SubtitleEmbeddedTrack)
    case external(SubtitleExternalTrack)

    var optionID: String? {
        switch self {
        case .off: return nil
        case .embedded(let track): return track.id
        case .external(let track): return track.id
        }
    }
}

/// One language entry in the left rail of the Android subtitle overlay.
struct SubtitleLanguageRailItem: Equatable, Identifiable {
    let key: String
    let label: String
    let count: Int

    var id: String { key }
}

enum SubtitleTrackOptionKind: Equatable {
    case embedded
    case external
}

/// One selectable track option, port of `SubtitleOptionRailItem`.
struct SubtitleTrackOptionItem: Equatable, Identifiable {
    let id: String
    let kind: SubtitleTrackOptionKind
    let title: String
    let sourceLabel: String
    let meta: String?
    let isSelected: Bool
}

/// Pure composition rules ported from the private helpers of
/// `SubtitleSelectionOverlay.kt`. No UI, no decoder, fully testable.
enum SubtitleSelectionComposer {
    /// Port of `normalizeOverlayLanguageKey`.
    static func languageKey(_ language: String?) -> String {
        guard let language, !language.isEmpty else { return SubtitleLanguageKey.unknown }
        let normalized = SubtitleLanguageCatalog.normalizeLanguageCode(language)
        switch normalized {
        case "pt-br", "es-419":
            return normalized
        default:
            let primary = normalized
                .components(separatedBy: "-")[0]
                .components(separatedBy: "_")[0]
            return primary.isEmpty ? SubtitleLanguageKey.unknown : primary
        }
    }

    /// Port of `normalizeOverlayLanguageKeyForTrack`: variant-aware key for
    /// embedded tracks, sniffing regional accents from name/trackId.
    static func languageKey(forTrack track: SubtitleEmbeddedTrack) -> String {
        let variant = SubtitleLanguageCatalog.detectTrackLanguageVariant(
            language: track.language,
            name: track.name,
            trackID: track.trackID
        )
        switch variant {
        case "pt-br", "es-419":
            return variant
        default:
            let primary = variant
                .components(separatedBy: "-")[0]
                .components(separatedBy: "_")[0]
            return primary.isEmpty ? SubtitleLanguageKey.unknown : primary
        }
    }

    /// Port of `preferredOverlayLanguageOrder`: the preferred languages that
    /// should float to the top of the rail, as overlay language keys.
    static func preferredLanguageOrder(
        preferredLanguage: String,
        secondaryPreferredLanguage: String?
    ) -> [String] {
        func overlayKey(_ language: String?) -> String? {
            guard let language, !language.isEmpty else { return nil }
            let normalized = SubtitleLanguageCatalog.normalizeLanguageCode(language)
            if normalized == "none" || normalized == "forced" { return nil }
            let key = languageKey(language)
            return key == SubtitleLanguageKey.unknown ? nil : key
        }
        var order: [String] = []
        for language in [preferredLanguage, secondaryPreferredLanguage] {
            if let key = overlayKey(language), !order.contains(key) {
                order.append(key)
            }
        }
        return order
    }

    /// Port of `buildSubtitleLanguageRailItems`. The "Off" entry is always
    /// first; languages follow ordered by preference then display label.
    static func languageRailItems(
        embeddedTracks: [SubtitleEmbeddedTrack],
        externalTracks: [SubtitleExternalTrack],
        preferences: SubtitleStyleOptions,
        currentLanguageKey: String,
        noneLabel: String = "None",
        unknownLabel: String = "Unknown"
    ) -> [SubtitleLanguageRailItem] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        func record(_ key: String) {
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        embeddedTracks.forEach { record(languageKey(forTrack: $0)) }
        externalTracks.forEach { record(languageKey($0.language)) }

        let preferredOrder = preferredLanguageOrder(
            preferredLanguage: preferences.preferredLanguage,
            secondaryPreferredLanguage: preferences.secondaryPreferredLanguage
        )

        var keys = order
        if preferences.showOnlyPreferredLanguages {
            let preferredKeys = Set(preferredOrder)
            keys = order.filter { preferredKeys.contains($0) || $0 == currentLanguageKey }
        }

        let sorted = keys.sorted { lhs, rhs in
            let lhsIndex = preferredOrder.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = preferredOrder.firstIndex(of: rhs) ?? Int.max
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return sortLabel(lhs) < sortLabel(rhs)
        }

        let items = sorted.map { key in
            SubtitleLanguageRailItem(
                key: key,
                label: languageLabel(key, noneLabel: noneLabel, unknownLabel: unknownLabel),
                count: counts[key] ?? 0
            )
        }
        return [SubtitleLanguageRailItem(key: SubtitleLanguageKey.off, label: noneLabel, count: 0)] + items
    }

    /// Port of `subtitleLanguageLabel`.
    static func languageLabel(
        _ key: String,
        noneLabel: String = "None",
        unknownLabel: String = "Unknown"
    ) -> String {
        switch key {
        case SubtitleLanguageKey.off: return noneLabel
        case SubtitleLanguageKey.unknown: return unknownLabel
        default: return SubtitleLanguageCatalog.languageCodeToName(key)
        }
    }

    /// Port of `subtitleLanguageSortLabel`: unknown sorts last via U+FFFF.
    static func sortLabel(_ key: String) -> String {
        switch key {
        case SubtitleLanguageKey.off: return SubtitleLanguageCatalog.languageCodeToName("none").lowercased()
        case SubtitleLanguageKey.unknown: return "\u{FFFF}"
        default: return SubtitleLanguageCatalog.languageCodeToName(key).lowercased()
        }
    }

    /// Port of `buildSubtitleOptionRailItems`: embedded options first (in
    /// track order), then external options sorted by installed addon order.
    static func optionItems(
        languageKey selectedLanguageKey: String,
        embeddedTracks: [SubtitleEmbeddedTrack],
        externalTracks: [SubtitleExternalTrack],
        installedAddonOrder: [String],
        selectedOptionID: String?,
        builtInLabel: String = "Built-in",
        forcedLabel: String = "Forced"
    ) -> [SubtitleTrackOptionItem] {
        if selectedLanguageKey == SubtitleLanguageKey.off { return [] }

        let internalItems = embeddedTracks
            .filter { languageKey(forTrack: $0) == selectedLanguageKey }
            .map { track in
                SubtitleTrackOptionItem(
                    id: track.id,
                    kind: .embedded,
                    title: track.name,
                    sourceLabel: builtInLabel,
                    meta: metaLabel(codec: track.codec, isForced: track.isForced, forcedLabel: forcedLabel),
                    isSelected: track.id == selectedOptionID
                )
            }

        let addonOrderIndex = Dictionary(
            installedAddonOrder.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var seenIDs = Set<String>()
        let externalItems = externalTracks
            .enumerated()
            .filter { languageKey($1.language) == selectedLanguageKey }
            .sorted { lhs, rhs in
                let lhsOrder = addonOrderIndex[lhs.element.addonName] ?? Int.max
                let rhsOrder = addonOrderIndex[rhs.element.addonName] ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.offset < rhs.offset
            }
            .filter { seenIDs.insert($1.id).inserted }
            .map { _, track in
                SubtitleTrackOptionItem(
                    id: track.id,
                    kind: .external,
                    title: SubtitleLanguageCatalog.languageCodeToName(
                        SubtitleLanguageCatalog.normalizeLanguageCode(track.language)
                    ),
                    sourceLabel: track.addonName,
                    meta: track.externalID.isEmpty || track.externalID == track.language
                        ? nil
                        : track.externalID,
                    isSelected: track.id == selectedOptionID
                )
            }

        return internalItems + externalItems
    }

    private static func metaLabel(codec: String?, isForced: Bool, forcedLabel: String) -> String? {
        let parts = [codec, isForced ? forcedLabel : nil].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    /// Port of `selectedSubtitleLanguageKey`: the selected external track
    /// wins, then the selected embedded track, then "off".
    static func selectedLanguageKey(
        embeddedTracks: [SubtitleEmbeddedTrack],
        externalTracks: [SubtitleExternalTrack]
    ) -> String {
        if let selected = externalTracks.first(where: \.isSelected) {
            return languageKey(selected.language)
        }
        if let selected = embeddedTracks.first(where: \.isSelected) {
            return languageKey(forTrack: selected)
        }
        return SubtitleLanguageKey.off
    }

    /// Port of `selectedSubtitleOptionId`.
    static func selectedOptionID(
        embeddedTracks: [SubtitleEmbeddedTrack],
        externalTracks: [SubtitleExternalTrack]
    ) -> String? {
        if let selected = externalTracks.first(where: \.isSelected) { return selected.id }
        if let selected = embeddedTracks.first(where: \.isSelected) { return selected.id }
        return nil
    }

    /// Port of the overlay's session-initial focus/selection rules
    /// (`sessionInitialLanguageKey` / `sessionInitialSelectedOptionId`):
    /// open on the selected language when it is listed, otherwise the first
    /// non-off language, otherwise "off"; the option id is kept only when the
    /// selected language is the initial language.
    static func initialPanelSelection(
        embeddedTracks: [SubtitleEmbeddedTrack],
        externalTracks: [SubtitleExternalTrack],
        preferences: SubtitleStyleOptions
    ) -> (languageKey: String, optionID: String?) {
        let selectedKey = selectedLanguageKey(
            embeddedTracks: embeddedTracks,
            externalTracks: externalTracks
        )
        let items = languageRailItems(
            embeddedTracks: embeddedTracks,
            externalTracks: externalTracks,
            preferences: preferences,
            currentLanguageKey: selectedKey
        )
        let initialKey = items.first(where: { $0.key == selectedKey })?.key
            ?? items.first(where: { $0.key != SubtitleLanguageKey.off })?.key
            ?? SubtitleLanguageKey.off
        let optionID = selectedOptionID(
            embeddedTracks: embeddedTracks,
            externalTracks: externalTracks
        )
        let keepsOption = initialKey == selectedKey ? optionID : nil
        return (initialKey, keepsOption)
    }

    /// Startup default track preference, distilled from
    /// `applySubtitlePreferences` and the forced-subtitle track parameters in
    /// `PlayerRuntimeControllerInitialization.kt`:
    ///
    /// - preferred language "none" disables subtitles entirely;
    /// - when "use forced subtitles" is on, only a forced embedded track of a
    ///   preferred language is auto-selected;
    /// - otherwise the first non-forced embedded track matching the preferred
    ///   (then secondary) language is selected;
    /// - external addon tracks are never auto-selected: Android only attaches
    ///   them through explicit user action or a persisted per-content
    ///   preference. Returns nil when no rule matches (no auto selection).
    static func defaultTrackSelection(
        embeddedTracks: [SubtitleEmbeddedTrack],
        preferences: SubtitleStyleOptions
    ) -> SubtitleTrackSelection? {
        if preferences.preferredLanguage == "none" { return .off }

        let languages = [preferences.preferredLanguage, preferences.secondaryPreferredLanguage]
            .compactMap { $0 }
        for language in languages {
            let matching = embeddedTracks.filter {
                SubtitleLanguageCatalog.matchesLanguageCode($0.language, target: language)
            }
            if preferences.useForcedSubtitles {
                if let forced = matching.first(where: \.isForced) {
                    return .embedded(forced)
                }
            } else if let regular = matching.first(where: { !$0.isForced }) {
                return .embedded(regular)
            }
        }
        return nil
    }
}
