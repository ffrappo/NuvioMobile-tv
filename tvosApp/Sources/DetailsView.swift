import SwiftUI

struct DetailsView: View {
    let summary: MetaSummary

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var addonStore: AddonStore
    @State private var detail: MetaDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedVideo: StremioVideo?
    @State private var playerRoute: PlayerRoute?
    @FocusState private var focusedAction: DetailAction?

    private let service = StremioService()

    private enum DetailAction: Hashable {
        case favorite
        case episode(String)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    hero

                    if isLoading {
                        ProgressView("Loading details")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else if let errorMessage {
                        ErrorPanel(message: errorMessage, retry: reload)
                    } else if let detail {
                        metadata(detail)
                        if !detail.videos.isEmpty {
                            episodePicker(detail.videos)
                        }
                        StreamSourcesView(
                            summary: detail.summary,
                            type: detail.type,
                            videoID: selectedVideo?.id ?? detail.id,
                            contentID: selectedVideo?.id ?? detail.id,
                            title: detail.name,
                            seasonNumber: selectedVideo?.season,
                            episodeNumber: selectedVideo?.episode,
                            episodeTitle: selectedVideo?.name,
                            episodes: detail.videos.map(PlayerEpisodeOption.init),
                            addons: addonStore.addons,
                            onSelectEpisode: { episode in
                                playerRoute = nil
                                selectedVideo = detail.videos.first { $0.id == episode.id }
                            },
                            onPlay: { playerRoute = $0 }
                        )
                    }
                }
                .padding(.horizontal, 54)
                .padding(.vertical, 44)
            }
        }
        .background(NuvioTheme.background)
        .task { await loadDetail() }
        .fullScreenCover(item: $playerRoute) { route in
            PlayerView(route: route)
        }
    }

    private var backdrop: some View {
        RemoteArtwork(urlString: detail?.background ?? summary.background, systemPlaceholder: "film.fill")
            .frame(maxWidth: .infinity, maxHeight: 560)
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.30), NuvioTheme.background.opacity(0.72), NuvioTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 34) {
            RemoteArtwork(urlString: detail?.poster ?? summary.poster, systemPlaceholder: "film")
                .frame(width: 250, height: 365)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.7), radius: 25)

            VStack(alignment: .leading, spacing: 18) {
                Text((detail?.name ?? summary.name).tvSafe)
                    .font(.system(size: 52, weight: .bold))
                    .lineLimit(2)

                Text(infoLine)
                    .font(.title3)
                    .foregroundStyle(NuvioTheme.secondaryText)

                Button {
                    library.toggle(detail?.summary ?? summary)
                } label: {
                    Label(
                        library.contains(summary.id) ? "Remove from Library" : "Add to Library",
                        systemImage: library.contains(summary.id) ? "heart.slash.fill" : "heart.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(NuvioTheme.accent)
                .focused($focusedAction, equals: .favorite)
            }
            .padding(.bottom, 12)
        }
        .defaultFocus($focusedAction, .favorite)
    }

    private var infoLine: String {
        let current = detail
        return [current?.releaseInfo ?? summary.releaseInfo, current?.runtime, current?.imdbRating.map { "IMDb \($0)" }]
            .compactMap { $0 }
            .joined(separator: "  |  ")
            .tvSafe
    }

    @ViewBuilder
    private func metadata(_ detail: MetaDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let description = detail.description, !description.isEmpty {
                Text(description.tvSafe)
                    .font(.title3)
                    .lineSpacing(5)
                    .frame(maxWidth: 1150, alignment: .leading)
            }

            if !detail.genres.isEmpty {
                HStack(spacing: 12) {
                    ForEach(detail.genres, id: \.self) { genre in
                        Text(genre.tvSafe)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(NuvioTheme.panel, in: Capsule())
                    }
                }
            }

            if let released = detail.released {
                Text("Released \(released.tvSafe)")
                    .font(.callout)
                    .foregroundStyle(NuvioTheme.secondaryText)
            }
        }
    }

    private func episodePicker(_ videos: [StremioVideo]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Episodes")
                .font(.title2.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(videos) { video in
                        Button {
                            selectedVideo = video
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(video.label.tvSafe)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(video.description?.tvSafe ?? "Choose this episode")
                                    .font(.caption)
                                    .foregroundStyle(NuvioTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            .frame(width: 330, alignment: .leading)
                            .padding(20)
                            .background(
                                selectedVideo?.id == video.id ? NuvioTheme.accent.opacity(0.6) : NuvioTheme.panel,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(focusedAction == .episode(video.id) ? Color.white : .clear, lineWidth: 4)
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedAction, equals: .episode(video.id))
                    }
                }
                .padding(8)
            }
        }
    }

    private func reload() {
        Task { await loadDetail() }
    }

    @MainActor
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await service.details(type: summary.type, id: summary.id)
            detail = loaded
            selectedVideo = loaded.videos.first
        } catch {
            errorMessage = error.userMessage
        }
        isLoading = false
    }
}

