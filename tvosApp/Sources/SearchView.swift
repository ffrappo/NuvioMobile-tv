import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var addons: AddonStore
    @StateObject private var store = SearchStore()
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var recentSearches = RecentSearchHistory()
    let onSelect: (MetaSummary) -> Void

    private let recentSearchesKey = "nuvio.tv.recentSearches.v1"

    var body: some View {
        SearchParityView(
            query: $query,
            presentation: SearchParityView.presentation(
                query: query,
                submittedQuery: submittedQuery,
                isSearching: store.isLoading,
                errorMessage: store.message,
                providerResults: store.providerResults,
                recentSearches: recentSearches.items,
                discoverLocation: .inSearch
            ),
            onSubmitQuery: { startSearch(immediately: true) },
            onSelectItem: { item in selectPosterItem(item) },
            onSelectRecentSearch: { value in
                query = value
                startSearch(immediately: true)
            },
            onClearRecentSearches: {
                recentSearches.clear()
                persistRecentSearches()
            },
            onRetry: { startSearch(immediately: true) }
        )
        .onAppear { loadRecentSearches() }
        .onChange(of: query) { _, value in
            searchTask?.cancel()
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                store.clear()
                submittedQuery = ""
            } else if trimmed.count < 2 {
                store.clear(message: "Enter at least two characters.")
            } else {
                startSearch(immediately: false)
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func selectPosterItem(_ item: SearchPosterItem) {
        guard let summary = store.items.first(where: {
            "\($0.type):\($0.id)" == item.id
        }) else { return }
        onSelect(summary)
    }

    private func loadRecentSearches() {
        let encoded = UserDefaults.standard.string(forKey: recentSearchesKey) ?? ""
        recentSearches = RecentSearchHistory(encoded: encoded)
    }

    private func persistRecentSearches() {
        UserDefaults.standard.set(recentSearches.encoded, forKey: recentSearchesKey)
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
            if immediately {
                await MainActor.run {
                    submittedQuery = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if submittedQuery.count >= 2 {
                        recentSearches.save(submittedQuery)
                        persistRecentSearches()
                    }
                }
            }
            await store.search(value, addons: availableAddons)
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

    @Published private(set) var providerResults: [SearchProviderResult] = []

    func clear(message nextMessage: String? = nil) {
        requestID = UUID()
        items = []
        providerResults = []
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
        providerResults = descriptors.map { descriptor in
            SearchProviderResult(
                addonID: descriptor.addonID,
                addonName: descriptor.addonName,
                addonBaseURL: descriptor.baseURL,
                catalogID: descriptor.catalogID,
                catalogName: descriptor.catalogName,
                type: descriptor.type,
                items: [],
                state: .loading
            )
        }
        let values = AsyncBatcher.values(descriptors, limit: 3) { [repository] descriptor in
            do {
                return try await repository.searchPage(of: descriptor, query: query).items
            } catch is CancellationError {
                return []
            } catch {
                return []
            }
        }
        for await result in values {
            guard !Task.isCancelled, requestID == currentRequest else { return }
            publishProviderResult(at: result.index, items: result.value)
            items = Self.merged(items, result.value)
            await Task.yield()
        }
        if requestID == currentRequest, items.isEmpty {
            message = "No results for ‘\(query)’."
        }
    }

    private func publishProviderResult(at index: Int, items incoming: [MetaSummary]) {
        guard providerResults.indices.contains(index) else { return }
        let base = providerResults[index]
        providerResults[index] = SearchProviderResult(
            addonID: base.addonID,
            addonName: base.addonName,
            addonBaseURL: base.addonBaseURL,
            catalogID: base.catalogID,
            catalogName: base.catalogName,
            type: base.type,
            items: incoming,
            state: incoming.isEmpty ? .failed(message: nil) : .loaded
        )
    }

    private static func merged(_ existing: [MetaSummary], _ incoming: [MetaSummary]) -> [MetaSummary] {
        var keys = Set(existing.map { "\($0.type):\($0.id)" })
        return existing + incoming.filter { keys.insert("\($0.type):\($0.id)").inserted }
    }
}
