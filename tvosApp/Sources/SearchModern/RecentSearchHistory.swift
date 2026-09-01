import Foundation

/// Port of Android `SearchHistoryDataStore` (recent searches): trim, dedup
/// case-insensitively, collapse prefix searches, cap at `maxCount`, and
/// persist as a JSON string array the integrator can store anywhere.
public struct RecentSearchHistory: Equatable, Sendable {
    /// Android `MAX_RECENT_SEARCHES` / `DEFAULT_MAX_RECENT_SEARCHES`.
    public static let maxCount = 8

    public private(set) var items: [String]

    public init(items: [String] = []) {
        self.items = Self.normalized(items)
    }

    /// Android `parseRecentSearches`: malformed payloads decode to an empty
    /// history rather than throwing.
    public init(encoded: String) {
        let decoded = (try? JSONDecoder().decode([String].self, from: Data(encoded.utf8))) ?? []
        self.items = Self.normalized(decoded)
    }

    /// Android `saveRecentSearch`: the query is trimmed; empty queries are
    /// ignored; the query is prepended; case-insensitive duplicates and
    /// existing prefixes ("f", "fr" before "frieren") are collapsed; the
    /// list is capped at `max(1, maxCount)`.
    public mutating func save(_ query: String, maxCount: Int = RecentSearchHistory.maxCount) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var updated = [normalized]
        updated.append(
            contentsOf: items.filter { existing in
                guard let existing = existing.trimmedNonEmpty else { return false }
                return !areFoldedEqual(existing, normalized) &&
                    !isCaseInsensitivePrefix(prefix: existing, of: normalized)
            }
        )
        items = Array(updated.prefix(max(maxCount, 1)))
    }

    /// Android `clearRecentSearches`.
    public mutating func clear() {
        items = []
    }

    /// JSON persistence model: a plain string array, matching the Android
    /// DataStore payload (`gson.toJson(listOf<String>())`).
    public var encoded: String {
        guard let data = try? JSONEncoder().encode(items) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func normalized(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}

private func areFoldedEqual(_ lhs: String, _ rhs: String) -> Bool {
    lhs.lowercased() == rhs.lowercased()
}

private func isCaseInsensitivePrefix(prefix: String, of full: String) -> Bool {
    guard !prefix.isEmpty else { return false }
    return full.lowercased().hasPrefix(prefix.lowercased())
}
