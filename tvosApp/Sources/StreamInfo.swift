import Foundation

struct StreamDisplayInfo: Equatable {
    var quality: String?
    var hdr: String?
    var codec: String?
    var audio: [String] = []
    var languages: [String] = []

    var summary: String {
        var parts: [String] = []
        if let quality { parts.append(quality) }
        if let hdr { parts.append(hdr) }
        if let codec { parts.append(codec) }
        parts.append(contentsOf: audio)
        parts.append(contentsOf: languages)
        return parts.joined(separator: " \u{00B7} ")
    }

    var hasContent: Bool { !summary.isEmpty }
}

enum StreamInfo {
    static func displayInfo(name: String?, description: String?) -> StreamDisplayInfo {
        let text = "\(name ?? "") \(description ?? "")"
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

    static func labels(name: String?, description: String?) -> [String] {
        let info = displayInfo(name: name, description: description)
        return [
            info.quality, info.hdr, info.codec,
        ].compactMap { $0 } + info.audio + info.languages
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

extension StremioStream {
    var displayInfo: StreamDisplayInfo {
        StreamInfo.displayInfo(name: name, description: description)
    }
}