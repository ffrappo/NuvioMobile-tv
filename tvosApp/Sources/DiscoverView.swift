import SwiftUI

/// Wave 2 integration: the Android-parity Discover composition wired to the
/// existing DiscoveryStore. Filter, catalog, genre, pagination, and item
/// selection behavior stays in the store; the view renders the parity
/// presentation.
struct DiscoverView: View {
    @EnvironmentObject private var addons: AddonStore
    @StateObject private var store = DiscoveryStore()
    let onSelect: (MetaSummary) -> Void

    var body: some View {
        DiscoverParityView(
            presentation: DiscoverPresentation.build(
                descriptors: store.descriptors,
                selectedType: store.selectedType,
                selectedCatalogID: store.selectedCatalogID,
                selectedGenre: store.selectedGenre,
                items: store.items,
                canLoadMore: store.canLoadMore,
                isLoadingMore: store.isLoadingMore,
                isInitialLoad: store.isLoading && store.items.isEmpty
            ),
            onSelectType: { type in Task { await store.selectType(type) } },
            onSelectCatalog: { id in Task { await store.selectCatalog(id) } },
            onSelectGenre: { genre in Task { await store.selectGenre(genre) } },
            onSelectItem: { item in selectItem(item) },
            onLoadMore: { Task { await store.loadMore() } }
        )
        .task(id: catalogKey) { await store.configure(addons: addons.homeAddons) }
    }

    private var catalogKey: String {
        addons.homeAddons.map { "\($0.baseURL):\($0.manifest.version ?? "")" }.joined(separator: "|")
    }

    private func selectItem(_ item: SearchPosterItem) {
        guard let summary = store.items.first(where: {
            "\($0.type):\($0.id)" == item.id
        }) else { return }
        onSelect(summary)
    }
}
