import Foundation

// MARK: - Android parity formatting

/// Port of `GenreLabelFormatter.localizedGenreLabel` (English labels).
public enum DetailsGenreLabels {
    public static func label(for genre: String) -> String {
        let key = genre.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "-", with: " ")
        switch key {
        case "action": return "Action"
        case "adventure": return "Adventure"
        case "animation": return "Animation"
        case "comedy": return "Comedy"
        case "crime": return "Crime"
        case "documentary": return "Documentary"
        case "drama": return "Drama"
        case "family": return "Family"
        case "fantasy": return "Fantasy"
        case "history": return "History"
        case "horror": return "Horror"
        case "music": return "Music"
        case "mystery": return "Mystery"
        case "romance": return "Romance"
        case "science fiction": return "Science Fiction"
        case "tv movie": return "TV Movie"
        case "thriller": return "Thriller"
        case "war": return "War"
        case "western": return "Western"
        case "anime": return "Anime"
        case "biography": return "Biography"
        case "children": return "Children"
        case "donghua": return "Donghua"
        case "game show": return "Game Show"
        case "holiday": return "Holiday"
        case "home and garden": return "Home and Garden"
        case "mini series": return "Mini Series"
        case "musical": return "Musical"
        case "none": return "None"
        case "short": return "Short"
        case "special interest": return "Special Interest"
        case "sporting event": return "Sporting Event"
        case "superhero": return "Superhero"
        case "suspense": return "Suspense"
        case "talk show", "talk": return "Talk"
        case "action & adventure": return "Action & Adventure"
        case "kids": return "Kids"
        case "news": return "News"
        case "reality": return "Reality"
        case "sci fi & fantasy": return "Sci-Fi & Fantasy"
        case "soap": return "Soap"
        case "war & politics": return "War & Politics"
        default: return genre
        }
    }
}

/// Port of the status mapping in `HeroSection.MetaInfoRow` / `HeroTitleContent`.
public enum DetailsStatusMapper {
    public static func badge(status: String?, isSeries: Bool) -> String? {
        _ = isSeries // Android keeps separate string sets; English values match.
        let raw = status?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        let mapped: String
        switch raw.lowercased() {
        case "ended": mapped = "Ended"
        case "continuing", "returning series": mapped = "Ongoing"
        case "current": mapped = "Current"
        case "cancelled", "canceled": mapped = "Cancelled"
        case "released": mapped = "Released"
        case "planned": mapped = "Planned"
        case "rumored": mapped = "Rumored"
        case "in production": mapped = "In Production"
        case "post production": mapped = "Post Production"
        default: mapped = raw
        }
        return mapped.uppercased()
    }
}

/// Port of `formatRuntime` (HeroSection.kt) and `formatHeroRuntime`.
public enum DetailsMetaFormatter {
    public static func formatRuntime(_ runtime: String?) -> String? {
        let trimmed = runtime?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty else { return nil }

        var totalMinutes: Int?
        if trimmed.contains("h") || trimmed.contains("m") {
            let hours = firstInt(in: trimmed, pattern: "(\\d+)\\s*h")
            let minutes = firstInt(in: trimmed, pattern: "(\\d+)\\s*m")
            if hours != nil || minutes != nil {
                totalMinutes = (hours ?? 0) * 60 + (minutes ?? 0)
            }
        } else if trimmed.contains(":"), let parts = splitColon(trimmed) {
            totalMinutes = parts.hours * 60 + parts.minutes
        } else if let digits = Int(trimmed.filter(\.isNumber)), !trimmed.filter(\.isNumber).isEmpty {
            totalMinutes = digits
        }
        guard let minutes = totalMinutes, minutes > 0 else { return runtime }
        return minutesLabel(minutes)
    }

    public static func minutesLabel(_ totalMinutes: Int) -> String {
        guard totalMinutes > 0 else { return "" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, let m): return "\(m)m"
        case (let h, 0): return "\(h)h"
        case (let h, let m): return "\(h)h \(m)m"
        }
    }

    /// Port of `extractYearText`: full release date for movies when requested,
    /// otherwise the trimmed `releaseInfo` range.
    public static func yearText(
        type: String,
        releaseInfo: String?,
        released: String?,
        showFullReleaseDate: Bool
    ) -> String? {
        if showFullReleaseDate, Self.isMovieType(type), let released, let date = parseISODate(released) {
            return fullDateFormatter.string(from: date)
        }
        let trimmed = releaseInfo?.trimmingCharacters(in: .whitespaces)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    public static func contentTypeLabel(_ type: String) -> String {
        switch type.lowercased() {
        case "movie": return "Movie"
        case "series", "tv": return "Series"
        default: return type.prefix(1).uppercased() + type.dropFirst()
        }
    }

    public static func isSeriesType(_ type: String) -> Bool {
        ["series", "tv"].contains(type.lowercased())
    }

    public static func isMovieType(_ type: String) -> Bool {
        type.lowercased() == "movie"
    }

    /// Port of `formatEpisodeCardDate` with a fixed locale for determinism.
    public static func episodeDateText(_ isoDate: String?) -> String? {
        guard let isoDate, let date = parseISODate(isoDate) else { return nil }
        return episodeDateFormatter.string(from: date)
    }

    public static func parseISODate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let date = isoFractionalFormatter.date(from: trimmed) { return date }
        if let date = isoFormatter.date(from: trimmed) { return date }
        if let date = plainDateFormatter.date(from: trimmed) { return date }
        return nil
    }

    private static func firstInt(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[range])
    }

    private static func splitColon(_ text: String) -> (hours: Int, minutes: Int)? {
        let parts = text.split(separator: ":")
        guard parts.count >= 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        return (hours, minutes)
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let episodeDateFormatter: DateFormatter = fullDateFormatter

    private static let isoFractionalFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let plainDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Port of `EpisodeWatchedProjection.resolveEpisodeWatchedState`.
public enum DetailsEpisodeWatchedProjection {
    public static func resolve(
        currentlyWatched: Bool,
        completedByProgress: Bool,
        optimisticallyMarked: Bool,
        optimisticallyUnmarked: Bool,
        watchedByVideoID: Bool?
    ) -> Bool {
        if watchedByVideoID == true && !optimisticallyUnmarked { return true }
        if watchedByVideoID == false,
           currentlyWatched,
           !completedByProgress,
           !optimisticallyMarked {
            return false
        }
        return currentlyWatched
    }
}
