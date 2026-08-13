import SwiftUI

struct DetailsView: View {
    let summary: MetaSummary

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var addonStore: AddonStore
    @EnvironmentObject private var watchProgress: WatchProgressStore
    @Environment(\.nuvioTheme) private var theme
    @State private var detail: MetaDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedVideo: StremioVideo?
    @State private var playerRoute: PlayerRoute?
    @FocusState private var focusedAction: DetailAction?

    private let detailsRepository = DetailsRepository.shared

    private enum DetailAction: Hashable {
        case favorite
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailsBackdrop(urlString: detail?.background ?? summary.background)

            ScrollView {
                VStack(alignment: .leading, spacing: 42) {
                    hero

                    if isLoading {
                        DetailsLoadingView()
                    } else if let errorMessage {
                        ErrorPanel(message: errorMessage, retry: reload)
                    } else if let detail {
                        if !detail.videos.isEmpty {
                            SeriesEpisodesView(
                                videos: detail.videos,
                                selectedVideo: selectedVideo,
                                fallbackArtwork: detail.background ?? detail.poster,
                                progressRecords: watchProgress.records(contentID: detail.id),
                                onSelect: { selectedVideo = $0 }
                            )
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
                        .id(selectedVideo?.id ?? detail.id)
                        DetailCreditsView(detail: detail)
                    }
                }
                .padding(.horizontal, 72)
                .padding(.top, 64)
                .padding(.bottom, 80)
            }
        }
        .background(theme.background)
        .task { await loadDetail() }
        .fullScreenCover(item: $playerRoute) { route in
            PlayerView(route: route)
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 48) {
            RemoteArtwork(urlString: detail?.poster ?? summary.poster, systemPlaceholder: "film")
                .frame(width: 286, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.separator, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.65), radius: 28, y: 16)

            VStack(alignment: .leading, spacing: 22) {
                Text(detail?.type.uppercased() ?? summary.type.uppercased())
                    .font(.callout.weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)

                Text((detail?.name ?? summary.name).tvSafe)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                DetailFacts(detail: detail, summary: summary)

                libraryButton

                if let description = detail?.description, !description.isEmpty {
                    Text(description.tvSafe)
                        .font(.title3)
                        .foregroundStyle(Color.white.opacity(0.90))
                        .lineSpacing(6)
                        .lineLimit(5)
                        .frame(maxWidth: 970, alignment: .leading)
                }

                DetailTags(detail: detail)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 1420, minHeight: 430, alignment: .leading)
    }

    private var libraryButton: some View {
        let isSaved = library.contains(summary.id)
        return Button {
            library.toggle(detail?.summary ?? summary)
        } label: {
            Label(
                isSaved ? "Remove from Library" : "Add to Library",
                systemImage: isSaved ? "heart.slash.fill" : "heart.fill"
            )
            .font(.headline)
            .padding(.horizontal, 24)
            .frame(minHeight: 62)
        }
        .buttonStyle(.borderedProminent)
        .focused($focusedAction, equals: .favorite)
    }

    private func reload() {
        Task { await loadDetail() }
    }

    @MainActor
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await detailsRepository.detail(for: summary)
            detail = loaded
            let latestResume = watchProgress.latestResumableRecord(contentID: summary.id)
            selectedVideo = summary.playbackVideoID.flatMap { videoID in
                loaded.videos.first { $0.id == videoID }
            } ?? loaded.videos.first { video in
                video.season == summary.playbackSeason && video.episode == summary.playbackEpisode
            } ?? latestResume.flatMap { record in
                loaded.videos.first { video in
                    video.id == record.videoID ||
                        (video.season == record.season && video.episode == record.episode)
                }
            } ?? loaded.videos.first
        } catch {
            errorMessage = error.userMessage
        }
        isLoading = false
    }
}

private struct DetailFacts: View {
    let detail: MetaDetail?
    let summary: MetaSummary
    @Environment(\.nuvioTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            if let year = detail?.releaseInfo ?? summary.releaseInfo {
                fact(year.tvSafe, symbol: "calendar")
            }
            if let runtime = detail?.runtime {
                fact(runtime.tvSafe, symbol: "clock")
            }
            if let rating = detail?.imdbRating, !rating.isEmpty {
                fact("IMDb \(rating.tvSafe)", symbol: "star.fill", tint: .yellow)
            }
        }
    }

    private func fact(_ text: String, symbol: String, tint: Color = .secondary) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(Color.black.opacity(0.42), in: Capsule())
            .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
    }
}

private struct DetailTags: View {
    let detail: MetaDetail?
    @Environment(\.nuvioTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(detail?.genres ?? [], id: \.self) { genre in
                Text(genre.tvSafe)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 15)
                    .frame(minHeight: 38)
                    .background(theme.panel, in: Capsule())
            }

            if let released = detail?.released {
                Label(released.tvReleaseDate, systemImage: "calendar.badge.clock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
        }
    }
}

struct DetailSectionHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
    }
}

extension String {
    var tvReleaseDate: String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: self) else { return tvSafe }
        return date.formatted(.dateTime.month(.wide).day().year())
    }
}

extension PlayerEpisodeOption {
    init(_ video: StremioVideo) {
        self.init(
            id: video.id,
            title: video.name,
            seasonNumber: video.season,
            episodeNumber: video.episode
        )
    }
}
