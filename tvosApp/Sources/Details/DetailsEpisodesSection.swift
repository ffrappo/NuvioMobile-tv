import SwiftUI

/// Season tabs (focusable capsule row) plus the episode card rail, per Android
/// `EpisodesSection.kt` / `EpisodeRatingsSection.kt`. Watched episodes show the
/// watched marker; the next unwatched episode (continue target) is highlighted.
public struct DetailsEpisodesSectionView: View {
    public let seasons: [DetailsSeasonTab]
    public let selectedSeason: Int
    public let episodes: [DetailsEpisodeItem]
    public let fallbackArtworkURLString: String?
    public let onSelectSeason: (Int) -> Void
    public let onSelectEpisode: (DetailsEpisodeItem) -> Void

    @FocusState private var focusedSeason: Int?
    @State private var pendingSeasonTask: Task<Void, Never>?

    public init(
        seasons: [DetailsSeasonTab],
        selectedSeason: Int,
        episodes: [DetailsEpisodeItem],
        fallbackArtworkURLString: String? = nil,
        onSelectSeason: @escaping (Int) -> Void = { _ in },
        onSelectEpisode: @escaping (DetailsEpisodeItem) -> Void = { _ in }
    ) {
        self.seasons = seasons
        self.selectedSeason = selectedSeason
        self.episodes = episodes
        self.fallbackArtworkURLString = fallbackArtworkURLString
        self.onSelectSeason = onSelectSeason
        self.onSelectEpisode = onSelectEpisode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
            if !seasons.isEmpty {
                seasonTabs
            }
            episodeRail
        }
        .padding(.top, NuvioDesignTokens.Spacing.lg)
        .onDisappear { pendingSeasonTask?.cancel() }
    }

    private var seasonTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NuvioDesignTokens.Spacing.md) {
                ForEach(seasons) { tab in
                    DetailsSeasonTabButton(
                        tab: tab,
                        isSelected: tab.season == selectedSeason,
                        isFocused: focusedSeason == tab.season
                    ) {
                        onSelectSeason(tab.season)
                    }
                    .focused($focusedSeason, equals: tab.season)
                }
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
            .padding(.vertical, NuvioDesignTokens.Spacing.xl)
        }
        .focusSection()
        .onChange(of: focusedSeason) { _, season in
            // Android SeasonTabs selects the focused tab after a 150ms dwell.
            pendingSeasonTask?.cancel()
            guard let season, season != selectedSeason else { return }
            pendingSeasonTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                onSelectSeason(season)
            }
        }
    }

    private var episodeRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: NuvioDesignTokens.Spacing.Rail.itemGap) {
                ForEach(episodes) { episode in
                    DetailsEpisodeCard(
                        episode: episode,
                        fallbackArtworkURLString: fallbackArtworkURLString,
                        onSelect: { onSelectEpisode(episode) }
                    )
                }
            }
            .padding(.horizontal, NuvioDesignTokens.Spacing.Rail.horizontalPadding)
            .padding(.vertical, NuvioDesignTokens.Spacing.Rail.verticalPadding)
        }
        .focusSection()
    }
}

struct DetailsSeasonTabButton: View {
    let tab: DetailsSeasonTab
    let isSelected: Bool
    let isFocused: Bool
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSelect) {
            Text(tab.label)
                .nuvioTextStyle(.playerControl)
                .foregroundStyle(textColor)
                .padding(.horizontal, NuvioDesignTokens.Spacing.xl)
                .padding(.vertical, NuvioDesignTokens.Spacing.sm)
                .background(backgroundColor, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isFocused
                            ? NuvioDesignTokens.Colors.defaultFocus
                            : NuvioDesignTokens.Colors.neutral700,
                        lineWidth: isFocused
                            ? NuvioDesignTokens.Focus.ringWidth
                            : NuvioDesignTokens.Strokes.hairline
                    )
                )
        }
        .buttonStyle(DetailsNoScaleButtonStyle())
        .accessibilityLabel("\(tab.label), \(tab.episodeCount) episodes")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(
            NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
            value: isSelected
        )
        .animation(
            NuvioMotion.animation(for: .focus, reduceMotion: reduceMotion),
            value: isFocused
        )
    }

    private var textColor: Color {
        if isFocused { return NuvioDesignTokens.Colors.canvasBlack }
        if isSelected { return NuvioDesignTokens.Colors.primaryText }
        return NuvioDesignTokens.Colors.secondaryText
    }

    private var backgroundColor: Color {
        if isFocused { return NuvioDesignTokens.Colors.brandFocus }
        if isSelected { return NuvioDesignTokens.Colors.elevatedSecondary }
        return NuvioDesignTokens.Colors.elevated
    }
}

