import SwiftUI

struct PlayerSelectionPanel: View {
    let panel: PlayerControlStrip.Panel
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var styleStore = SubtitleStyleSettingsStore()
    @State private var sourceAddonFilter: String?
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
                            .padding(36)
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
                row(track.displayName, symbol: "waveform", selected: track.isSelected) {
                    session.selectAudio(id: track.id)
                    dismiss()
                }
            }
        case .sources:
            ForEach(route.availableSources) { source in
                row(
                    sourceTitle(source),
                    symbol: source.compatibilityIssue == nil ? "play.rectangle" : "exclamationmark.triangle.fill",
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
                    symbol: "rectangle.stack",
                    selected: episode.id == route.contentID
                ) {
                    onSelectEpisode(episode)
                    dismiss()
                }
            }
        }
    }

    /// The parity subtitle side panel (Android `SubtitleSelectionOverlay.kt`):
    /// embedded tracks, off state, timing with the dialog, the SDH filter,
    /// and the appearance entry routing to the parity style panel.
    private var subtitleSelectionPanel: some View {
        SubtitleSelectionPanel(
            embeddedTracks: session.subtitleTracks.map { track in
                SubtitleEmbeddedTrack(
                    index: Int(track.id),
                    name: track.displayName,
                    language: track.language,
                    trackID: String(track.id),
                    codec: nil,
                    isForced: false,
                    isSelected: track.isSelected
                )
            },
            externalTracks: [],
            styleOptions: styleStore.options,
            delayMilliseconds: session.subtitleDelayMilliseconds,
            onSelectEmbedded: { embedded in
                session.selectSubtitle(id: Int64(embedded.index))
            },
            onDisableSubtitles: {
                session.selectSubtitle(id: nil)
            },
            onAdjustDelay: { delta in
                session.setSubtitleDelay(
                    milliseconds: session.subtitleDelayMilliseconds + delta
                )
                timingState.adjustDelay(byMilliseconds: delta)
            },
            onOpenTimingDialog: {
                timingState = SubtitleTimingDialogState(
                    delayMilliseconds: session.subtitleDelayMilliseconds
                )
                showsTimingDialog = true
            },
            onToggleSdhFilter: { styleStore.toggleSdhFilter($0) },
            onShowAppearance: { showsSubtitleAppearance = true },
            onClose: { dismiss() }
        )
        .frame(maxWidth: 640)
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
        symbol: String,
        selected: Bool,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol).frame(width: 34)
                Text(title.tvSafe).lineLimit(2)
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        }
        .buttonStyle(PlayerSelectionRowStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }

    private func sourceTitle(_ source: PlayerSourceOption) -> String {
        var parts = [source.name]
        if let summary = source.displaySummary?.trimmedNonEmpty { parts.append(summary) }
        parts.append(source.addonName)
        if let issue = source.compatibilityIssue { parts.append(issue) }
        return parts.joined(separator: "  ·  ")
    }

    private func episodeTitle(_ episode: PlayerEpisodeOption) -> String {
        guard let season = episode.seasonNumber, let number = episode.episodeNumber else {
            return episode.title
        }
        return "S\(season) E\(number)  \(episode.title)"
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
