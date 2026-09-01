import Foundation

/// Saved vs Cloud library source, mirroring Android's private `LibraryViewMode`
/// (`LibraryScreen.kt`). The mode decides empty-state copy; the integrator feeds
/// whichever item list belongs to the active mode.
enum LibraryViewMode: String, CaseIterable, Equatable, Sendable {
    case saved
    case cloud

    /// Capsule label (`library_source_saved` / `library_source_cloud`).
    var label: String {
        switch self {
        case .saved: return "Saved"
        case .cloud: return "Cloud"
        }
    }

    /// Header badge (`library_source_cloud` / `library_source_local`).
    var sourceLabel: String {
        switch self {
        case .saved: return "LOCAL"
        case .cloud: return "CLOUD"
        }
    }
}

/// Watched-status filter over saved items (`LibraryWatchedFilter`).
enum LibraryWatchedFilter: String, CaseIterable, Equatable, Sendable {
    case all
    case watched
    case unwatched

    var label: String {
        switch self {
        case .all: return "All"
        case .watched: return "Watched"
        case .unwatched: return "Unwatched"
        }
    }
}

/// Sort options, mirroring Android's `LibrarySortOption` enum (same raw keys).
/// `providerOrder` is Android's `DEFAULT` ("provider order"); for a local
/// library Android falls back to source order, which is what we do here.
enum LibrarySortOption: String, CaseIterable, Equatable, Sendable {
    case providerOrder = "default"
    case addedDesc = "added_desc"
    case addedAsc = "added_asc"
    case titleAsc = "title_asc"
    case titleDesc = "title_desc"

    var label: String {
        switch self {
        case .providerOrder: return "Provider Order"
        case .addedDesc: return "Added ↓"
        case .addedAsc: return "Added ↑"
        case .titleAsc: return "Title A-Z"
        case .titleDesc: return "Title Z-A"
        }
    }

    /// Options offered for a local (non-tracking) source — Android's
    /// `LibrarySortOption.LocalOptions`.
    static let localOptions: [LibrarySortOption] = [.addedDesc, .addedAsc, .titleAsc, .titleDesc]

    /// Options offered for a tracking source — Android's `TrackingOptions`.
    static let trackingOptions: [LibrarySortOption] =
        [.providerOrder, .addedDesc, .addedAsc, .titleAsc, .titleDesc]
}

/// One type tab with its facet count, mirroring Android's `LibraryTypeTab`.
/// The label embeds the count, e.g. "Movie (8)" / "All (12)".
struct LibraryTypeTab: Equatable, Sendable {
    let key: String
    let count: Int

    /// Android's `LibraryTypeTab.ALL_KEY`.
    static let allKey = "__all__"

    static let all = LibraryTypeTab(key: allKey, count: 0)

    var label: String {
        "\(Self.localizedLabel(forKey: key)) (\(count))"
    }

    /// Localized type label: `library_type_all` for the All tab, then
    /// `localizedContentType` semantics (movie / series / TV) and Android's
    /// `prettifyTypeLabel` title-casing for anything else.
    static func localizedLabel(forKey key: String) -> String {
        switch key.lowercased() {
        case allKey: return "All"
        case "movie": return "Movie"
        case "series": return "Series"
        case "tv": return "TV"
        default: return prettifiedTypeLabel(key)
        }
    }

    /// Android `prettifyTypeLabel`: `_`/`-` become spaces, each token's first
    /// character is title-cased, blank input becomes "Unknown".
    static func prettifiedTypeLabel(_ key: String) -> String {
        let tokens = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
        let joined = tokens
            .map { token -> String in
                guard let first = token.first else { return "" }
                return String(first).uppercased() + token.dropFirst()
            }
            .joined(separator: " ")
        return joined.isEmpty ? "Unknown" : joined
    }
}

/// One provider filter option with a facet count, mirroring Android's
/// `FilterOption` for cloud providers. Providers are derived per item; for
/// saved items the provider key is the metadata addon host.
struct LibraryProviderOption: Equatable, Sendable {
    let key: String
    let label: String
    let count: Int

    /// Sentinel for the "All providers" choice (`cloud_library_provider_all`).
    static let allKey = "__all__"

    var labelWithCount: String {
        "\(label) (\(count))"
    }
}

/// Empty-state descriptor. Android shows a single empty state when the visible
/// list is empty; we additionally distinguish a truly empty library
/// (`noItems`) from filters/query narrowing results to zero (`noMatches`)
/// so the integrator can act on the difference.
struct LibraryEmptyState: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case noItems
        case noMatches
    }

    let kind: Kind
    let viewMode: LibraryViewMode
    let title: String
    let subtitle: String
}

extension MetaSummary {
    /// Stable library identity matching Android's grid key `"$type:$id"`
    /// and the tvOS watched-key format `"\(type.lowercased()):\(id)"`.
    var libraryIdentityKey: String {
        let normalizedType = type
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(normalizedType):\(id)"
    }
}
