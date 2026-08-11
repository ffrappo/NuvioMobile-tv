import SwiftUI

struct SearchView: View {
    let onSelect: (MetaSummary) -> Void

    @EnvironmentObject private var addons: AddonStore
    @State private var query = ""
    @State private var results: [MetaSummary] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @FocusState private var focusedResult: String?

    private let service = StremioService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if isSearching {
                    ProgressView("Searching your catalogs")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let errorMessage {
                    ErrorPanel(message: errorMessage) { search() }
                } else if results.isEmpty {
                    searchPrompt
                } else {
                    resultsGrid
                }
            }
            .padding(48)
        }
        // The system search field owns focus, keyboard presentation, and Siri
        // Remote dictation. A custom text field hides that native behavior.
        .searchable(text: $query, prompt: "Movie, series, or person")
        .onSubmit(of: .search, search)
        .defaultFocus($focusedResult, results.first?.id)
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 34)], spacing: 38) {
            ForEach(results) { item in
                Button {
                    onSelect(item)
                } label: {
                    PosterCard(item: item)
                }
                .buttonStyle(.card)
                .focused($focusedResult, equals: item.id)
            }
        }
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var searchPrompt: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView(
                "Find Something to Watch",
                systemImage: "sparkle.magnifyingglass",
                description: Text("Search every compatible addon catalog. Press the microphone button on your remote to dictate.")
            )
            .frame(maxWidth: .infinity, minHeight: 420)
        } else {
            ContentUnavailableView.search(text: query)
                .frame(maxWidth: .infinity, minHeight: 420)
        }
    }

    private func search() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            results = []
            return
        }
        Task { await performSearch(value) }
    }

    @MainActor
    private func performSearch(_ value: String) async {
        isSearching = true
        errorMessage = nil
        do {
            let requests = SearchCatalogRequest.compatibleRequests(from: addons.homeAddons)
            let loaded = try await searchCatalogs(requests, query: value)
            results = loaded.deduplicatedSearchResults()
            if let first = results.first { focusedResult = first.id }
        } catch {
            errorMessage = error.userMessage
        }
        isSearching = false
    }

    private func searchCatalogs(
        _ requests: [SearchCatalogRequest],
        query: String
    ) async throws -> [MetaSummary] {
        try await withThrowingTaskGroup(of: (Int, [MetaSummary]?).self) { group in
            for (index, request) in requests.enumerated() {
                group.addTask {
                    do {
                        let items = try await service.catalog(
                            baseURL: request.baseURL,
                            type: request.type,
                            id: request.catalogID,
                            query: query
                        )
                        return (index, items)
                    } catch {
                        AppLog.provider.error(
                            "Search catalog failed addon=\(request.addonName, privacy: .public) catalog=\(request.catalogID, privacy: .public) detail=\(AppLog.safeDescription(error), privacy: .public)"
                        )
                        return (index, nil)
                    }
                }
            }

            var ordered = Array<[MetaSummary]?>(repeating: nil, count: requests.count)
            var successfulRequests = 0
            for try await (index, items) in group {
                guard let items else { continue }
                successfulRequests += 1
                ordered[index] = items
            }
            guard successfulRequests > 0 else { throw StremioServiceError.badResponse }
            return ordered.compactMap { $0 }.flatMap { $0 }
        }
    }
}

struct SearchCatalogRequest: Equatable {
    let baseURL: String
    let addonName: String
    let type: String
    let catalogID: String

    static func compatibleRequests(from addons: [HomeAddon]) -> [SearchCatalogRequest] {
        let requests = addons.flatMap { addon in
            addon.manifest.catalogs.compactMap { catalog -> SearchCatalogRequest? in
                guard catalog.supportsSearch else { return nil }
                return SearchCatalogRequest(
                    baseURL: addon.baseURL,
                    addonName: addon.name,
                    type: catalog.type,
                    catalogID: catalog.id
                )
            }
        }
        return requests.isEmpty ? cinemetaFallback : requests
    }

    private static let cinemetaFallback = [
        SearchCatalogRequest(
            baseURL: StremioService.cinemetaBaseURL.absoluteString,
            addonName: "Cinemeta",
            type: "movie",
            catalogID: "top"
        ),
        SearchCatalogRequest(
            baseURL: StremioService.cinemetaBaseURL.absoluteString,
            addonName: "Cinemeta",
            type: "series",
            catalogID: "top"
        ),
    ]
}

private extension AddonCatalog {
    var supportsSearch: Bool {
        extra.contains { $0.name == "search" }
            && !extra.contains { $0.isRequired && $0.name != "search" }
    }
}

private extension Array where Element == MetaSummary {
    func deduplicatedSearchResults() -> [MetaSummary] {
        var seen = Set<String>()
        return filter { seen.insert("\($0.type):\($0.id)").inserted }
    }
}
