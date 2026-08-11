import SwiftUI

struct CatalogView: View {
    let onSelect: (MetaSummary) -> Void

    @State private var movies: [MetaSummary] = []
    @State private var series: [MetaSummary] = []
    @State private var manifestName = "Cinemeta"
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = StremioService()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 44) {
                header

                if isLoading {
                    ProgressView("Loading popular catalogs")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let errorMessage {
                    ErrorPanel(message: errorMessage, retry: load)
                } else {
                    CatalogRail(title: "Popular Movies", items: movies, onSelect: onSelect)
                    CatalogRail(title: "Popular Series", items: series, onSelect: onSelect)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
        }
        .task { await loadContent() }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Image("NuvioLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: NuvioTheme.accent.opacity(0.45), radius: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Nuvio")
                    .font(.largeTitle.weight(.bold))
                Text("Popular picks from \(manifestName.tvSafe)")
                    .font(.title3)
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
        }
    }

    private func load() {
        Task { await loadContent() }
    }

    @MainActor
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let manifest = try await service.cinemetaManifest()
            manifestName = manifest.name
            let movieCatalog = manifest.catalogs.first { $0.type == "movie" && $0.id == "top" }
            let seriesCatalog = manifest.catalogs.first { $0.type == "series" && $0.id == "top" }
            async let movieItems = service.catalog(
                type: "movie",
                id: movieCatalog?.id ?? "top"
            )
            async let seriesItems = service.catalog(
                type: "series",
                id: seriesCatalog?.id ?? "top"
            )
            let loaded = try await (movieItems, seriesItems)
            movies = loaded.0
            series = loaded.1
        } catch {
            errorMessage = error.userMessage
        }
        isLoading = false
    }
}

struct CatalogRail: View {
    let title: String
    let items: [MetaSummary]
    let onSelect: (MetaSummary) -> Void

    @FocusState private var focusedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            PosterCard(item: item, isFocused: focusedID == item.id)
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .focused($focusedID, equals: item.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 22)
            }
        }
        .defaultFocus($focusedID, items.first?.id)
    }
}

struct PosterCard: View {
    let item: MetaSummary
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtwork(urlString: item.poster, systemPlaceholder: "film")
                .frame(width: 220, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isFocused ? NuvioTheme.accent : Color.white.opacity(0.12), lineWidth: isFocused ? 5 : 1)
                )
                .shadow(color: isFocused ? NuvioTheme.accent.opacity(0.75) : .black.opacity(0.45), radius: isFocused ? 24 : 10)

            Text(item.name.tvSafe)
                .font(.headline)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)

            Text(item.releaseInfo?.tvSafe ?? item.type.capitalized)
                .font(.subheadline)
                .foregroundStyle(NuvioTheme.secondaryText)
        }
        .scaleEffect(isFocused ? 1.07 : 1)
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

struct RemoteArtwork: View {
    let urlString: String?
    let systemPlaceholder: String

    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                ZStack {
                    NuvioTheme.panel
                    ProgressView()
                }
            default:
                ZStack {
                    NuvioTheme.panel
                    Image(systemName: systemPlaceholder)
                        .font(.system(size: 54))
                        .foregroundStyle(NuvioTheme.secondaryText)
                }
            }
        }
        .clipped()
    }
}

struct ErrorPanel: View {
    let message: String
    let retry: () -> Void
    @FocusState private var retryFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 54))
            Text(message.tvSafe)
                .font(.title3)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .focused($retryFocused)
        }
        .padding(42)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 24))
        .defaultFocus($retryFocused, true)
    }
}

