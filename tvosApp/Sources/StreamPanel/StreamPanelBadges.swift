import Foundation

/// Builds badge models for a stream row. Android renders addon-supplied
/// badge images plus a file-size chip; the tvOS stream model exposes the
/// same information as text, so badges are composed from
/// `StreamDisplayInfo` plus a seeds/health scan of the stream text.
enum StreamPanelBadgeComposer {
    static func badges(for source: StreamSource, showFileSize: Bool) -> [StreamPanelBadge] {
        let info = source.stream.displayInfo
        var badges: [StreamPanelBadge] = []

        if let quality = info.quality {
            badges.append(StreamPanelBadge(kind: .quality, text: quality))
        }
        if showFileSize, let size = info.size {
            badges.append(StreamPanelBadge(kind: .size, text: size))
        }
        if let seeds = seedsBadge(for: source) {
            badges.append(StreamPanelBadge(kind: .seeds, text: seeds))
        }
        if let codec = info.codec {
            badges.append(StreamPanelBadge(kind: .codec, text: codec))
        }
        if let hdr = info.hdr {
            badges.append(StreamPanelBadge(kind: .hdr, text: hdr))
        }
        for audio in info.audio {
            badges.append(StreamPanelBadge(kind: .audio, text: audio))
        }
        for language in info.languages {
            badges.append(StreamPanelBadge(kind: .language, text: language))
        }
        return badges
    }

    /// Torrent streams announce seed counts in their titles or descriptions
    /// (for example "12 seeders" or "S: 34"). Returns a health label when
    /// such a count is present, otherwise nil.
    static func seedsBadge(for source: StreamSource) -> String? {
        let texts = [
            source.stream.name,
            source.stream.title,
            source.stream.description,
        ].compactMap { $0 }
        for text in texts {
            if let count = firstMatch(text, patterns: [
                "(?i)\\b(\\d{1,5})\\s*seeders?\\b",
                "(?i)\\bseeds?:?\\s*(\\d{1,5})\\b",
                "(?i)\\bs:?\\s*(\\d{1,5})\\b",
            ]) {
                return "\(count) seed\(count == 1 ? "" : "s")"
            }
        }
        return nil
    }

    private static func firstMatch(_ text: String, patterns: [String]) -> Int? {
        for pattern in patterns {
            guard let range = text.range(of: pattern, options: .regularExpression) else { continue }
            let digits = text[range].filter(\.isNumber)
            if let value = Int(digits) { return value }
        }
        return nil
    }
}
