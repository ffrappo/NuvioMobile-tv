import SwiftUI

struct CollectionDetailView: View {
    let collection: TVCollection
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var addons: AddonStore
    @EnvironmentObject private var collections: CollectionStore
    @StateObject private var store = CollectionDetailStore()
    @State private var showsEditor = false

    private var selectedFolder: TVCollectionFolder? {
        collection.folders.first { $0.id == store.selectedFolderID } ?? collection.folders.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                NuvioPageHeader(
                    title: collection.title,
                    subtitle: "Choose a folder, then browse each source"
                )
                CollectionFolderRail(
                    folders: collection.folders.map(CollectionFolderDraft.init)
                ) { folder in
                    store.selectFolderID(folder.id)
                }
                NuvioButton(
                    title: "Edit Collection",
                    symbol: "pencil.circle",
                    action: { showsEditor = true }
                )
                .frame(width: 320)
                content
            }
            .padding(48)
        }
        .navigationTitle(collection.title.tvSafe)
        .task(id: selectedFolder?.id) { await loadSelectedFolder() }
        .sheet(isPresented: $showsEditor) {
            CollectionEditingSheet(existing: collection)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.sourceListings.isEmpty {
            CatalogPlaceholderGrid()
        } else if store.sourceListings.isEmpty {
            NuvioUnavailableView(
                title: store.message ?? "This folder is empty",
                symbol: "folder",
                message: "Choose another folder or try again later."
            )
        } else {
            ForEach(store.sourceListings) { listing in
                CatalogRail(
                    title: listing.displayTitle,
                    subtitle: listing.descriptor.addonName,
                    items: Array(listing.items.prefix(18)),
                    onSelect: onSelect
                )
            }
        }
    }

    private func loadSelectedFolder() async {
        let descriptors = selectedFolder.map {
            collections.descriptors(for: $0, addons: addons.homeAddons)
        } ?? []
        await store.select(folder: selectedFolder, descriptors: descriptors)
    }
}

extension CollectionFolderDraft {
    /// Maps the synced folder wire model onto the editor draft used by the
    /// parity folder tiles.
    init(_ folder: TVCollectionFolder) {
        self.init(
            id: folder.id,
            title: folder.title,
            coverImageUrl: folder.coverImageUrl,
            tileShape: CollectionTileShape(raw: folder.tileShape),
            hideTitle: folder.hideTitle,
            sources: folder.sources.map { source in
                CollectionSourceDraft(
                    provider: source.provider,
                    addonId: source.addonId,
                    type: source.type,
                    catalogId: source.catalogId,
                    genre: source.genre,
                    title: source.title,
                    tmdbSourceType: source.tmdbSourceType,
                    tmdbId: source.tmdbId,
                    traktListId: source.traktListId,
                    mediaType: source.mediaType,
                    sortBy: source.sortBy,
                    sortHow: source.sortHow
                )
            }
        )
    }
}
