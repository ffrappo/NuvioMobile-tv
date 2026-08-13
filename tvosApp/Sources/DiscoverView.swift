import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var addons: AddonStore
    @StateObject private var store = DiscoveryStore()
    @FocusState private var focusedItemID: String?
    let onSelect: (MetaSummary) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                NuvioPageHeader(
                    title: "Discover",
                    subtitle: "Choose a type and catalog, then browse every title"
                )
                filters
                content
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 48)
        }
        .navigationTitle("Discover")
        .task(id: catalogKey) { await store.configure(addons: addons.homeAddons) }
    }

    private var catalogKey: String {
        addons.homeAddons.map { "\($0.baseURL):\($0.manifest.version ?? "")" }.joined(separator: "|")
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.availableTypes.count > 1 {
                filterSection("Type") {
                    ForEach(store.availableTypes, id: \.self) { type in
                        filterButton(type.capitalized, selected: type == store.selectedType) {
                            await store.selectType(type)
                        }
                    }
                }
            }
            filterSection("Catalog") {
                ForEach(store.availableCatalogs) { descriptor in
                    filterButton(
                        descriptor.displayTitle,
                        subtitle: descriptor.addonName,
                        selected: descriptor.catalogID == store.selectedDescriptor?.catalogID &&
                            descriptor.baseURL == store.selectedDescriptor?.baseURL
                    ) {
                        await store.selectCatalog(descriptor.id)
                    }
                }
            }
            if !store.availableGenres.isEmpty {
                filterSection("Genre") {
                    filterButton("All", selected: store.selectedGenre == nil) {
                        await store.selectGenre(nil)
                    }
                    ForEach(store.availableGenres, id: \.self) { genre in
                        filterButton(genre, selected: genre == store.selectedGenre) {
                            await store.selectGenre(genre)
                        }
                    }
                }
            }
        }
        .focusSection()
    }

    private var content: some View {
        Group {
            if store.isLoading && store.items.isEmpty {
                CatalogPlaceholderGrid()
            } else if store.items.isEmpty {
                NuvioUnavailableView(
                    title: store.message ?? "Nothing here yet",
                    symbol: "sparkles.tv",
                    message: "Choose another catalog or try again."
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 236, maximum: 270), spacing: 28)],
                    spacing: 34
                ) {
                    ForEach(store.items) { item in
                        MediaPosterButton(item: item, onSelect: onSelect)
                            .focused($focusedItemID, equals: "\(item.type):\(item.id)")
                    }
                    if store.canLoadMore || store.isLoadingMore {
                        loadMoreButton
                    }
                }
            }
        }
        .focusSection()
    }

    private var loadMoreButton: some View {
        Button {
            Task { await store.loadMore() }
        } label: {
            VStack(spacing: 14) {
                if store.isLoadingMore { ProgressView() }
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 58))
                Text(store.isLoadingMore ? "Loading" : "Load More")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 342)
        }
        .buttonStyle(.card)
        .disabled(store.isLoadingMore)
    }

    private func filterSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 14) { content() }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func filterButton(
        _ title: String,
        subtitle: String? = nil,
        selected: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Group {
            if selected {
                Button { Task { await action() } } label: { filterLabel(title, subtitle: subtitle) }
                    .buttonStyle(.borderedProminent)
            } else {
                Button { Task { await action() } } label: { filterLabel(title, subtitle: subtitle) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func filterLabel(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.tvSafe).font(.headline).lineLimit(1)
            if let subtitle {
                Text(subtitle.tvSafe).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .frame(minWidth: 150, minHeight: 62, alignment: .leading)
    }
}
