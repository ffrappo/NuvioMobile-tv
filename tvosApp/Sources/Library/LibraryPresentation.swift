import Foundation

/// Pure, SwiftUI-free presentation model for the Library screen.
///
/// Inputs mirror Android's `LibraryUiState` selection surface: the loaded
/// items, watched keys (`"type:id"`), view mode, selected type tab, provider
/// option (nil = all providers), watched filter, sort option, and the local
/// free-text query. Outputs mirror `withVisibleItems()`: the filtered and
/// sorted item list, type tabs with facet counts, provider options with
/// counts, the offered sort option list, the empty-state descriptor, and a
/// `sortSelectionVersion` that increments only when the sort selection
/// actually changes (Android's `sortSelectionVersion`) so the view can
/// restore focus to the first visible poster after a re-sort.
struct LibraryPresentation: Equatable {
    var items: [MetaSummary]
    var watchedKeys: Set<String>
    var viewMode: LibraryViewMode
    var selectedTypeTabKey: String
    var selectedProviderKey: String?
    var watchedFilter: LibraryWatchedFilter
    var sortOption: LibrarySortOption
    /// Free-text filter applied locally over the already-loaded items.
    /// Never triggers a network request (Android: `cloudSearchQuery`).
    var query: String
    private(set) var sortSelectionVersion: Int

    init(
        items: [MetaSummary] = [],
        watchedKeys: Set<String> = [],
        viewMode: LibraryViewMode = .saved,
        selectedTypeTabKey: String = LibraryTypeTab.allKey,
        selectedProviderKey: String? = nil,
        watchedFilter: LibraryWatchedFilter = .all,
        sortOption: LibrarySortOption = .addedDesc,
        query: String = ""
    ) {
        self.items = items
        self.watchedKeys = watchedKeys
        self.viewMode = viewMode
        self.selectedTypeTabKey = selectedTypeTabKey
        self.selectedProviderKey = selectedProviderKey
        self.watchedFilter = watchedFilter
        self.sortOption = sortOption
        self.query = query
        self.sortSelectionVersion = 0
    }

    /// Android `onSelectSortOption`: bumps `sortSelectionVersion` only when
    /// the selection actually changes.
    mutating func select(sortOption: LibrarySortOption) {
        guard sortOption != self.sortOption else { return }
        self.sortOption = sortOption
        sortSelectionVersion += 1
    }

    // MARK: Outputs

    /// Filtered and sorted visible items (`LibraryUiState.visibleItems`).
    var visibleItems: [MetaSummary] {
        var filtered = items

        // Step 1: provider filter (validated against current options —
        // Android clears selections that no longer resolve).
        if let provider = effectiveProviderKey {
            filtered = filtered.filter { Self.providerKey(for: $0) == provider }
        }

        // Step 2: type filter.
        let typeKey = selectedTypeTabKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !typeKey.isEmpty && typeKey != LibraryTypeTab.allKey {
            filtered = filtered.filter { Self.normalizedTypeKey($0.type) == typeKey }
        }

        // Step 3: watched status filter.
        switch watchedFilter {
        case .all:
            break
        case .watched:
            filtered = filtered.filter(isWatched)
        case .unwatched:
            filtered = filtered.filter { !isWatched($0) }
        }

        // Step 4: local free-text filter over already-loaded items.
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        // Step 5: sort.
        return Self.sorted(filtered, by: sortOption)
    }

