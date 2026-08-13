import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var addons: AddonStore
    @StateObject private var store = SearchStore()
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    let onSelect: (MetaSummary) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                NuvioPageHeader(
                    title: "Search",
                    subtitle: "Find movies and series across your installed addons"
                )
                searchContent
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 48)
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Movies and series")
        .onSubmit(of: .search) { startSearch(immediately: true) }
        .onChange(of: query) { _, value in
            searchTask?.cancel()
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                store.clear()
            } else if trimmed.count < 2 {
                store.clear(message: "Enter at least two characters.")
            } else {
                startSearch(immediately: false)
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func startSearch(immediately: Bool) {
        searchTask?.cancel()
        let value = query
        let availableAddons = addons.homeAddons
        searchTask = Task {
            if !immediately {
                try? await Task.sleep(for: .milliseconds(350))
            }
            guard !Task.isCancelled else { return }
            await store.search(value, addons: availableAddons)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if store.isLoading && store.items.isEmpty {
            CatalogPlaceholderGrid()
        } else if store.items.isEmpty {
            NuvioUnavailableView(
                title: store.message ?? "Search Nuvio",
                symbol: "magnifyingglass",
                message: "Use the Search tab to enter a title. Catalog browsing lives in Discover."
            )
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 236, maximum: 270), spacing: 28)],
                spacing: 34
            ) {
                ForEach(store.items) { item in
                    MediaPosterButton(item: item, onSelect: onSelect)
                }
            }
        }
    }
}

@MainActor
final class SearchStore: ObservableObject {
    @Published private(set) var items: [MetaSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private let repository: CatalogRepository
    private var requestID = UUID()

    init(repository: CatalogRepository = .shared) {
        self.repository = repository
    }

    func clear(message nextMessage: String? = nil) {
        requestID = UUID()
        items = []
        isLoading = false
        message = nextMessage
    }

    func search(_ rawQuery: String, addons: [HomeAddon]) async {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            clear(message: query.isEmpty ? nil : "Enter at least two characters.")
            return
        }
        requestID = UUID()
        let currentRequest = requestID
        items = []
        message = nil
        isLoading = true
        defer { if requestID == currentRequest { isLoading = false } }

        let descriptors = CatalogDescriptors.search(from: addons)
        let batches = AsyncBatcher.batches(descriptors, limit: 3) { [repository] descriptor in
            do {
                return try await repository.firstPage(of: descriptor, query: query).items
            } catch is CancellationError {
                return []
            } catch {
                return []
            }
        }
        for await batch in batches {
            guard !Task.isCancelled, requestID == currentRequest else { return }
            let additions = batch.flatMap(\.value)
            items = Self.merged(items, additions)
        }
        if requestID == currentRequest, items.isEmpty {
            message = "No results for ‘\(query)’."
        }
    }

    private static func merged(_ existing: [MetaSummary], _ incoming: [MetaSummary]) -> [MetaSummary] {
        var keys = Set(existing.map { "\($0.type):\($0.id)" })
        return existing + incoming.filter { keys.insert("\($0.type):\($0.id)").inserted }
    }
}
