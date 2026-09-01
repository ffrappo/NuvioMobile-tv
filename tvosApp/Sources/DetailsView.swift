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
    @State private var selectedSeason: Int?
    @State private var playerRoute: PlayerRoute?

    private let detailsRepository = DetailsRepository.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailsBackdrop(urlString: detail?.background ?? summary.background)

            ScrollView {
                VStack(alignment: .leading, spacing: 42) {
                    if isLoading {
                        DetailsLoadingView()
                    } else if let errorMessage {
                        ErrorPanel(message: errorMessage, retry: reload)
                    } else if let detail {
                        paritySections(detail)
                        paritySections(detail)                    }
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

    @ViewBuilder
    private func paritySections(_ detail: MetaDetail) -> some View {
        let presentation = presentation(detail)
        DetailsHeroHeaderView(
                            model: presentation.hero,
                            actions: heroActions,
                            onAction: performAction
                        )

                        if presentation.isSeries {
                            DetailsEpisodesSectionView(
                                seasons: presentation.seasons,
                                selectedSeason: selectedSeason ?? presentation.seasons.first?.season ?? 1,
                                episodes: presentation.episodes(
                                    season: selectedSeason ?? presentation.seasons.first?.season ?? 1
                                ),
                                fallbackArtworkURLString: detail.background ?? detail.poster,
                                onSelectSeason: { season in selectedSeason = season },
                                onSelectEpisode: { episode in
                                    selectedVideo = detail.videos.first { $0.id == episode.id }
                                }
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
                            episodes: detail.videos.map { video in
                                PlayerEpisodeOption(
                                    id: video.id,
                                    title: video.name,
                                    seasonNumber: video.season,
                                    episodeNumber: video.episode
                                )
                            },
                            addons: addonStore.enabledAddons,
                            onSelectEpisode: { episode in
                                playerRoute = nil
                                selectedVideo = detail.videos.first { $0.id == episode.id }
                            },
                            onPlay: { playerRoute = $0 }
                        )
                        .id(selectedVideo?.id ?? detail.id)

                        if let castSection = presentation.castSection {
                            DetailsCastSectionView(model: castSection)
                        }
                        if let similarSection = presentation.similarSection,
                           !similarSection.items.isEmpty {
                            DetailsMoreLikeThisSectionView(
                                model: similarSection,
                                onSelectItem: { item in selectPosterItem(item) }
                            )
                        }

    }

    private var heroActions: [DetailsHeroActionModel] {
        let isSaved = library.contains(summary.id)
        return [
            DetailsHeroActionModel(
                id: "library",
                title: isSaved ? "Remove from Library" : "Add to Library",
                systemImage: isSaved ? "heart.slash.fill" : "heart.fill"
            ),
        ]
    }

    private func performAction(_ action: DetailsHeroActionModel) {
        guard action.id == "library" else { return }
        library.toggle(detail?.summary ?? summary)
    }

    /// Builds the parity presentation from the loaded detail and the watch
    /// progress of the active profile.
    private func presentation(_ detail: MetaDetail) -> DetailsPresentation {
        let records = watchProgress.records(contentID: detail.id)
        var progressByEpisode: [String: Double] = [:]
        for record in records where record.duration > 0 {
            progressByEpisode[record.videoID] =
                min(max(Double(record.position) / Double(record.duration), 0), 1)
        }
        return DetailsPresentation(
            meta: detail,
            watchedEpisodeIDs: Set(records.filter(\.isCompleted).map(\.videoID)),
            completedEpisodeIDs: Set(records.filter(\.isCompleted).map(\.videoID)),
            progressByEpisodeID: progressByEpisode
        )
    }

    private func selectPosterItem(_ item: DetailsPosterItemModel) {
        // More-like-this navigation reuses the detail route once the
        // recommendation pipeline supplies full summaries.
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
            selectedSeason = selectedVideo?.season
        } catch {
            errorMessage = error.userMessage
        }
        isLoading = false
    }
}
