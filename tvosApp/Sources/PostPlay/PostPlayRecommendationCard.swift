import SwiftUI

/// The recommendation summary block: poster, title (logo with text fallback),
/// metadata line (genres • release info • runtime), rating rows, and the
/// clamped description. Mirrors `PostPlayRecommendationSummary` plus the
/// brief's poster card element.
struct PostPlayRecommendationCard: View {
    let recommendation: PostPlayRecommendation
    let currentTitle: String
    let isTrailerPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: NuvioDesignTokens.Spacing.lg) {
            poster
            VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.md) {
                header
                titleBlock
                if !isTrailerPlaying {
                    metadata
                    ratingRows
                    description
                }
            }
        }
    }

    private var poster: some View {
        NuvioArtworkView(
            urlString: recommendation.poster ?? recommendation.backdrop,
            mode: .poster,
            pixelSize: NuvioDesignTokens.Sizes.Cards.poster,
            cornerRadius: NuvioDesignTokens.Shapes.posterRadius
        )
        .accessibilityHidden(true)
    }

    private var header: some View {
        Text(headerText)
            .font(NuvioTypography.metadata)
            .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
            .lineLimit(1)
    }

    private var headerText: String {
        let trimmed = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Recommended for you" : "Because you watched \(trimmed)"
    }

    @ViewBuilder
    private var titleBlock: some View {
        let logoURL = recommendation.logo.flatMap { $0.isEmpty ? nil : $0 }
        if let logoURL {
            NuvioArtworkView(
                urlString: logoURL,
                mode: .titleLogo,
                pixelSize: CGSize(
                    width: NuvioDesignTokens.Sizes.logo.width,
                    height: isTrailerPlaying ? 44 : 64
                ),
                cornerRadius: 0,
                statePresentation: .transparent,
                placeholderSystemImage: "textformat"
            )
            .frame(maxWidth: 420, alignment: .leading)
            .accessibilityLabel(recommendation.title)
        } else {
            Text(recommendation.title)
                .font(isTrailerPlaying ? NuvioTypography.headline : NuvioTypography.display)
                .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        let line = PostPlayMetadataLine(recommendation: recommendation).text
        if !line.isEmpty {
            Text(line)
                .font(NuvioTypography.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var ratingRows: some View {
        VStack(alignment: .leading, spacing: NuvioDesignTokens.Spacing.sm) {
            PostPlayRatingRow(
                imdbRating: recommendation.showsStandardRatings ? positiveRating(recommendation.rating) : nil,
                tmdbRating: recommendation.showsStandardRatings ? positiveRating(recommendation.tmdbRating) : nil
            )
            if let external = recommendation.externalRatings, !external.isEmpty {
                PostPlayExternalRatingRow(ratings: external)
            }
        }
    }

    private func positiveRating(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    @ViewBuilder
    private var description: some View {
        if let description = recommendation.description,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(description)
                .font(NuvioTypography.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                .lineLimit(3)
                .truncationMode(.tail)
        }
    }
}

/// `metadataLine(context)`: first two genres joined with " • ", then release
/// info and runtime, joined with "  •  ".
struct PostPlayMetadataLine: Equatable {
    let text: String

    init(recommendation: PostPlayRecommendation) {
        text = Self.build(recommendation)
    }

    private static func build(_ recommendation: PostPlayRecommendation) -> String {
        var groups: [String] = []
        let genres = recommendation.genres
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)
        if !genres.isEmpty {
            groups.append(genres.joined(separator: " • "))
        }
        if let releaseInfo = Self.nonBlank(recommendation.releaseInfo) {
            groups.append(releaseInfo)
        }
        if let runtime = Self.nonBlank(recommendation.runtime) {
            groups.append(runtime)
        }
        return groups.joined(separator: "  •  ")
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

/// IMDb + TMDB rating row mirroring `StandardRatingsRow`.
struct PostPlayRatingRow: View {
    let imdbRating: Double?
    let tmdbRating: Double?

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.sm) {
            if let imdbRating {
                ratingLabel("IMDb", value: String(format: "%.1f", imdbRating), tint: NuvioDesignTokens.Colors.imdb)
            }
            if imdbRating != nil && tmdbRating != nil {
                Text("•")
                    .font(NuvioTypography.metadata)
                    .foregroundStyle(NuvioDesignTokens.Colors.neutral500)
            }
            if let tmdbRating {
                ratingLabel("TMDB", value: String(Int(tmdbRating * 10)), tint: NuvioDesignTokens.Colors.tmdb)
            }
        }
    }

    private func ratingLabel(_ source: String, value: String, tint: Color) -> some View {
        HStack(spacing: NuvioDesignTokens.Spacing.xs) {
            Text(source)
                .font(NuvioTypography.button)
                .foregroundStyle(tint)
            Text(value)
                .font(NuvioTypography.metadata)
                .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

/// External (MDBList-style) ratings row mirroring `MDBListRatingsRow`.
struct PostPlayExternalRatingRow: View {
    let ratings: PostPlayExternalRatings

    private var items: [(source: String, value: Double)] {
        [
            ("Trakt", ratings.trakt),
            ("IMDb", ratings.imdb),
            ("TMDB", ratings.tmdb),
            ("Letterboxd", ratings.letterboxd),
            ("MAL", ratings.myAnimeList),
            ("RT", ratings.rottenTomatoes),
        ]
        .compactMap { source, value in
            value.map { (source, $0) }
        }
    }

    var body: some View {
        HStack(spacing: NuvioDesignTokens.Spacing.md) {
            ForEach(items, id: \.source) { item in
                HStack(spacing: NuvioDesignTokens.Spacing.xs) {
                    Text(item.source)
                        .font(NuvioTypography.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.mdblist)
                    Text(String(format: "%.1f", item.value))
                        .font(NuvioTypography.metadata)
                        .foregroundStyle(NuvioDesignTokens.Colors.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Circular trailer auto-play countdown indicator.
struct PostPlayCountdownIndicator: View {
    let seconds: Int?
    let total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let seconds {
            ZStack {
                Circle()
                    .trim(from: 0, to: progress(seconds))
                    .stroke(
                        NuvioDesignTokens.Colors.primaryText,
                        style: StrokeStyle(lineWidth: NuvioDesignTokens.Strokes.progress, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(seconds)")
                    .font(NuvioTypography.button)
                    .foregroundStyle(NuvioDesignTokens.Colors.primaryText)
            }
            .frame(width: NuvioDesignTokens.Sizes.Player.control, height: NuvioDesignTokens.Sizes.Player.control)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: seconds)
            .accessibilityLabel("Trailer starts in \(seconds) seconds")
        }
    }

    private func progress(_ seconds: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(seconds) / Double(total)
    }
}
