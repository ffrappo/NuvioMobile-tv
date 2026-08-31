import SwiftUI

struct CatalogView: View {
    let onSelect: (MetaSummary) -> Void
    var onOpenCatalog: (CatalogListing) -> Void = { _ in }
    var onOpenCollection: (TVCollection) -> Void = { _ in }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var addons: AddonStore
    @EnvironmentObject private var profiles: TVProfileStore
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var preferences: HomePreferencesStore
    @Environment(\.nuvioTheme) private var theme
    @FocusState private var retryFocused: Bool

    var body: some View {
        Group {
            if home.snapshot.isLoading && !home.snapshot.hasContent {
                loadingState
            } else if !home.snapshot.hasContent {
                emptyState
            } else {
                homeContent
            }
        }
        .background(NuvioDesignTokens.Colors.canvasBlack.ignoresSafeArea())
        .task(id: reloadKey) { await reload() }
        .refreshable { await reload(force: true) }
    }

    private var homeContent: some View {
        let presentation = ModernHomePresentation.build(
            snapshot: home.snapshot,
            preferences: preferences.value
        )
        return ModernHomeCatalogContent(
            presentation: presentation,
            continueWatching: home.snapshot.continueWatching,
            upcoming: home.snapshot.upcoming,
            collections: home.snapshot.collections,
            message: home.snapshot.message,
            isOffline: home.snapshot.isOffline,
            onSelect: onSelect,
            onOpenCatalog: { onOpenCatalog(.from($0)) },
            onOpenCollection: onOpenCollection
        )
    }

    private var reloadKey: String {
        "\(profiles.activeProfileID):\(addons.homeAddons.map(\.baseURL).joined(separator: "|"))"
    }

    private func reload(force: Bool = false) async {
        await home.load(
            addons: addons.homeAddons,
            auth: auth,
            profileID: profiles.activeProfileID,
            force: force
        )
    }

    private var loadingState: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.xl) {
            ProgressView().controlSize(.large)
            Text("Loading your Home").nuvioTextStyle(.sectionTitle)
            Text("Synchronizing catalogs, progress, and collections")
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 640)
    }

    private var emptyState: some View {
        VStack(spacing: NuvioDesignTokens.Spacing.xxl) {
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 72))
            Text("Your Home is ready for content").nuvioTextStyle(.display)
            Text("Enable an addon with catalogs, or retry when your connection returns.")
                .nuvioTextStyle(.body)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            NuvioButton(title: "Retry", symbol: "arrow.clockwise") {
                Task { await reload(force: true) }
            }
            .focused($retryFocused)
        }
        .frame(maxWidth: .infinity, minHeight: 640)
        .defaultFocus($retryFocused, true)
    }
}
