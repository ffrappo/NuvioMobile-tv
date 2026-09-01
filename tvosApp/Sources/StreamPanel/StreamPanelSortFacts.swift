import Foundation

/// Sortable facts extracted from a stream, mirroring the rank inputs of the
/// Android `DirectDebridStreamFilter.compareFacts` comparator. Every rank is
/// "higher is better" and compared in the order Android's sort profiles define.
struct StreamPanelSortFacts: Equatable, Sendable {
    let resolutionRank: Int
    let qualityRank: Int
    let visualRank: Int
    let audioTagRank: Int
    let channelRank: Int
    let encodeRank: Int
    let sizeBytes: Int64
    let languageRank: Int
    let originalIndex: Int

    init(source: StreamSource, preferredLanguages: [String], originalIndex: Int) {
        let stream = source.stream
        let text = [
            stream.name,
            stream.title,
            stream.description,
            stream.filename,
        ].compactMap { $0 }.joined(separator: " ")
        let info = stream.displayInfo

        resolutionRank = Self.resolutionRank(text: text, info: info)
        qualityRank = Self.qualityRank(text: text)
        visualRank = Self.visualRank(text: text, info: info)
        audioTagRank = Self.audioTagRank(text: text, info: info)
        channelRank = Self.channelRank(info: info)
        encodeRank = Self.encodeRank(info: info)
        sizeBytes = stream.videoSize ?? 0
        languageRank = Self.languageRank(info: info, preferred: preferredLanguages)
        self.originalIndex = originalIndex
    }

    // MARK: Android rank mirrors

    /// `DebridStreamResolution` order: 2160, 1440, 1080, 720, 576, 480, unknown.
    private static func resolutionRank(text: String, info: StreamDisplayInfo) -> Int {
        if matches(text, "(?i)\\b(4k|2160p|uhd)\\b") { return 2160 }
        if matches(text, "(?i)\\b(1440p|qhd)\\b") { return 1440 }
        if matches(text, "(?i)\\b(1080p|full\\s*hd|fhd)\\b") || info.quality == "1080p" { return 1080 }
        if matches(text, "(?i)\\b720p\\b") || info.quality == "720p" { return 720 }
        if matches(text, "(?i)\\b576p\\b") { return 576 }
        if matches(text, "(?i)\\b(480p|576p|sd)\\b") || info.quality == "SD" { return 480 }
        return 0
    }

    /// `DebridStreamQuality` order: BluRay REMUX, BluRay, WEB-DL, WEBRip,
    /// HDRip, DVDRip, HDTV, CAM, unknown.
    private static func qualityRank(text: String) -> Int {
        if matches(text, "(?i)blu-?ray\\s*remux") { return 80 }
        if matches(text, "(?i)\\bblu-?ray\\b|\\bbdrip\\b") { return 70 }
        if matches(text, "(?i)\\bweb-?dl\\b") { return 60 }
        if matches(text, "(?i)\\bweb-?rip\\b|\\bwebrip\\b") { return 50 }
        if matches(text, "(?i)\\bhd-?rip\\b|\\bhdrip\\b") { return 40 }
        if matches(text, "(?i)\\bdvd-?rip\\b|\\bdvdrip\\b") { return 30 }
        if matches(text, "(?i)\\bhdtv\\b") { return 20 }
        if matches(text, "(?i)\\b(cam|ts|tc|scr)\\b") { return 10 }
        return 0
    }

    /// `DebridStreamVisualTag` order restricted to the tags the stream text
    /// can express: DV highest, then HDR10+, HDR10, HDR, HLG.
    private static func visualRank(text: String, info: StreamDisplayInfo) -> Int {
        if info.hdr == "DV" || matches(text, "(?i)dolby\\s*vision|\\bdv\\b") { return 90 }
        if matches(text, "(?i)\\bhdr10\\+\\b") { return 80 }
        if matches(text, "(?i)\\bhdr10\\b") { return 70 }
        if info.hdr == "HDR" || matches(text, "(?i)\\bhdr\\b") { return 60 }
        if matches(text, "(?i)\\bhlg\\b") { return 50 }
        return 0
    }

