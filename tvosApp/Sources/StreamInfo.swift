import Foundation

struct StremioStream: Decodable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let title: String?
    let description: String?
    let url: String?
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
    let videoSize: Int64?
    let filename: String?
    let displayInfo: StreamDisplayInfo

    private enum CodingKeys: String, CodingKey { case name, title, description, url, behaviorHints }
    private enum BehaviorHintKeys: String, CodingKey { case proxyHeaders, videoSize, filename }
    private enum ProxyHeaderKeys: String, CodingKey { case request, response }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = container.decodeFlexibleString(forKey: .name)
            ?? container.decodeFlexibleString(forKey: .title)
            ?? "Unnamed source"
        title = container.decodeFlexibleString(forKey: .title)
        description = container.decodeFlexibleString(forKey: .description)
        url = container.decodeFlexibleString(forKey: .url)
        let hints = try? container.nestedContainer(keyedBy: BehaviorHintKeys.self, forKey: .behaviorHints)
        let proxy = try? hints?.nestedContainer(keyedBy: ProxyHeaderKeys.self, forKey: .proxyHeaders)
        requestHeaders = (try? proxy?.decode([String: String].self, forKey: .request)) ?? [:]
        responseHeaders = (try? proxy?.decode([String: String].self, forKey: .response)) ?? [:]
        videoSize = hints?.decodeFlexibleInt64(forKey: .videoSize)
        filename = hints?.decodeFlexibleString(forKey: .filename)
        var parsed = StreamInfo.displayInfo(
            name: name,
            title: title,
            description: description,
            filename: filename
        )
        if let videoSize { parsed.size = FileSizeFormatter.string(videoSize) }
        displayInfo = parsed
    }

    var directURL: URL? {
        guard let url, let value = URL(string: url), let scheme = value.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return value
    }
}

struct StreamSource: Identifiable, Hashable, Sendable {
    let addonName: String
    let addonLogoURL: String?
    let stream: StremioStream

    var id: UUID { stream.id }
}

struct StreamFetchReport: Sendable {
    let sources: [StreamSource]
    let failures: [String]
}

struct StreamDisplayInfo: Equatable, Hashable, Sendable {
    var quality: String?
    var hdr: String?
    var codec: String?
    var size: String?
    var audio: [String] = []
    var languages: [String] = []

    var summary: String {
        var parts: [String] = []
        if let quality { parts.append(quality) }
        if let hdr { parts.append(hdr) }
        if let codec { parts.append(codec) }
        parts.append(contentsOf: audio)
        parts.append(contentsOf: languages)
        if let size { parts.append(size) }
        return parts.joined(separator: " \u{00B7} ")
    }
}

enum FileSizeFormatter {
    static func string(_ bytes: Int64) -> String? {
        guard bytes > 0 else { return nil }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return nil
    }
}

enum StreamInfo {
    static func displayInfo(name: String?, title: String? = nil, description: String? = nil, filename: String? = nil) -> StreamDisplayInfo {
        let text = [name, title, description, filename].compactMap { $0 }.joined(separator: " ")
        var info = StreamDisplayInfo()

        info.quality = firstMatch(text, patterns: [
            ("4K", "(?i)\\b(4k|2160p|uhd|ultra hd)\\b"),
            ("1080p", "(?i)\\b(1080p|1920\\s*[x\\u00D7]\\s*1080|full\\s*hd|fhd)\\b"),
            ("720p", "(?i)\\b(720p|1280\\s*[x\\u00D7]\\s*720|hd\\s*ready)\\b"),
            ("SD", "(?i)\\b(480p|576p)\\b"),
        ])

        if contains(text, "(?i)dolby\\s*vision|\\bdv\\b") {
            info.hdr = "DV"
        } else if contains(text, "(?i)hdr10\\+|hdr10|\\bhlg\\b|\\bhdr\\b") {
            info.hdr = "HDR"
        }

        info.codec = firstMatch(text, patterns: [
            ("AV1", "(?i)\\bav1\\b"),
            ("HEVC", "(?i)\\b(hevc|x265|h\\.?265)\\b"),
            ("AVC", "(?i)\\b(avc|x264|h\\.?264)\\b"),
            ("VP9", "(?i)\\bvp9\\b"),
        ])

        if contains(text, "(?i)\\batmos\\b") {
            info.audio.append("Atmos")
        }
        if contains(text, "(?i)\\b(truehd|dts-hd|dts\\s*master)\\b") {
            info.audio.append("DTS")
        }
        if contains(text, "(?i)\\b7\\.1\\b") {
            info.audio.append("7.1")
        }
        if contains(text, "(?i)\\b5\\.1\\b") {
            info.audio.append("5.1")
        }
        if contains(text, "(?i)\\b(dual|2\\.0|stereo)\\b") {
            info.audio.append("Dual")
        }

        info.languages = matchedLanguages(text)

        return info
    }

    private static func contains(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func firstMatch(_ text: String, patterns: [(String, String)]) -> String? {
        for (label, pattern) in patterns where contains(text, pattern) {
            return label
        }
        return nil
    }

    private static func matchedLanguages(_ text: String) -> [String] {
        var found: [String] = []
        for (pattern, label) in languagePatterns where contains(text, pattern) {
            if !found.contains(label) { found.append(label) }
            if found.count == 3 { break }
        }
        return found
    }

    private static let languagePatterns: [(String, String)] = [
        ("(?i)\\beng(?:lish)?\\b", "English"),
        ("(?i)\\bita(?:lian)?\\b", "Italian"),
        ("(?i)\\bspa(?:nish)?\\b", "Spanish"),
        ("(?i)\\b(fre|fra|french|francais)\\b", "French"),
        ("(?i)\\b(ger|deu|german)\\b", "German"),
        ("(?i)\\b(por|portuguese)\\b", "Portuguese"),
        ("(?i)\\b(jpn|japanese)\\b", "Japanese"),
        ("(?i)\\b(kor|korean)\\b", "Korean"),
        ("(?i)\\b(chi|zho|chinese)\\b", "Chinese"),
        ("(?i)\\b(hin|hindi)\\b", "Hindi"),
        ("(?i)\\b(ara|arabic)\\b", "Arabic"),
        ("(?i)\\b(tur|turkish)\\b", "Turkish"),
        ("(?i)\\b(rus|russian)\\b", "Russian"),
        ("(?i)\\b(pol|polish)\\b", "Polish"),
        ("(?i)\\b(nld|dut|dutch)\\b", "Dutch"),
        ("(?i)\\b(swe|swedish)\\b", "Swedish"),
        ("(?i)\\b(dan|danish)\\b", "Danish"),
        ("(?i)\\b(nor|norwegian)\\b", "Norwegian"),
        ("(?i)\\b(fin|finnish)\\b", "Finnish"),
        ("(?i)\\b(ell|gre|greek)\\b", "Greek"),
        ("(?i)\\b(heb|hebrew)\\b", "Hebrew"),
        ("(?i)\\b(cze|ces|czech)\\b", "Czech"),
        ("(?i)\\b(ukr|ukrainian)\\b", "Ukrainian"),
        ("(?i)\\b(tha|thai)\\b", "Thai"),
        ("(?i)\\b(vie|vietnamese)\\b", "Vietnamese"),
        ("(?i)\\b(ind|indonesian)\\b", "Indonesian"),
        ("(?i)\\b(mal|malay)\\b", "Malay"),
    ]
}
