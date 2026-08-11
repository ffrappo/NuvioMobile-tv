import SwiftUI

struct SearchView: View {
    let onSelect: (MetaSummary) -> Void

    @State private var query = ""
    @State private var results: [MetaSummary] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @FocusState private var focus: SearchFocus?

    private let service = StremioService()

    private enum SearchFocus: Hashable {
        case field
        case submit
        case result(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Search")
                    .font(.largeTitle.weight(.bold))

                HStack(spacing: 18) {
                    TextField("Movie, series, or person", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(.horizontal, 22)
                        .frame(height: 68)
                        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(focusBorder(.field))
                        .focused($focus, equals: .field)
                        .onSubmit(search)

                    Button(action: search) {
                        Label("Search", systemImage: "magnifyingglass")
                            .font(.headline)
                            .padding(.horizontal, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($focus, equals: .submit)
                }

                if isSearching {
                    ProgressView("Searching Cinemeta")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let errorMessage {
                    Text(errorMessage.tvSafe)
                        .font(.title3)
                        .foregroundStyle(.red)
                        .padding(30)
                } else if results.isEmpty {
                    searchPrompt
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 34)], spacing: 38) {
                        ForEach(results) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                PosterCard(item: item, isFocused: focus == .result(item.id))
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled()
                            .focused($focus, equals: .result(item.id))
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
            .padding(48)
        }
        .defaultFocus($focus, .field)
    }

    private var searchPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 64))
            Text(query.isEmpty ? "Find something to watch" : "No results found")
                .font(.title2)
            Text("Searches movies and series from Cinemeta.")
                .foregroundStyle(NuvioTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func focusBorder(_ target: SearchFocus) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(focus == target ? Color.white : Color.clear, lineWidth: 4)
    }

    private func search() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            results = []
            focus = .field
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
            if let first = results.first { focus = .result(first.id) }
        } catch {
            errorMessage = error.userMessage
        }
        isSearching = false
    }
}

