import SwiftUI

struct CatalogGridView: View {
    let title: String
    let subtitle: String?
    let items: [MetaSummary]
    let isLoading: Bool
    let isLoadingMore: Bool
    let canLoadMore: Bool
    let message: String?
    let onSelect: (MetaSummary) -> Void
    let onLoadMore: () async -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                NuvioPageHeader(title: title, subtitle: subtitle)
                content
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 48)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && items.isEmpty {
            CatalogPlaceholderGrid()
        } else if items.isEmpty {
            NuvioUnavailableView(
                title: message ?? "Nothing here yet",
                symbol: "rectangle.grid.2x2",
                message: "Try this catalog again later."
            )
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 236, maximum: 270), spacing: 28)],
                spacing: 34
            ) {
                ForEach(items) { item in
                    MediaPosterButton(item: item, onSelect: onSelect)
                }
                if canLoadMore || isLoadingMore {
                    Button { Task { await onLoadMore() } } label: {
                        VStack(spacing: 14) {
                            if isLoadingMore { ProgressView() }
                            Image(systemName: "ellipsis.circle.fill").font(.system(size: 58))
                            Text(isLoadingMore ? "Loading" : "Load More").font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 342)
                    }
                    .buttonStyle(.card)
                    .disabled(isLoadingMore)
                }
            }
        }
    }
}

@MainActor
final class CatalogGridStore: ObservableObject {
    @Published private(set) var listing: CatalogListing
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private let repository: CatalogRepository
    private var duplicatePageCount = 0

    init(listing: CatalogListing, repository: CatalogRepository = .shared) {
        self.listing = listing
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard listing.items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await repository.firstPage(of: listing.descriptor)
            try Task.checkCancellation()
            listing.items = page.items
            listing.nextSkip = page.nextSkip
        } catch is CancellationError {
            return
        } catch {
            message = error.userMessage
        }
    }

    func loadMore() async {
        guard listing.canLoadMore else { return }
        listing.isLoadingMore = true
        defer { listing.isLoadingMore = false }
        do {
            guard let page = try await repository.nextPage(of: listing) else {
                listing.nextSkip = nil
                return
            }
            try Task.checkCancellation()
            let keys = Set(listing.items.map { "\($0.type):\($0.id)" })
            let additions = page.items.filter { !keys.contains("\($0.type):\($0.id)") }
            duplicatePageCount = additions.isEmpty ? duplicatePageCount + 1 : 0
            listing.items.append(contentsOf: additions)
            listing.nextSkip = duplicatePageCount >= 3 ? nil : page.nextSkip
        } catch is CancellationError {
            return
        } catch {
            message = error.userMessage
            listing.nextSkip = nil
        }
    }
}

struct CatalogGridScreen: View {
    @StateObject private var store: CatalogGridStore
    let onSelect: (MetaSummary) -> Void

    init(listing: CatalogListing, onSelect: @escaping (MetaSummary) -> Void) {
        _store = StateObject(wrappedValue: CatalogGridStore(listing: listing))
        self.onSelect = onSelect
    }

    var body: some View {
        CatalogGridView(
            title: store.listing.displayTitle,
            subtitle: store.listing.displaySubtitle,
            items: store.listing.items,
            isLoading: store.isLoading,
            isLoadingMore: store.listing.isLoadingMore,
            canLoadMore: store.listing.canLoadMore,
            message: store.message,
            onSelect: onSelect,
            onLoadMore: store.loadMore
        )
        .task { await store.loadIfNeeded() }
    }
}
