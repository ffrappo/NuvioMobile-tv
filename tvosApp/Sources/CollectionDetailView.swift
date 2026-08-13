import SwiftUI

struct CollectionDetailView: View {
    let collection: TVCollection
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var addons: AddonStore
    @EnvironmentObject private var collections: CollectionStore
    @State private var selectedFolderID: String?
    @State private var items: [MetaSummary] = []
    @State private var isLoading = false
    @State private var message: String?
    @FocusState private var focusedItemID: String?

    private var selectedFolder: TVCollectionFolder? {
        collection.folders.first { $0.id == selectedFolderID } ?? collection.folders.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                NuvioPageHeader(
                    title: collection.title,
                    subtitle: "Choose a folder, then browse its titles"
                )
                folderSelector
                content
            }
            .padding(48)
        }
        .task(id: selectedFolder?.id) { await loadSelectedFolder() }
    }

    private var folderSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 22) {
                ForEach(collection.folders) { folder in
                    Button { selectedFolderID = folder.id } label: {
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
        if isLoading && items.isEmpty {
            CatalogPlaceholderGrid()
        } else if items.isEmpty {
            NuvioUnavailableView(
                title: message ?? "This folder is empty",
                symbol: "folder",
                message: "Choose another folder or try again later."
            )
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 236, maximum: 270), spacing: 28)],
                spacing: 34
            ) {
                ForEach(items) { item in
                    MediaPosterButton(item: item, onSelect: onSelect)
                        .focused($focusedItemID, equals: "\(item.type):\(item.id)")
                }
            }
            .focusSection()
        }
    }

    private func loadSelectedFolder() async {
        guard let folder = selectedFolder else {
            items = []
            message = "This collection has no folders"
            return
        }
        if selectedFolderID == nil { selectedFolderID = folder.id }
        isLoading = true
        message = nil
        let loaded = await collections.items(for: folder, addons: addons.homeAddons)
        guard !Task.isCancelled else { return }
        items = loaded
        isLoading = false
        if loaded.isEmpty { message = "This folder has no available titles" }
    }
}