    /// Type tabs with facet counts, rebuilt from the full item list
    /// (`buildTypeTabsWithCounts`). Stable order: All, then
    /// movie/series/tv/show/anime, then anything else alphabetically.
    var typeTabs: [LibraryTypeTab] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[Self.normalizedTypeKey(item.type), default: 0] += 1
        }
        let canonicalOrder = ["movie", "series", "tv", "show", "anime"]
        let sortedKeys = counts.keys.sorted { lhs, rhs in
            let lhsIndex = canonicalOrder.firstIndex(of: lhs) ?? canonicalOrder.count
            let rhsIndex = canonicalOrder.firstIndex(of: rhs) ?? canonicalOrder.count
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs < rhs
        }
        var tabs = [LibraryTypeTab(key: LibraryTypeTab.allKey, count: items.count)]
        tabs += sortedKeys.map { LibraryTypeTab(key: $0, count: counts[$0] ?? 0) }
        return tabs
    }

    /// Provider options derived from the items, sorted by label
    /// (Android groups cloud items by provider and sorts by label).
    var providerOptions: [LibraryProviderOption] {
        var counts: [String: Int] = [:]
        for item in items {
            guard let provider = Self.providerKey(for: item) else { continue }
            counts[provider, default: 0] += 1
        }
        return counts
            .map { LibraryProviderOption(key: $0.key, label: $0.key, count: $0.value) }
            .sorted {
                $0.label.lowercased() == $1.label.lowercased()
                    ? $0.key < $1.key
                    : $0.label.lowercased() < $1.label.lowercased()
            }
    }

    /// The selected provider after validation; a stale selection resolves to
    /// nil (all providers), mirroring Android's `validProvider`.
    var effectiveProviderKey: String? {
        guard let key = selectedProviderKey,
              providerOptions.contains(where: { $0.key == key })
        else { return nil }
        return key
    }

    /// Sort options offered in the UI. The tvOS library is a local source,
    /// so this matches Android's `LibrarySortOption.LocalOptions`.
    var sortOptions: [LibrarySortOption] {
        LibrarySortOption.localOptions
    }

    /// Empty-state descriptor (nil when items are visible).
    var emptyState: LibraryEmptyState? {
        if !visibleItems.isEmpty { return nil }
        if items.isEmpty {
            return emptyState(kind: .noItems)
        }
        return emptyState(kind: .noMatches)
    }

    /// Watched marker for a poster (Android checks the movie/series id sets;
    /// here both sides use the `"type:id"` key format).
    func isWatched(_ item: MetaSummary) -> Bool {
        watchedKeys.contains(item.libraryIdentityKey)
    }

    // MARK: Helpers

    private func emptyState(kind: LibraryEmptyState.Kind) -> LibraryEmptyState {
        switch viewMode {
        case .saved:
            // Android `library_empty_local_title`: "No <type> yet" with the
            // selected type label lowercased, falling back to
            // `library_type_items` ("items") — we use that fallback for the
            // All tab, where the literal Android copy would read "No all yet".
            let typeLabel: String
            let selectedKey = selectedTypeTabKey
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if selectedKey.isEmpty || selectedKey == LibraryTypeTab.allKey {
                typeLabel = "items"
            } else {
                typeLabel = LibraryTypeTab.localizedLabel(forKey: selectedKey).lowercased()
            }
            return LibraryEmptyState(
                kind: kind,
                viewMode: viewMode,
                title: "No \(typeLabel) yet",
                subtitle: "Start saving your favorites to see them here"
            )
        case .cloud:
            // Android `cloud_library_empty_title` / `cloud_library_empty_message`.
            return LibraryEmptyState(
                kind: kind,
                viewMode: viewMode,
                title: "Nothing here yet",
                subtitle: "No playable cloud files match the current filters."
            )
        }
    }

    /// Normalized type key: trimmed, lowercased, blank becomes "unknown"
    /// (Android: `(entry.mediaCategory ?: entry.type).trim().ifBlank { "unknown" }`).
    static func normalizedTypeKey(_ type: String) -> String {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    /// Provider key for a saved item: the metadata addon host, nil when the
    /// item has no metadata base URL.
    static func providerKey(for item: MetaSummary) -> String? {
        guard let base = item.metadataBaseURL?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !base.isEmpty,
            let url = URL(string: base),
            let host = url.host,
            !host.isEmpty
        else { return nil }
        return host
    }

    /// Stable sort honoring the selected option. Positions in the input array
    /// are the tiebreak so results are deterministic regardless of Swift's
    /// non-stable `sorted` (Kotlin's `sortedWith` is stable).
    ///
    /// "Added" ordering maps array position: index 0 is treated as the most
    /// recently added item, matching `LibraryStore.toggle` inserting at the
    /// front of the list.
    static func sorted(
        _ items: [MetaSummary],
        by option: LibrarySortOption
    ) -> [MetaSummary] {
        switch option {
        case .providerOrder, .addedDesc:
            // Android: DEFAULT for a local source keeps source order;
            // ADDED_DESC is newest-first, which is the array order here.
            return items
        case .addedAsc:
            return Array(items.reversed())
        case .titleAsc:
            return items
                .enumerated()
                .sorted { lhs, rhs in
                    let left = titleSortKey(for: lhs.element)
                    let right = titleSortKey(for: rhs.element)
                    if left != right { return left < right }
                    return titleTiebreak(lhs, rhs)
                }
                .map(\.element)
        case .titleDesc:
            // Android: compareByDescending(titleSortKey).thenBy(id) — key
            // descending, id ascending.
            return items
                .enumerated()
                .sorted { lhs, rhs in
                    let left = titleSortKey(for: lhs.element)
                    let right = titleSortKey(for: rhs.element)
                    if left != right { return left > right }
                    if lhs.element.id != rhs.element.id {
                        return lhs.element.id < rhs.element.id
                    }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)
        }
    }

    /// Android title comparator tail: equal keys fall back to id (ascending)
    /// then original position.
    private static func titleTiebreak(
        _ lhs: (offset: Int, element: MetaSummary),
        _ rhs: (offset: Int, element: MetaSummary)
    ) -> Bool {
        if lhs.element.id != rhs.element.id {
            return lhs.element.id < rhs.element.id
        }
        return lhs.offset < rhs.offset
    }

    /// Android uses `titleSortKey(it.name.ifBlank { it.id })`: a blank name
    /// falls back to the id as the sort title.
    private static func titleSortKey(for item: MetaSummary) -> String {
        let title = item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? item.id
            : item.name
        return titleSortKey(for: title)
    }

    /// Android `titleSortKey`: strips a leading English article ("the",
    /// "an", "a" followed by whitespace) and lowercases, so "The Walking
    /// Dead" sorts under W.
    static func titleSortKey(for title: String) -> String {
        var key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for article in ["the ", "an ", "a "] where key.hasPrefix(article) {
            key.removeFirst(article.count)
            break
        }
        return key
    }
}
