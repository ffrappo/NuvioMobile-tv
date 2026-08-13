import SwiftUI

struct PlayerControlMenus: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onInteraction: () -> Void
    let onModalPresentationChanged: (Bool) -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @State private var presentedPanel: Panel?

    enum Panel: String, Identifiable {
        case resize, speed, subtitles, audio, sources, episodes
        var id: String { rawValue }
    }

    private let speeds = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        HStack(spacing: 16) {
            panelButton(.resize, title: session.resizeMode.title, symbol: session.resizeMode.symbol)
            panelButton(.speed, title: speedTitle(session.speed), symbol: "speedometer")
            panelButton(.subtitles, title: "Subtitles", symbol: "captions.bubble")
            if !session.audioTracks.isEmpty {
                panelButton(.audio, title: "Audio", symbol: "waveform")
            }
            AudioRoutePicker(onInteraction: onInteraction)
                .frame(width: 68, height: 52)
                .accessibilityLabel("Audio Output")
            if route.availableSources.count > 1 {
                panelButton(.sources, title: "Sources", symbol: "arrow.left.arrow.right")
            }
            if route.episodes.count > 1 {
                panelButton(.episodes, title: "Episodes", symbol: "rectangle.stack")
            }
        }
        .sheet(item: $presentedPanel) { panel in
            NavigationStack {
                List { panelRows(panel) }
                    .navigationTitle(panel.title)
            }
        }
        .onChange(of: presentedPanel) { _, panel in
            onModalPresentationChanged(panel != nil)
        }
    }

    private func panelButton(_ panel: Panel, title: String, symbol: String) -> some View {
        Button {
            onInteraction()
            onModalPresentationChanged(true)
            presentedPanel = panel
        } label: {
            Label(title.tvSafe, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func panelRows(_ panel: Panel) -> some View {
        switch panel {
        case .resize:
            ForEach(PlayerResizeMode.allCases) { mode in
                selectionRow(mode.title, selected: session.resizeMode == mode) {
                    session.setResizeMode(mode)
                }
            }
        case .speed:
            ForEach(speeds, id: \.self) { speed in
                selectionRow(speedTitle(speed), selected: session.speed == speed) {
                    session.setSpeed(speed)
                }
            }
        case .subtitles:
            selectionRow("Off", selected: !session.subtitleTracks.contains(where: \.isSelected)) {
                session.selectSubtitle(id: nil)
            }
            ForEach(session.subtitleTracks) { track in
                selectionRow(track.displayName, selected: track.isSelected) {
                    session.selectSubtitle(id: track.id)
                }
            }
            NavigationLink {
                SubtitleAppearanceView(session: session)
            } label: {
                Label("Appearance and Timing", systemImage: "textformat")
            }
        case .audio:
            ForEach(session.audioTracks) { track in
                selectionRow(track.displayName, selected: track.isSelected) {
                    session.selectAudio(id: track.id)
                }
            }
        case .sources:
            ForEach(route.availableSources) { source in
                selectionRow(sourceMenuTitle(source), selected: source.url == selectedSourceURL) {
                    onSelectSource(source)
                }
            }
        case .episodes:
            ForEach(route.episodes) { episode in
                selectionRow(episodeLabel(episode), selected: episode.id == route.contentID) {
                    onSelectEpisode(episode)
                }
            }
        }
    }

    private func selectionRow(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            onInteraction()
            presentedPanel = nil
        } label: {
            HStack {
                Text(title.tvSafe)
                    .lineLimit(2)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                }
            }
        }
    }

    private func sourceMenuTitle(_ source: PlayerSourceOption) -> String {
        var title = source.name
        if let summary = source.displaySummary?.trimmedNonEmpty { title += "  ·  \(summary)" }
        title += "  ·  \(source.addonName)"
        return title
    }

    private func speedTitle(_ speed: Double) -> String {
        speed == 1 ? "1x" : "\(speed.formatted())x"
    }

    private func episodeLabel(_ episode: PlayerEpisodeOption) -> String {
        guard let season = episode.seasonNumber, let number = episode.episodeNumber else {
            return episode.title
        }
        return "S\(season) E\(number)  \(episode.title)"
    }
}

private extension PlayerControlMenus.Panel {
    var title: String {
        switch self {
        case .resize: return "Video Size"
        case .speed: return "Playback Speed"
        case .subtitles: return "Subtitles"
        case .audio: return "Audio Track"
        case .sources: return "Sources"
        case .episodes: return "Episodes"
        }
    }
}
