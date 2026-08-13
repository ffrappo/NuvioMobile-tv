import SwiftUI

struct CollectionDetailView: View {
    let collection: TVCollection
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var addons: AddonStore
    @EnvironmentObject private var collections: CollectionStore
    @StateObject private var store = CollectionDetailStore()

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
                folderSelector
                content
            }
            .padding(48)
        }
        .navigationTitle(collection.title.tvSafe)
        .task(id: selectedFolder?.id) { await loadSelectedFolder() }
    }

    private var folderSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 22) {
                ForEach(collection.folders) { folder in
                    Button { store.selectFolderID(folder.id) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            RemoteArtwork(urlString: folder.coverImageUrl, systemPlaceholder: "folder.fill")
                                .frame(width: 230, height: folder.tileShape.lowercased() == "landscape" ? 145 : 230)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            if !folder.hideTitle {
                                Text(folder.title.tvSafe).font(.headline).lineLimit(1)
                            }
                        }
                        .frame(width: 230, alignment: .leading)
                    }
                    .buttonStyle(.card)
                    .accessibilityLabel(folder.title.tvSafe)
                }
            }
            .padding(.vertical, 18)
        }
        .focusSection()
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
