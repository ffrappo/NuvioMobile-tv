import Foundation

/// Pure presentation builder for the stream sources side panel. Takes the
/// stream list, capability filter, and UI state, and produces the fully
/// filtered, sorted, and badged snapshot the SwiftUI panel renders.
/// Fully testable without SwiftUI.
enum StreamPanelPresentation {
    static func snapshot(for input: StreamPanelInput) -> StreamPanelSnapshot {
        let addonNames = orderedAddonNames(in: input.sources)
        let effectiveAddon = resolvedSelectedAddon(
            selected: input.selectedAddon,
            addonNames: addonNames
        )

        let chips = buildChips(
            addonNames: addonNames,
            sources: input.sources,
            selected: effectiveAddon,
            statuses: input.addonStatuses
        )

        let playability = playability(for: input.sources, filter: input.playbackFilter)
        let keptSources = input.sources.filter { source in
            guard let verdict = playability[source.id] else { return true }
            return !input.playbackFilter.omitUnplayable || verdict.isPlayable
        }

        let filtered = effectiveAddon.map { addon in
            keptSources.filter { $0.addonName == addon }
        } ?? keptSources

        let sorted = StreamPanelSorter.sorted(
            filtered,
            option: input.sortOption,
            preferredLanguages: input.preferredLanguages
        )

        let playingIndex = playingIndex(in: sorted, playing: input.playing)

        let rows = sorted.enumerated().map { index, source in
            let verdict = playability[source.id] ?? StreamPlayability(isPlayable: true, issue: nil)
            return StreamPanelRow(
                id: source.id,
                title: source.stream.name,
                subtitle: subtitle(for: source),
                badges: StreamPanelBadgeComposer.badges(
                    for: source,
                    showFileSize: input.showFileSizeBadges
                ),
                addonName: source.addonName,
                addonLogoURL: source.addonLogoURL,
                filename: filename(for: source),
                isPlaying: index == playingIndex,
                isPlayable: verdict.isPlayable,
                compatibilityIssue: verdict.issue,
                source: source
            )
        }

        let playableCount = rows.filter(\.isPlayable).count
        let limitedCount = rows.count - playableCount
        let anchor = focusAnchor(rows: rows, playingIndex: playingIndex)

        return StreamPanelSnapshot(
            rows: rows,
            chips: chips,
            sortOptions: StreamSortOption.allCases,
            selectedSortOption: input.sortOption,
            playingIndex: playingIndex,
            focusAnchor: anchor,
            totalStreamCount: input.sources.count,
            playableCount: playableCount,
            limitedCount: limitedCount,
            isLoading: input.isLoading,
            failures: input.failures,
            contentState: contentState(
                isLoading: input.isLoading,
                sources: input.sources,
                failures: input.failures
            ),
            headerCountLabel: headerCountLabel(
                totalCount: input.sources.count,
                playableCount: playableCount,
                limitedCount: limitedCount
            )
        )
    }

    // MARK: Addon ordering and filtering

    /// Addons in first-appearance order, matching the tvOS source list and
    /// the Android `orderedAddonNames` build (available addons, then chips).
    static func orderedAddonNames(in sources: [StreamSource]) -> [String] {
        var seen = Set<String>()
        return sources.map(\.addonName).filter { seen.insert($0).inserted }
    }

    /// Android `AddonFilterChips` switches to the last available addon when
    /// the selected addon disappears from the list; "All" (nil) is preserved.
    static func resolvedSelectedAddon(selected: String?, addonNames: [String]) -> String? {
        guard let selected else { return nil }
        return addonNames.contains(selected) ? selected : addonNames.last
    }

    static func buildChips(
        addonNames: [String],
        sources: [StreamSource],
        selected: String?,
        statuses: [String: StreamAddonStatus]
    ) -> [StreamAddonFilterChip] {
        var chips = [
            StreamAddonFilterChip(
                name: nil,
                count: sources.count,
                status: .success,
                isSelected: selected == nil,
                isSelectable: true
            ),
        ]
        for name in addonNames {
            let status = statuses[name] ?? .success
            chips.append(StreamAddonFilterChip(
                name: name,
                count: sources.filter { $0.addonName == name }.count,
                status: status,
                isSelected: selected == name,
                isSelectable: status == .success
            ))
        }
        return chips
    }

