import SwiftUI

struct SearchView: View {
    let onSelect: (MetaSummary) -> Void

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
                    ProgressView("Searching Cinemeta")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let errorMessage {
                    Label(errorMessage.tvSafe, systemImage: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .padding(30)
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
                    PosterCard(item: item, isFocused: focusedResult == item.id)
                }
                .buttonStyle(NuvioBareButtonStyle())
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
                description: Text("Search movies and series. Press the microphone button on your remote to dictate.")
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
            async let movies = service.catalog(type: "movie", query: value)
            async let series = service.catalog(type: "series", query: value)
            let loaded = try await (movies, series)
            results = loaded.0 + loaded.1
            if let first = results.first { focusedResult = first.id }
        } catch {
            errorMessage = error.userMessage
        }
        isSearching = false
    }
}