    /// `DebridStreamAudioTag` order restricted to detectable tags:
    /// Atmos, TrueHD, DTS-HD, DTS, DD+, DD, AAC.
    private static func audioTagRank(text: String, info: StreamDisplayInfo) -> Int {
        if info.audio.contains("Atmos") || matches(text, "(?i)\\batmos\\b") { return 90 }
        if matches(text, "(?i)\\btruehd\\b") { return 80 }
        if matches(text, "(?i)\\bdts-?hd\\b") { return 70 }
        if info.audio.contains("DTS") || matches(text, "(?i)\\bdts\\b") { return 60 }
        if matches(text, "(?i)\\bdd\\+\\b|\\beac3\\b") { return 50 }
        if matches(text, "(?i)\\bac-?3\\b|\\bdd\\b") { return 40 }
        if matches(text, "(?i)\\baac\\b") { return 30 }
        return 0
    }

    /// `DebridStreamAudioChannel` order: 7.1, 6.1, 5.1, 2.0, unknown.
    private static func channelRank(info: StreamDisplayInfo) -> Int {
        if info.audio.contains("7.1") { return 40 }
        if matches(info.audio.joined(separator: " "), "(?i)\\b6\\.1\\b") { return 30 }
        if info.audio.contains("5.1") { return 20 }
        if info.audio.contains("Dual") { return 10 }
        return 0
    }

    /// `DebridStreamEncode` order: AV1, HEVC, AVC, unknown.
    private static func encodeRank(info: StreamDisplayInfo) -> Int {
        switch info.codec {
        case "AV1": 40
        case "HEVC": 30
        case "AVC": 20
        default: 0
        }
    }

    /// Position of the stream's best language inside the preferred list;
    /// unmatched languages score zero (Android `languageRank` DESC).
    private static func languageRank(info: StreamDisplayInfo, preferred: [String]) -> Int {
        var best = 0
        for language in info.languages {
            if let index = preferred.firstIndex(of: language) {
                best = max(best, preferred.count - index)
            }
        }
        return best
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}

/// Comparators mirroring the Android sort profiles from
/// `DebridSettingsScreen.sortCriteriaForProfile`.
enum StreamPanelSorter {
    static func sorted(
        _ sources: [StreamSource],
        option: StreamSortOption,
        preferredLanguages: [String]
    ) -> [StreamSource] {
        let facts = sources.enumerated().map { index, source in
            (source: source, facts: StreamPanelSortFacts(
                source: source,
                preferredLanguages: preferredLanguages,
                originalIndex: index
            ))
        }
        return facts.sorted { left, right in
            less(option: option, left: left.facts, right: right.facts)
        }.map(\.source)
    }

    private static func less(
        option: StreamSortOption,
        left: StreamPanelSortFacts,
        right: StreamPanelSortFacts
    ) -> Bool {
        // Every profile is stable and falls back to the original index.
        func compare(_ values: [(Int, Int)]) -> Bool {
            for (a, b) in values where a != b { return a > b }
            return left.originalIndex < right.originalIndex
        }

        switch option {
        case .original:
            return left.originalIndex < right.originalIndex
        case .bestQuality:
            // Android defaultOrder: resolution, quality, visual, audio,
            // channel, encode, size — all DESC.
            return compare([
                (left.resolutionRank, right.resolutionRank),
                (left.qualityRank, right.qualityRank),
                (left.visualRank, right.visualRank),
                (left.audioTagRank, right.audioTagRank),
                (left.channelRank, right.channelRank),
                (left.encodeRank, right.encodeRank),
                (Int(left.sizeBytes), Int(right.sizeBytes)),
            ])
        case .largest:
            return compare([(Int(left.sizeBytes), Int(right.sizeBytes))])
        case .smallest:
            if left.sizeBytes != right.sizeBytes { return left.sizeBytes < right.sizeBytes }
            return left.originalIndex < right.originalIndex
        case .bestAudio:
            // Android AUDIO profile: audio tag, channel, resolution, quality, size.
            return compare([
                (left.audioTagRank, right.audioTagRank),
                (left.channelRank, right.channelRank),
                (left.resolutionRank, right.resolutionRank),
                (left.qualityRank, right.qualityRank),
                (Int(left.sizeBytes), Int(right.sizeBytes)),
            ])
        case .language:
            // Android LANGUAGE profile: language, resolution, quality, size.
            return compare([
                (left.languageRank, right.languageRank),
                (left.resolutionRank, right.resolutionRank),
                (left.qualityRank, right.qualityRank),
                (Int(left.sizeBytes), Int(right.sizeBytes)),
            ])
        }
    }
}
