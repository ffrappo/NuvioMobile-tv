import Foundation

/// Language code display names ported from the Android `LanguageUtils.kt`
/// (`languageCodeToName`) plus the ISO-639-2/B aliases used by the subtitle
/// track pipeline. Display strings resolve through `Locale` with a fixed
/// `en_US` display locale so panel labels and tests are deterministic.
enum SubtitleLanguageCatalog {
    /// `LANGUAGE_DISPLAY_OVERRIDES` from LanguageUtils.kt.
    private static let displayOverrides: [String: String] = [
        "id": "Indonesia",
        "in": "Indonesia",
        "ind": "Indonesia",
    ]

    /// `LANGUAGE_OVERRIDES` from LanguageUtils.kt. Values keep the mixed-case
    /// BCP-47 form used for display; `normalizeLanguageCode` lowercases them.
    private static let overrides: [String: String] = [
        "pt": "pt", "pt-pt": "pt", "pt_pt": "pt", "por": "pt",
        "pt-br": "pt-BR", "pt_br": "pt-BR", "br": "pt-BR", "pob": "pt-BR",
        "fre": "fr", "ger": "de", "deu": "de", "dut": "nl", "nld": "nl",
        "chi": "zh", "zho": "zh", "jpn": "ja", "kor": "ko", "ara": "ar",
        "hin": "hi", "rus": "ru", "pol": "pl", "spa": "es", "spl": "es-419",
        "es-419": "es-419", "es_419": "es-419", "es-la": "es-419", "es-lat": "es-419",
        "fra": "fr", "ita": "it", "eng": "en", "swe": "sv", "nor": "no",
        "dan": "da", "fin": "fi", "tur": "tr", "ell": "el", "gre": "el",
        "heb": "he", "tha": "th", "vie": "vi", "ind": "id", "msa": "ms",
        "may": "ms", "ces": "cs", "cze": "cs", "hun": "hu", "ron": "ro",
        "rum": "ro", "ukr": "uk", "bul": "bg", "hrv": "hr", "srp": "sr",
        "slk": "sk", "slo": "sk", "slv": "sl", "zht": "zh-TW", "zhs": "zh-CN",
        "chi-tw": "zh-TW", "chi-cn": "zh-CN", "zh-tw": "zh-TW", "zh_tw": "zh-TW",
        "zh-cn": "zh-CN", "zh_cn": "zh-CN", "cat": "ca", "alb": "sq", "sqi": "sq",
        "bos": "bs", "mac": "mk", "mkd": "mk", "lav": "lv", "lit": "lt",
        "est": "et", "isl": "is", "ice": "is", "glg": "gl", "baq": "eu",
        "eus": "eu", "wel": "cy", "cym": "cy", "gle": "ga", "ben": "bn",
        "tam": "ta", "tel": "te", "mal": "ml", "kan": "kn", "mar": "mr",
        "pan": "pa", "guj": "gu", "urd": "ur", "fas": "fa", "per": "fa",
        "amh": "am", "swa": "sw", "zul": "zu", "afr": "af", "mlt": "mt",
        "bel": "be", "geo": "ka", "kat": "ka", "arm": "hy", "hye": "hy",
        "aze": "az", "kaz": "kk", "uzb": "uz", "mon": "mn", "khm": "km",
        "lao": "lo", "mya": "my", "bur": "my", "sin": "si", "nep": "ne",
        "tgl": "tl", "fil": "tl",
    ]

    /// `LANGUAGE_NAME_ALIASES` from LanguageUtils.kt (English names to codes).
    private static let nameAliases: [String: String] = [
        "afrikaans": "af", "albanian": "sq", "amharic": "am", "arabic": "ar",
        "armenian": "hy", "azerbaijani": "az", "basque": "eu", "belarusian": "be",
        "bengali": "bn", "bosnian": "bs", "bulgarian": "bg", "burmese": "my",
        "catalan": "ca", "chinese": "zh", "mandarin": "zh", "croatian": "hr",
        "czech": "cs", "danish": "da", "dutch": "nl", "english": "en",
        "estonian": "et", "filipino": "tl", "finnish": "fi", "french": "fr",
        "galician": "gl", "georgian": "ka", "german": "de", "greek": "el",
        "gujarati": "gu", "hebrew": "he", "hindi": "hi", "hungarian": "hu",
        "icelandic": "is", "indonesian": "id", "irish": "ga", "italian": "it",
        "japanese": "ja", "kannada": "kn", "kazakh": "kk", "khmer": "km",
        "korean": "ko", "lao": "lo", "latvian": "lv", "lithuanian": "lt",
        "macedonian": "mk", "malay": "ms", "malayalam": "ml", "maltese": "mt",
        "marathi": "mr", "mongolian": "mn", "nepali": "ne", "norwegian": "no",
        "persian": "fa", "polish": "pl", "portuguese": "pt", "portugues": "pt",
        "punjabi": "pa", "romanian": "ro", "russian": "ru", "serbian": "sr",
        "sinhala": "si", "slovak": "sk", "slovenian": "sl", "spanish": "es",
        "espanol": "es", "swahili": "sw", "swedish": "sv", "tamil": "ta",
        "telugu": "te", "thai": "th", "turkish": "tr", "ukrainian": "uk",
        "urdu": "ur", "uzbek": "uz", "vietnamese": "vi", "welsh": "cy", "zulu": "zu",
    ]

