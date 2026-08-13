import SwiftUI

struct PlayerSelectionPanel: View {
    let panel: PlayerControlStrip.Panel
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onSubtitleSelection: (PlaybackTrack?) -> Void
    let onSubtitleAppearanceChanged: () -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsSubtitleAppearance = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) { panelRows }
                    .padding(36)
            }
            .navigationTitle(panel.title)
            .navigationDestination(isPresented: $showsSubtitleAppearance) {
                SubtitleAppearanceView(
                    session: session,
                    onPreferenceChanged: onSubtitleAppearanceChanged
                )
            }
        }
    }

    @ViewBuilder
    private var panelRows: some View {
        switch panel {
        case .subtitles:
            row("Off", symbol: "captions.bubble", selected: !session.subtitleTracks.contains(where: \.isSelected)) {
                onSubtitleSelection(nil)
                dismiss()
            }
            ForEach(session.subtitleTracks) { track in
                row(track.displayName, symbol: "captions.bubble.fill", selected: track.isSelected) {
                    onSubtitleSelection(track)
                    dismiss()
                }
            }
            row("Appearance and Timing", symbol: "textformat", selected: false) {
                showsSubtitleAppearance = true
            }
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
