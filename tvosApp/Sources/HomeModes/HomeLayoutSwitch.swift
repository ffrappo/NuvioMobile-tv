import SwiftUI

/// The home layout preference, mirroring the Android HomeLayout enum order
/// (Classic, Grid, Modern) with Modern as the default target per the parity
/// specification.
enum HomeLayoutMode: String, CaseIterable, Codable, Hashable, Sendable {
    case modern
    case classic
    case grid

    /// Android HomeLayout.displayName: "Classic View", "Grid View",
    /// "Modern View".
    var displayName: String {
        switch self {
        case .modern: return "Modern View"
        case .classic: return "Classic View"
        case .grid: return "Grid View"
        }
    }

    static let defaultMode = HomeLayoutMode.modern
}

/// The callbacks every home layout consumes, shared so one wiring works for
/// Modern, Classic, and Grid.
struct HomeLayoutHandlers {
    var onSelect: (MetaSummary) -> Void
    var onOpenCatalog: (HomeCatalogSection) -> Void
    var onOpenCollection: (TVCollection) -> Void
    var onPrefetchCatalog: (String) -> Void

    init(
        onSelect: @escaping (MetaSummary) -> Void,
        onOpenCatalog: @escaping (HomeCatalogSection) -> Void,
        onOpenCollection: @escaping (TVCollection) -> Void,
        onPrefetchCatalog: @escaping (String) -> Void = { _ in }
    ) {
        self.onSelect = onSelect
        self.onOpenCatalog = onOpenCatalog
        self.onOpenCollection = onOpenCollection
        self.onPrefetchCatalog = onPrefetchCatalog
    }
}

/// The switch the integrator uses to select the home layout from a user
/// setting and render the matching content from one shared input contract.
enum HomeLayoutSwitch {
    /// Resolves a persisted setting into a layout mode. Accepts the raw
    /// value ("classic") or the display name ("Classic View"); anything
    /// unrecognized falls back to Modern.
    static func mode(forSetting setting: String?) -> HomeLayoutMode {
        guard let setting, !setting.isEmpty else { return .defaultMode }
        let trimmed = setting.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = HomeLayoutMode(rawValue: trimmed.lowercased()) {
            return raw
        }
        return HomeLayoutMode.allCases.first {
            $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame
        } ?? .defaultMode
    }

    /// Builds the selected layout from the same HomeSnapshot input the
    /// Modern layout uses.
    @ViewBuilder
    static func content(
        mode: HomeLayoutMode,
        snapshot: HomeSnapshot,
        preferences: HomePreferences,
        handlers: HomeLayoutHandlers
    ) -> some View {
        switch mode {
        case .modern:
            ModernHomeCatalogContent(
                presentation: ModernHomePresentation.build(
                    snapshot: snapshot,
                    preferences: preferences
                ),
                continueWatching: snapshot.continueWatching,
                upcoming: snapshot.upcoming,
                collections: snapshot.collections,
                message: snapshot.message,
                isOffline: snapshot.isOffline,
                onSelect: handlers.onSelect,
                onOpenCatalog: handlers.onOpenCatalog,
                onOpenCollection: handlers.onOpenCollection,
                onPrefetchCatalog: handlers.onPrefetchCatalog
            )
        case .classic:
            ClassicHomeView(
                presentation: ClassicHomePresentation.build(
                    snapshot: snapshot,
                    preferences: preferences
                ),
                message: snapshot.message,
                isOffline: snapshot.isOffline,
                onSelect: handlers.onSelect,
                onOpenCatalog: handlers.onOpenCatalog,
                onOpenCollection: handlers.onOpenCollection,
                onPrefetchCatalog: handlers.onPrefetchCatalog
            )
        case .grid:
            GridHomeView(
                presentation: GridHomePresentation.build(
                    snapshot: snapshot,
                    preferences: preferences
                ),
                onSelect: handlers.onSelect,
                onOpenCatalog: handlers.onOpenCatalog,
                onOpenCollection: handlers.onOpenCollection
            )
        }
    }
}
