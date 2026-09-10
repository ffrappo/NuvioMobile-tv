import SwiftUI

struct PlayerSelectionPanel: View {
    let panel: PlayerControlStrip.Panel
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var addonStore: AddonStore
    @StateObject private var styleStore = SubtitleStyleSettingsStore()
    @State private var sourceAddonFilter: String?
    @State private var externalSubtitleTracks: [SubtitleExternalTrack] = []
    @State private var isLoadingExternalSubtitles = false
    @State private var sourceSort: StreamSortOption = .original
    @State private var showsSubtitleAppearance = false
    @State private var showsTimingDialog = false
    @State private var timingState = SubtitleTimingDialogState()

    var body: some View {
        NavigationStack {
            Group {
                if panel == .subtitles {
                    subtitleSelectionPanel
                } else if panel == .sources && !route.streamSources.isEmpty {
                    sourceSidePanel
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) { panelRows }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle(panel.title)
            .navigationDestination(isPresented: $showsSubtitleAppearance) {
                SubtitleStylePanel(
                    style: styleStore.options,
                    onChange: { updated in
                        styleStore.update(to: updated)
                        session.applySubtitleStyle(updated)
                    },
                    onClose: { showsSubtitleAppearance = false }
                )
                .padding(36)
            }
            .sheet(isPresented: $showsTimingDialog) {
                SubtitleTimingDialog(
                    state: timingState,
                    onAdjustDelay: { delta in
                        session.setSubtitleDelay(
                            milliseconds: session.subtitleDelayMilliseconds + delta
                        )
                        timingState.adjustDelay(byMilliseconds: delta)
                    },
                    onResetDelay: {
                        session.setSubtitleDelay(milliseconds: 0)
                        timingState.resetDelay()
                    },
                    onClose: { showsTimingDialog = false }
                )
                .frame(maxWidth: 620)
                .padding(40)
            }
        }
    }

    @ViewBuilder
    private var panelRows: some View {
        switch panel {
        case .subtitles:
            EmptyView()
        case .audio:
            ForEach(session.audioTracks) { track in
                row(
                    track.displayName,
                    subtitle: track.language?.uppercased(),
                    symbol: "waveform",
                    selected: track.isSelected
                ) {
                    session.selectAudio(id: track.id)
                    dismiss()
                }
            }
        case .sources:
            ForEach(route.availableSources) { source in
                let title = sourceQualityTitle(source)
                row(
                    title,
                    subtitle: source.name,
                    symbol: source.compatibilityIssue == nil ? "play.rectangle.fill" : "exclamationmark.triangle.fill",
                    selected: source.url == selectedSourceURL,
                    enabled: source.compatibilityIssue == nil
                ) {
                    onSelectSource(source)
                    dismiss()
                }
            }
        case .episodes:
            ForEach(route.episodes) { episode in
                row(
                    episodeTitle(episode),
                    symbol: "rectangle.stack.fill",
                    selected: episode.id == route.contentID
                ) {
                    onSelectEpisode(episode)
                    dismiss()
                }
            }
        }
    }

    private var subtitleSelectionPanel: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                row(
                    "Off",
                    subtitle: "Disable subtitles",
                    symbol: "captions.bubble",
                    selected: session.subtitleTracks.allSatisfy { !$0.isSelected }
                ) {
                    session.selectSubtitle(id: nil)
                    dismiss()
                }

                if !session.subtitleTracks.isEmpty {
                    sectionHeader("Built-in Tracks")
                    ForEach(session.subtitleTracks) { track in
                        row(
                            track.displayName,
                            subtitle: track.language?.uppercased(),
                            symbol: "captions.bubble.fill",
                            selected: track.isSelected
                        ) {
                            session.selectSubtitle(id: track.id)
                            dismiss()
                        }
                    }
                }

                if !externalSubtitleTracks.isEmpty {
                    sectionHeader("Addon Subtitles")
                    ForEach(externalSubtitleTracks) { track in
                        row(
                            track.language.capitalized,
                            subtitle: track.addonName,
                            symbol: "arrow.down.circle",
                            selected: track.isSelected
                        ) {
                            session.addExternalSubtitle(
                                url: track.url,
                                title: track.externalID,
                                language: track.language
                            )
                            dismiss()
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.12)).padding(.vertical, 8)

                HStack(spacing: 16) {
                    Button {
                        showsSubtitleAppearance = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "textformat")
                            Text("Appearance")
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(PlayerSelectionRowStyle())

                    Button {
                        timingState = SubtitleTimingDialogState(
                            delayMilliseconds: session.subtitleDelayMilliseconds
                        )
                        showsTimingDialog = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "timer")
                            Text("Sync / Delay")
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(PlayerSelectionRowStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task(id: route.videoID) {
            guard externalSubtitleTracks.isEmpty, !isLoadingExternalSubtitles else { return }
            isLoadingExternalSubtitles = true
            let repository = AddonSubtitleRepository()
            let playingStream = route.streamSources.first {
                $0.stream.url == selectedSourceURL.absoluteString
            }?.stream ?? route.streamSources.first?.stream
            let tracks = await repository.externalTracks(
                type: route.summary.type,
                id: route.summary.id,
                videoID: route.videoID,
                addons: addonStore.enabledAddons,
                filename: playingStream?.filename,
                videoSize: playingStream?.videoSize
            )
            externalSubtitleTracks = tracks
            isLoadingExternalSubtitles = false
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(1.5)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
    }

    /// The parity source side panel (Android `StreamSourcesSidePanel.kt`):
    /// addon chips, sorting, quality/size badges, and compatibility dimming,
    /// fed by the unflattened stream sources carried on the route.
    private var sourceSidePanel: some View {
        StreamSidePanelView(
            snapshot: StreamPanelPresentation.snapshot(for: StreamPanelInput(
                sources: route.streamSources,
                selectedAddon: sourceAddonFilter,
                sortOption: sourceSort,
                playing: StreamPlayingReference(
                    url: selectedSourceURL.absoluteString,
                    addonName: nil,
                    streamName: nil
                )
            )),
            contentInfo: route.title,
            onClose: { dismiss() },
            onReload: {},
            onSelectAddon: { sourceAddonFilter = $0 },
            onSelectSort: { sourceSort = $0 },
            onSelectStream: { row in
                guard let option = PlayerSourceOption(row.source) else { return }
                onSelectSource(option)
                dismiss()
            }
        )
        .frame(maxWidth: 760)
    }

    private func row(
        _ title: String,
        subtitle: String? = nil,
        symbol: String,
        selected: Bool,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.tvSafe)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle.tvSafe)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        }
        .buttonStyle(PlayerSelectionRowStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }

    private func sourceQualityTitle(_ source: PlayerSourceOption) -> String {
        var parts: [String] = []
        if let summary = source.displaySummary?.trimmedNonEmpty {
            parts.append(summary)
        }
        parts.append(source.addonName)
        if let issue = source.compatibilityIssue {
            parts.append("(\(issue))")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func sourceTitle(_ source: PlayerSourceOption) -> String {
        sourceQualityTitle(source)
    }

    private func episodeTitle(_ episode: PlayerEpisodeOption) -> String {
        guard let season = episode.seasonNumber, let number = episode.episodeNumber else {
            return episode.title
        }
        return "S\(season) E\(number) · \(episode.title)"
    }
}

private struct PlayerSelectionRowStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused ? Color.clear : Color.white.opacity(0.16), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension PlayerControlStrip.Panel {
    var title: String {
        switch self {
        case .subtitles: return "Subtitles"
        case .audio: return "Audio Track"
        case .sources: return "Sources"
        case .episodes: return "Episodes"
        }
    }
}
