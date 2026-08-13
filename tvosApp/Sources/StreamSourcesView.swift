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
    @State private var selectedAddon: String?
    @FocusState private var focusedSource: UUID?
    @Environment(\.nuvioTheme) private var theme

    private let repository = StreamRepository.shared
    private let playbackCapabilities = TVPlaybackCapabilities.current

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                DetailSectionHeader(title: "Sources", symbol: "antenna.radiowaves.left.and.right")
                Spacer()
                if !report.sources.isEmpty {
                    Text(sourceCountLabel)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(theme.panel, in: Capsule())
                }
            }
            sourceFilters
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
        } else if isLoading && report.sources.isEmpty {
            HStack(spacing: 16) {
                ProgressView()
                Text("Checking enabled addons").foregroundStyle(.secondary)
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
                ForEach(visibleSources) { source in sourceButton(source) }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    private var playableSources: [StreamSource] {
        orderedSources.filter { $0.stream.directURL != nil && compatibility($0).issue == nil }
    }

    private var orderedSources: [StreamSource] {
        playbackCapabilities.ordered(report.sources)
    }

    private var visibleSources: [StreamSource] {
        guard let selectedAddon else { return orderedSources }
        return orderedSources.filter { $0.addonName == selectedAddon }
    }

    private var addonNames: [String] {
        var seen = Set<String>()
        return orderedSources.map(\.addonName).filter { seen.insert($0).inserted }
    }

    @ViewBuilder
    private var sourceFilters: some View {
        if addonNames.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    sourceFilterButton("All", value: nil)
                    ForEach(addonNames, id: \.self) { sourceFilterButton($0, value: $0) }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .focusSection()
        }
    }

    private func sourceFilterButton(_ title: String, value: String?) -> some View {
        Group {
            if selectedAddon == value {
                Button(title.tvSafe) { selectedAddon = value }.buttonStyle(.borderedProminent)
            } else {
                Button(title.tvSafe) { selectedAddon = value }.buttonStyle(.bordered)
            }
        }
    }

    private var sourceCountLabel: String {
        let limited = orderedSources.filter { compatibility($0).issue != nil }.count
        return limited == 0 ? "\(playableSources.count) ready" : "\(playableSources.count) ready · \(limited) limited"
    }

    private func sourceButton(_ source: StreamSource) -> some View {
        let isDirect = source.stream.directURL != nil
        let compatibility = compatibility(source)
        let isPlayable = isDirect && compatibility.issue == nil
        let info = source.stream.displayInfo
        let labels = infoLabels(info)

        return Button { play(source) } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(source.stream.name.tvSafe)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                        if let issue = compatibility.issue {
                            Text(issue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        } else if !isDirect {
                            Text("Unavailable")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let subtitle = sourceSubtitle(source.stream) {
                        Text(subtitle.tvSafe)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if !labels.isEmpty {
                        HStack(spacing: 7) {
                            ForEach(Array(labels.prefix(6)), id: \.self) { label in sourceBadge(label) }
                        }
                        .lineLimit(1)
                    }
                    if let filename = source.stream.filename?.trimmedNonEmpty,
                       filename != source.stream.name,
                       filename != source.stream.title {
                        Text(filename.tvSafe)
                            .font(.caption2.monospaced())
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                addonIdentity(source)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 126)
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
        .accessibilityValue(accessibilityValue(
            source,
            labels: labels,
            status: compatibility.issue ?? (isDirect ? "Ready" : "Unavailable")
        ))
        .accessibilityHint(isPlayable ? "Stream this source" : "Choose a source marked ready")
    }

    private func sourceBadge(_ label: String) -> some View {
        Text(label.tvSafe)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.separator, lineWidth: 1))
    }

    private func addonIdentity(_ source: StreamSource) -> some View {
        VStack(spacing: 7) {
            if let logo = source.addonLogoURL {
                RemoteArtwork(urlString: logo, systemPlaceholder: "puzzlepiece.extension")
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            }
            Text(source.addonName.tvSafe)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(width: 126)
        }
    }

    private func infoLabels(_ info: StreamDisplayInfo) -> [String] {
        var labels = [info.quality, info.hdr, info.codec].compactMap { $0 }
        labels.append(contentsOf: info.audio)
        labels.append(contentsOf: info.languages)
        if let size = info.size { labels.append("Size \(size)") }
        return labels
    }

    private func sourceSubtitle(_ stream: StremioStream) -> String? {
        if let description = stream.description?.trimmedNonEmpty { return description }
        if let title = stream.title?.trimmedNonEmpty, title != stream.name { return title }
        return nil
    }

    private func accessibilityValue(
        _ source: StreamSource,
        labels: [String],
        status: String
    ) -> String {
        ([status, source.addonName] + labels).joined(separator: ", ")
    }

    private func compatibility(_ source: StreamSource) -> StreamPlaybackCompatibility {
        playbackCapabilities.compatibility(for: source.stream.displayInfo)
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
            availableSources: orderedSources.compactMap(PlayerSourceOption.init),
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
        report = StreamFetchReport(sources: [], failures: [])
        var byIndex: [Int: StreamAddonResult] = [:]
        let request = StreamRequest(type: type, id: videoID, addons: addons)
        for await result in await repository.results(for: request) {
            guard !Task.isCancelled else { return }
            byIndex[result.index] = result
            let ordered = byIndex.values.sorted { $0.index < $1.index }
            report = StreamFetchReport(
                sources: ordered.flatMap(\.sources),
                failures: ordered.compactMap { value in
                    value.failure.map { "\(value.addonName): \($0)" }
                }
            )
        }
        guard !Task.isCancelled else { return }
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
                Text(title).font(.headline)
                Text(message).font(.callout).foregroundStyle(.secondary)
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
            compatibilityIssue: TVPlaybackCapabilities.current.compatibility(
                for: source.stream.displayInfo
            ).issue,
            requestHeaders: source.stream.requestHeaders,
            responseHeaders: source.stream.responseHeaders
        )
    }
}