    /// Port of `PlayerSubtitleUtils.normalizeLanguageCode`.
    static func normalizeLanguageCode(_ language: String) -> String {
        let code = language.trimmingCharacters(in: .whitespaces).lowercased()
        if code.isEmpty { return "" }

        let normalizedCode = code.replacingOccurrences(of: "_", with: "-")
        let tokenized = normalizedCode
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        func containsAny(_ values: [String]) -> Bool {
            values.contains { tokenized.contains($0) }
        }

        if containsAny(["portuguese", "portugues"]) {
            if containsAny(["brazil", "brasil", "brazilian", "brasileiro", "pt br", "ptbr", "pob", "(br)"]) {
                return "pt-br"
            }
            if containsAny(["portugal", "european", "europeu", "iberian", "pt pt", "ptpt"]) {
                return "pt"
            }
            return "pt"
        }

        if containsAny(["spanish", "espanol", "español", "castellano"]) {
            if containsAny(["latin", "latino", "latinoamerica", "latinoamericano", "lat am", "latam", "es 419", "es419", "la", "(419)"]) {
                return "es-419"
            }
            return "es"
        }

        return overrides[code]?.lowercased() ?? normalizedCode
    }

    /// Port of `LanguageUtils.languageCodeToName`.
    static func languageCodeToName(_ code: String) -> String {
        let lowerCode = code.lowercased()
        if lowerCode == "none" { return "None" }
        if lowerCode == "und" || lowerCode == "unknown" || lowerCode == "unk" {
            return "Unknown"
        }
        if let override = displayOverrides[lowerCode] { return override }

        let tokenized = lowerCode
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let bcp47 = overrides[lowerCode]
            ?? nameAliases[tokenized]
            ?? lowerCode.replacingOccurrences(of: "_", with: "-")
        if let override = displayOverrides[bcp47.lowercased()] { return override }

        let displayLocale = Locale(identifier: "en_US")
        let locale = Locale(identifier: bcp47)
        let name: String
        if locale.region != nil {
            name = displayLocale.localizedString(forIdentifier: bcp47) ?? bcp47
        } else {
            let languageCode = locale.language.languageCode?.identifier ?? bcp47
            name = displayLocale.localizedString(forLanguageCode: languageCode) ?? bcp47
        }
        if !name.isEmpty && name != bcp47 {
            return name.prefix(1).uppercased() + name.dropFirst()
        }
        return code.uppercased()
    }

    /// Port of `PlayerSubtitleUtils.detectTrackLanguageVariant`: sniffs a
    /// regional accent (Brazilian Portuguese, Latin American Spanish) from the
    /// track's name/language/trackId fields.
    static func detectTrackLanguageVariant(language: String?, name: String?, trackID: String?) -> String {
        let baseLang = normalizeLanguageCode(language ?? "")
        let haystack = [name, language, trackID]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if baseLang == "pt" || baseLang == "por" {
            let hasBrazilian = brazilianTags.contains { haystack.contains($0) }
            let hasEuropean = europeanPortugueseTags.contains { haystack.contains($0) }
            if hasBrazilian && !hasEuropean { return "pt-br" }
            if hasEuropean && !hasBrazilian { return "pt" }
            return baseLang
        }

        if baseLang == "es" || baseLang == "spa" {
            let hasLatino = latinoTags.contains { haystack.contains($0) }
            let hasCastilian = castilianTags.contains { haystack.contains($0) }
            if hasLatino && !hasCastilian { return "es-419" }
            if hasCastilian && !hasLatino { return "es" }
            return baseLang
        }

        return baseLang
    }

    /// `BRAZILIAN_TAGS` from PlayerSubtitleUtils.kt.
    static let brazilianTags = [
        "pt-br", "pt_br", "pob", "brazilian", "brazil", "brasil", "brasileiro", " br", "(br)",
    ]
    /// `EUROPEAN_PT_TAGS` from PlayerSubtitleUtils.kt.
    static let europeanPortugueseTags = [
        "pt-pt", "pt_pt", "iberian", "european", "portugal", "europeu", " eu", "(eu)",
    ]
    /// `LATINO_TAGS` from PlayerSubtitleUtils.kt.
    static let latinoTags = [
        "es-419", "es_419", "es-la", "es-lat", "latino", "latinoamerica",
        "latinoamericano", "latam", "lat am", "latin america",
    ]
    /// `CASTILIAN_TAGS` from PlayerSubtitleUtils.kt.
    static let castilianTags = [
        "es-es", "es_es", "castilian", "castellano", "spain", "españa", "espana", "iberian",
    ]

    /// Port of `PlayerSubtitleUtils.matchesLanguageCode`. Exact regional
    /// targets never match their siblings: "pt" does not match "pt-br" and
    /// "es" does not match "es-419".
    static func matchesLanguageCode(_ language: String?, target: String) -> Bool {
        guard let language, !language.isEmpty else { return false }
        let normalizedLanguage = normalizeLanguageCode(language)
        let normalizedTarget = normalizeLanguageCode(target)
        if matchesNormalizedLanguage(normalizedLanguage, normalizedTarget) {
            return true
        }

        let subtags = language
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: CharacterSet(charactersIn: "-./ "))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if subtags.count <= 1 { return false }
        for subtag in subtags.dropFirst() {
            guard subtag.count == 3 else { continue }
            if matchesNormalizedLanguage(normalizeLanguageCode(subtag), normalizedTarget) {
                return true
            }
        }
        return false
    }

    private static func matchesNormalizedLanguage(_ normalizedLanguage: String, _ normalizedTarget: String) -> Bool {
        if normalizedTarget == "pt" { return normalizedLanguage == "pt" }
        if normalizedTarget == "es" { return normalizedLanguage == "es" }
        return normalizedLanguage == normalizedTarget
            || normalizedLanguage.hasPrefix("\(normalizedTarget)-")
            || normalizedLanguage.hasPrefix("\(normalizedTarget)_")
    }
}
