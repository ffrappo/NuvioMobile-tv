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
    @EnvironmentObject private var collections: CollectionStore
    @Environment(\.nuvioTheme) private var theme
    @FocusState private var retryFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 42) {
                if let message = home.snapshot.message { statusBanner(message) }
                content
            }
            .padding(.bottom, 60)
        }
        .background(theme.background)
        .task(id: reloadKey) { await reload() }
        .refreshable { await reload(force: true) }
    }

    @ViewBuilder
    private var content: some View {
        if home.snapshot.isLoading && !home.snapshot.hasContent {
            loadingState
        } else if !home.snapshot.hasContent {
            emptyState
        } else {
            if let hero = home.snapshot.heroItems.first {
                HomeHeroView(item: hero) {
                    onSelect(hero)
                }
            }
            if !home.snapshot.continueWatching.isEmpty {
                Text("Continue Watching")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 48)
                ProgressRail(
                    items: home.snapshot.continueWatching,
                    onSelect: { item in
                        onSelect(item.summary.routedTo(
                            videoID: item.videoID,
                            season: item.season,
                            episode: item.episode
                        ))
                    }
                )
            }
            if !home.snapshot.upcoming.isEmpty {
                Text("Upcoming")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 48)
                ProgressRail(
                    items: home.snapshot.upcoming,
                    onSelect: { item in
                        onSelect(item.summary.routedTo(
                            videoID: item.videoID,
                            season: item.season,
                            episode: item.episode
                        ))
                    }
                )
            }
            ForEach(home.snapshot.collections) { collection in
                CatalogCollectionRail(collection: collection) {
                    onOpenCollection(collection)
                }
            }
            ForEach(home.snapshot.sections) { section in
                CatalogRail(
                    title: sectionTitle(section),
                    subtitle: section.definition.addonName,
                    items: Array(section.items.prefix(18)),
                    onSelect: onSelect,
                    onOpenCatalog: { onOpenCatalog(.from(section)) }
                )
            }
        }
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

    private func sectionTitle(_ section: HomeCatalogSection) -> String {
        let preference = preferences.value.preference(for: section.id)
        if let custom = preference?.customTitle.trimmedNonEmpty { return custom }
        return section.title
    }

    private var loadingState: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.large)
            Text("Loading your Home").font(.title2.weight(.semibold))
            Text("Synchronizing catalogs, progress, and collections")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 640)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 72))
            Text("Your Home is ready for content").font(.largeTitle.weight(.bold))
            Text("Enable an addon with catalogs, or retry when your connection returns.")
                .font(.title3).foregroundStyle(.secondary)
            NuvioButton(title: "Retry", symbol: "arrow.clockwise") {
                Task { await reload(force: true) }
            }
            .focused($retryFocused)
        }
        .frame(maxWidth: .infinity, minHeight: 640)
        .defaultFocus($retryFocused, true)
    }

    private func statusBanner(_ message: String) -> some View {
        Label(message.tvSafe, systemImage: home.snapshot.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
            .font(.headline)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .nuvioAdaptiveSurface(Capsule(), material: .ultraThinMaterial)
            .padding(.horizontal, 48).padding(.top, 30)
    }
}