/// Android season tabs keep focusedScale = 1f; this style preserves that.
struct DetailsNoScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(
                NuvioMotion.animation(for: .quick, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

struct DetailsEpisodeCard: View {
    let episode: DetailsEpisodeItem
    let fallbackArtworkURLString: String?
    let onSelect: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSelect) {
            thumbnail
                .overlay(alignment: .bottomLeading) {
                    if episode.progressFraction != nil {
                        DetailsEpisodeProgressBar(fraction: episode.progressFraction ?? 0)
                            .padding(NuvioDesignTokens.Spacing.sm)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if episode.isWatched {
                        watchedMarker
                    } else if episode.isContinueTarget {
                        continueBadge
                    }
                }
        }
        .buttonStyle(DetailsPosterCardButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Plays the episode")
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            NuvioArtworkView(
                urlString: episode.thumbnailURLString ?? fallbackArtworkURLString,
                mode: .backdrop,
                pixelSize: NuvioDesignTokens.Sizes.Cards.episodeThumbnail,
                cornerRadius: NuvioDesignTokens.Shapes.episodeRadius
            )
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.28), location: 0.35),
                    .init(color: .black.opacity(0.72), location: 0.6),
                    .init(color: .black.opacity(0.95), location: 1),
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.xxs) {
                Text("EPISODE \(episode.episode)")
                    .nuvioTextStyle(.badge)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText.opacity(0.9))
                    .padding(.horizontal, NuvioDesignTokens.Spacing.xs)
                    .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
                    .background(
                        NuvioDesignTokens.Colors.canvasBlack.opacity(0.42),
                        in: RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.xxs)
                    )
                Text(episode.title)
                    .nuvioTextStyle(.compactTitle)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                    .lineLimit(2)
                metaRow
            }
            .padding(NuvioDesignTokens.Spacing.md)
        }
        .frame(
            width: NuvioDesignTokens.Sizes.Cards.episodeThumbnail.width,
            height: NuvioDesignTokens.Sizes.Cards.episodeThumbnail.height
        )
        .clipShape(
            RoundedRectangle(cornerRadius: NuvioDesignTokens.Shapes.episodeRadius, style: .continuous)
        )
        .overlay(continueRing)
    }

    @ViewBuilder
    private var metaRow: some View {
        let items = metaTexts
        if !items.isEmpty {
            HStack(spacing: NuvioDesignTokens.Spacing.sm) {
                ForEach(items, id: \.self) { text in
                    Text(text)
                        .nuvioTextStyle(.metadata)
                        .foregroundStyle(
                            text.hasPrefix("IMDb")
                                ? NuvioDesignTokens.Colors.imdb
                                : NuvioDesignTokens.Colors.secondaryText
                        )
                        .lineLimit(1)
                }
            }
        }
    }

    private var metaTexts: [String] {
        var texts: [String] = []
        if let date = episode.airDateText, !date.isEmpty { texts.append(date) }
        if let rating = episode.imdbRatingText { texts.append("IMDb \(rating)") }
        return texts
    }

    private var watchedMarker: some View {
        Image(systemName: "checkmark")
            .nuvioTextStyle(.badge)
            .foregroundStyle(NuvioDesignTokens.Colors.canvasBlack)
            .frame(width: 20, height: 20)
            .background(NuvioDesignTokens.Colors.primaryText, in: Circle())
            .padding(NuvioDesignTokens.Spacing.sm)
            .accessibilityHidden(true)
    }

    private var continueBadge: some View {
        Label("Continue", systemImage: "play.fill")
            .nuvioTextStyle(.badge)
            .foregroundStyle(NuvioDesignTokens.Colors.canvasBlack)
            .padding(.horizontal, NuvioDesignTokens.Spacing.xs)
            .padding(.vertical, NuvioDesignTokens.Spacing.xxs)
            .background(NuvioDesignTokens.Colors.brand, in: Capsule())
            .padding(NuvioDesignTokens.Spacing.sm)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var continueRing: some View {
        // EpisodeWatchedProjection parity: highlight the next unwatched episode.
        if episode.isContinueTarget && !episode.isWatched {
            RoundedRectangle(
                cornerRadius: NuvioDesignTokens.Shapes.episodeRadius,
                style: .continuous
            )
            .strokeBorder(
                NuvioDesignTokens.Colors.brand,
                lineWidth: NuvioDesignTokens.Strokes.medium
            )
            .allowsHitTesting(false)
        }
    }

    private var accessibilityLabel: String {
        "Episode \(episode.episode), \(episode.title)"
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if let date = episode.airDateText, !date.isEmpty { values.append(date) }
        if episode.isWatched { values.append("Watched") }
        if episode.isContinueTarget { values.append("Continue watching") }
        if let progress = episode.progressFraction {
            values.append("\(Int((progress * 100).rounded())) percent watched")
        }
        return values.joined(separator: ", ")
    }
}

struct DetailsEpisodeProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                NuvioDesignTokens.Colors.canvasBlack.opacity(0.45)
                NuvioDesignTokens.Colors.brand
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: NuvioDesignTokens.Strokes.progress)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
