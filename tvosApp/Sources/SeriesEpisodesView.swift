import SwiftUI

struct SeriesEpisodesView: View {
    let videos: [StremioVideo]
    let selectedVideo: StremioVideo?
    let fallbackArtwork: String?
    let progressRecords: [WatchProgressRecord]
    let onSelect: (StremioVideo) -> Void

    @State private var selectedSeason: Int?
    @State private var focusedEpisodeBySeason: [Int: String] = [:]
    @FocusState private var focusedEpisodeID: String?
    @Environment(\.nuvioTheme) private var theme

    private var grouped: [Int: [StremioVideo]] {
        Dictionary(grouping: videos) { normalizedSeason($0.season) }
            .mapValues { episodes in
                episodes.sorted {
                    ($0.episode ?? .max, $0.released ?? "", $0.name) <
                        ($1.episode ?? .max, $1.released ?? "", $1.name)
                }
            }
    }

    private var seasons: [Int] {
        grouped.keys.sorted { left, right in
            if left == 0 { return false }
            if right == 0 { return true }
            return left < right
        }
    }

    private var currentSeason: Int {
        let preferred = normalizedSeason(selectedVideo?.season)
        return selectedSeason.flatMap { grouped[$0] == nil ? nil : $0 }
            ?? (grouped[preferred] == nil ? seasons.first ?? 0 : preferred)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if seasons.count > 1 { seasonSelector }
            Text(seasonLabel(currentSeason))
                .font(.title2.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(grouped[currentSeason] ?? []) { video in
                        episodeCard(video)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
        }
        .onAppear { selectedSeason = normalizedSeason(selectedVideo?.season) }
        .onChange(of: selectedVideo?.id) { _, _ in
            selectedSeason = normalizedSeason(selectedVideo?.season)
            focusedEpisodeID = selectedVideo?.id
        }
    }

    private var seasonSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.title2.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(seasons, id: \.self) { season in
                        Button {
                            rememberFocusedEpisode()
                            selectedSeason = season
                            focusedEpisodeID = focusedEpisodeBySeason[season]
                                ?? grouped[season]?.first?.id
                        } label: {
                            VStack(spacing: 8) {
                                RemoteArtwork(
                                    urlString: seasonArtwork(season),
                                    systemPlaceholder: "rectangle.stack.fill"
                                )
                                .frame(width: 150, height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            currentSeason == season ? theme.accent : theme.separator,
                                            lineWidth: currentSeason == season ? 3 : 1
                                        )
                                }
                                Text(seasonLabel(season))
                                    .font(.headline.weight(currentSeason == season ? .bold : .semibold))
                                    .lineLimit(1)
                            }
                            .frame(width: 160)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
        }
    }

    private func episodeCard(_ video: StremioVideo) -> some View {
        let progress = progressRecord(video)
        return Button { onSelect(video) } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteArtwork(
                    urlString: video.thumbnail ?? fallbackArtwork,
                    systemPlaceholder: "play.rectangle.fill"
                )
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.25),
                        .init(color: .black.opacity(0.40), location: 0.55),
                        .init(color: .black.opacity(0.94), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 7) {
                    Text(episodeCode(video))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 7))
                    Text(video.name.tvSafe)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                    if let overview = video.description?.trimmedNonEmpty {
                        Text(overview.tvSafe)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.84))
                            .lineLimit(3)
                    }
                    episodeFacts(video)
                    if let progress, progress.duration > 0, !progress.isCompleted {
                        ProgressView(value: Double(progress.position), total: Double(progress.duration))
                            .tint(theme.accent)
                            .accessibilityLabel("Episode progress")
                    }
                }
                .padding(18)
            }
            .frame(width: 430, height: 265)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if selectedVideo?.id == video.id {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.accent, lineWidth: 3)
                }
            }
            .opacity(video.isAvailable ? 1 : 0.58)
        }
        .buttonStyle(.card)
        .disabled(!video.isAvailable)
        .focused($focusedEpisodeID, equals: video.id)
        .onChange(of: focusedEpisodeID) { _, id in
            if let id { focusedEpisodeBySeason[currentSeason] = id }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episodeCode(video)), \(video.name.tvSafe)")
    }

    @ViewBuilder
    private func episodeFacts(_ video: StremioVideo) -> some View {
        let runtime = video.runtime.map(formatRuntime)
        let release = video.released?.tvReleaseDate
        if runtime != nil || release != nil {
            HStack(spacing: 14) {
                if let runtime { Text(runtime) }
                Spacer()
                if let release { Text(release.tvSafe).lineLimit(1) }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.76))
        }
    }

    private func rememberFocusedEpisode() {
        if let focusedEpisodeID {
            focusedEpisodeBySeason[currentSeason] = focusedEpisodeID
        }
    }

    private func normalizedSeason(_ season: Int?) -> Int {
        guard let season, season > 0 else { return 0 }
        return season
    }

    private func seasonLabel(_ season: Int) -> String {
        season == 0 ? "Specials" : "Season \(season)"
    }

    private func seasonArtwork(_ season: Int) -> String? {
        grouped[season]?.compactMap(\.seasonPoster).first ?? fallbackArtwork
    }

    private func episodeCode(_ video: StremioVideo) -> String {
        guard let episode = video.episode else { return video.name }
        let season = normalizedSeason(video.season)
        return season == 0 ? "Special \(episode)" : "S\(season) E\(episode)"
    }

    private func formatRuntime(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(remainder) min"
    }

    private func progressRecord(_ video: StremioVideo) -> WatchProgressRecord? {
        progressRecords
            .filter {
                $0.videoID == video.id ||
                    ($0.season == video.season && $0.episode == video.episode)
            }
            .max { $0.lastWatched < $1.lastWatched }
    }
}