private struct StreamSourcesView: View {
    let summary: MetaSummary
    let type: String
    let videoID: String
    let contentID: String
    let title: String
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeTitle: String?
    let episodes: [PlayerEpisodeOption]
    let addons: [AddonEndpoint]
    let onSelectEpisode: (PlayerEpisodeOption) -> Void
    let onPlay: (PlayerRoute) -> Void

    @State private var report = StreamFetchReport(sources: [], failures: [])
    @State private var isLoading = false
    @FocusState private var focusedSource: UUID?

    private let service = StremioService()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sources")
                .font(.title2.weight(.semibold))

            if addons.filter(\.providesStreams).isEmpty {
                Text("Add a stream addon from Addons to find playable sources.")
                    .foregroundStyle(NuvioTheme.secondaryText)
                    .padding(.vertical, 20)
            } else if isLoading {
                ProgressView("Checking enabled addons")
                    .padding(.vertical, 26)
            } else if report.sources.isEmpty {
                Text("No sources were returned for this title.")
                    .foregroundStyle(NuvioTheme.secondaryText)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 14) {
                    ForEach(report.sources) { source in
                        Button {
                            if let url = source.stream.directURL {
                                let options = report.sources.compactMap(PlayerSourceOption.init)
                                onPlay(PlayerRoute(
                                    url: url,
                                    contentID: contentID,
                                    imdbID: imdbID(from: contentID),
                                    title: title,
                                    sourceName: source.stream.name,
                                    summary: summary,
                                    videoID: videoID,
                                    seasonNumber: seasonNumber,
                                    episodeNumber: episodeNumber,
                                    episodeTitle: episodeTitle,
                                    availableSources: options,
                                    episodes: episodes,
                                    onSelectEpisode: onSelectEpisode
                                ))
                            }
                        } label: {
                            HStack(spacing: 18) {
                                Image(systemName: source.stream.directURL == nil ? "link.badge.plus" : "play.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(source.stream.name.tvSafe)
                                        .font(.headline)
                                    Text("\(source.addonName.tvSafe)  |  \(source.stream.directURL == nil ? "Direct playback unavailable" : "Ready to play")")
                                        .font(.caption)
                                        .foregroundStyle(NuvioTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(18)
                            .background(NuvioTheme.panel, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(focusedSource == source.id ? Color.white : .clear, lineWidth: 4)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(source.stream.directURL == nil)
                        .focused($focusedSource, equals: source.id)
                    }
                }
            }

            ForEach(report.failures, id: \.self) { failure in
                Text(failure.tvSafe)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .task(id: requestID) { await loadStreams() }
        .defaultFocus($focusedSource, report.sources.first(where: { $0.stream.directURL != nil })?.id)
    }

    private var requestID: String {
        ([type, videoID] + addons.map(\.baseURL)).joined(separator: "|")
    }

    private func imdbID(from contentID: String) -> String? {
        guard let prefix = contentID.split(separator: ":").first.map(String.init),
              prefix.hasPrefix("tt") else { return nil }
        return prefix
    }

    @MainActor
    private func loadStreams() async {
        guard addons.contains(where: \.providesStreams) else {
            report = StreamFetchReport(sources: [], failures: [])
            return
        }
        isLoading = true
        report = await service.streams(type: type, id: videoID, addons: addons)
        isLoading = false
    }
}

private extension PlayerSourceOption {
    init?(_ source: StreamSource) {
        guard let url = source.stream.directURL else { return nil }
        self.init(
            id: source.id,
            url: url,
            name: source.stream.name,
            addonName: source.addonName,
            requestHeaders: source.stream.requestHeaders
        )
    }
}

private extension PlayerEpisodeOption {
    init(_ video: StremioVideo) {
        self.init(
            id: video.id,
            title: video.name,
            seasonNumber: video.season,
            episodeNumber: video.episode
        )
    }
}