    // MARK: Capability filtering

    struct StreamPlayability: Equatable, Sendable {
        let isPlayable: Bool
        let issue: String?
    }

    static func playability(
        for sources: [StreamSource],
        filter: StreamPanelPlaybackFilter
    ) -> [UUID: StreamPlayability] {
        var results: [UUID: StreamPlayability] = [:]
        for source in sources {
            guard source.stream.directURL != nil else {
                results[source.id] = StreamPlayability(
                    isPlayable: false,
                    issue: "Unavailable"
                )
                continue
            }
            if let issue = filter.capabilities.compatibility(
                for: source.stream.displayInfo
            ).issue {
                results[source.id] = StreamPlayability(isPlayable: false, issue: issue)
            } else {
                results[source.id] = StreamPlayability(isPlayable: true, issue: nil)
            }
        }
        return results
    }

    // MARK: Current stream matching

    /// Mirrors Android `findCurrentStreamIndex` adapted to the tvOS stream
    /// model (no info hash): addon + URL first, then URL alone, then
    /// addon + name, then name alone.
    static func playingIndex(
        in sources: [StreamSource],
        playing: StreamPlayingReference?
    ) -> Int? {
        guard let playing, !sources.isEmpty else { return nil }

        if let url = playing.url?.nilIfBlank {
            if let addon = playing.addonName?.nilIfBlank,
               let match = sources.firstIndex(where: {
                   $0.addonName == addon && $0.stream.url == url
               }) {
                return match
            }
            if let match = sources.firstIndex(where: { $0.stream.url == url }) {
                return match
            }
        }
        if let addon = playing.addonName?.nilIfBlank, let name = playing.streamName?.nilIfBlank {
            if let match = sources.firstIndex(where: {
                $0.addonName == addon && $0.stream.name == name
            }) {
                return match
            }
        }
        if let name = playing.streamName?.nilIfBlank,
           let match = sources.firstIndex(where: { $0.stream.name == name }) {
            return match
        }
        return nil
    }

    // MARK: Focus anchor

    /// The row that should receive initial focus: the playing row when
    /// visible, otherwise the first playable row, otherwise the first row.
    static func focusAnchor(rows: [StreamPanelRow], playingIndex: Int?) -> StreamPanelFocusAnchor {
        guard !rows.isEmpty else { return StreamPanelFocusAnchor(rowIndex: nil) }
        if let playingIndex, rows.indices.contains(playingIndex) {
            return StreamPanelFocusAnchor(rowIndex: playingIndex)
        }
        if let firstPlayable = rows.firstIndex(where: \.isPlayable) {
            return StreamPanelFocusAnchor(rowIndex: firstPlayable)
        }
        return StreamPanelFocusAnchor(rowIndex: 0)
    }

    // MARK: States and labels

    static func contentState(
        isLoading: Bool,
        sources: [StreamSource],
        failures: [String]
    ) -> StreamPanelContentState {
        if isLoading { return .loading }
        if sources.isEmpty {
            return failures.isEmpty ? .empty : .failure(failures)
        }
        return .content
    }

    static func headerCountLabel(totalCount: Int, playableCount: Int, limitedCount: Int) -> String {
        let streams = "\(totalCount) stream\(totalCount == 1 ? "" : "s")"
        guard limitedCount > 0 else { return streams }
        return "\(streams) · \(playableCount) ready · \(limitedCount) limited"
    }

    private static func playableCount(of playability: [UUID: StreamPlayability]) -> Int {
        playability.values.filter(\.isPlayable).count
    }

    private static func limitedCount(of playability: [UUID: StreamPlayability]) -> Int {
        playability.values.count - playableCount(of: playability)
    }

    // MARK: Row text

    static func subtitle(for source: StreamSource) -> String? {
        if let description = source.stream.description?.trimmedNonEmpty {
            return description
        }
        if let title = source.stream.title?.trimmedNonEmpty, title != source.stream.name {
            return title
        }
        return nil
    }

    static func filename(for source: StreamSource) -> String? {
        guard let filename = source.stream.filename?.trimmedNonEmpty,
              filename != source.stream.name,
              filename != source.stream.title else { return nil }
        return filename
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
