import SwiftUI

struct StreamSourcesView: View {
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
    @Environment(\.nuvioTheme) private var theme

    private let service = StremioService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                DetailSectionHeader(title: "Sources", symbol: "antenna.radiowaves.left.and.right")
                Spacer()
                if !report.sources.isEmpty {
                    Text("\(playableSources.count) ready")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(theme.panel, in: Capsule())
                }
            }

            sourceContent

            ForEach(report.failures, id: \.self) { failure in
                NuvioStatusMessage(
                    message: failure,
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
        }
        .task(id: requestID) { await loadStreams() }
        .defaultFocus($focusedSource, playableSources.first?.id)
    }

    @ViewBuilder
    private var sourceContent: some View {
        if addons.filter(\.providesStreams).isEmpty {
            SourceEmptyState(
                symbol: "puzzlepiece.extension",
                title: "No stream addons enabled",
                message: "Add a stream addon from Addons to find playable sources."
            )
        } else if isLoading {
            HStack(spacing: 16) {
                ProgressView()
                Text("Checking enabled addons")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: 20))
        } else if report.sources.isEmpty {
            SourceEmptyState(
                symbol: "magnifyingglass",
                title: "No sources found",
                message: "The enabled addons returned no streams for this title."
            )
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(report.sources) { source in
                    sourceButton(source)
                }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    private var playableSources: [StreamSource] {
        report.sources.filter { $0.stream.directURL != nil }
    }

    private func sourceButton(_ source: StreamSource) -> some View {
        let isPlayable = source.stream.directURL != nil
        let info = source.stream.displayInfo

        return Button {
            play(source)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: isPlayable ? "play.fill" : "link.badge.plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isPlayable ? .white : .secondary)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(source.stream.name.tvSafe)
                        .font(.headline)
                        .lineLimit(1)
                    if let subtitle = sourceSubtitle(source.stream) {
                        Text(subtitle.tvSafe)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 7) {
                        ForEach(infoLabels(source, info: info), id: \.self) { label in
                            Text(label.tvSafe)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.14), in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 8)

                Text(isPlayable ? "Play" : "Unavailable")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                isPlayable ? theme.panel : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .opacity(isPlayable ? 1 : 0.5)
        }
        .buttonStyle(.card)
        .disabled(!isPlayable)
        .focused($focusedSource, equals: source.id)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(source.stream.name.tvSafe)
        .accessibilityValue(isPlayable ? "Play" : "Unavailable")
        .accessibilityHint("Stream this source")
    }

    private func infoLabels(_ source: StreamSource, info: StreamDisplayInfo) -> [String] {
        var labels = [
            info.quality, info.hdr, info.codec,
        ].compactMap { $0 } + info.audio + info.languages
        if let size = info.size { labels.append(size) }
        if !labels.contains(source.addonName) { labels.append(source.addonName) }
        return labels
    }

    private func sourceSubtitle(_ stream: StremioStream) -> String? {
        if let description = stream.description?.trimmedNonEmpty { return description }
        if let title = stream.title?.trimmedNonEmpty, title != stream.name { return title }
        return nil
    }

    private func play(_ source: StreamSource) {
        guard let url = source.stream.directURL else { return }
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
            availableSources: report.sources.compactMap(PlayerSourceOption.init),
            episodes: episodes,
            onSelectEpisode: onSelectEpisode
        ))
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

private struct SourceEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    @Environment(\.nuvioTheme) private var theme

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, height: 62)
                .background(Color.white.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 20))
    }
}

extension PlayerSourceOption {
    init?(_ source: StreamSource) {
        guard let url = source.stream.directURL else { return nil }
        self.init(
            id: source.id,
            url: url,
            name: source.stream.name,
            addonName: source.addonName,
            displaySummary: source.stream.displayInfo.summary,
            requestHeaders: source.stream.requestHeaders,
            responseHeaders: source.stream.responseHeaders
        )
    }
}
