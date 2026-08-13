import SwiftUI

struct PlayerControlMenus: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onInteraction: () -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @State private var showSubtitleAppearance = false
    @FocusState private var focusedMenu: MenuControl?

    private enum MenuControl: Hashable {
        case resize, speed, subtitles, audio, sources, episodes
    }

    private let speeds = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        HStack(spacing: 18) {
            resizeMenu
            speedMenu
            subtitlesMenu
            if !session.audioTracks.isEmpty { audioMenu }
            AudioRoutePicker(onInteraction: onInteraction)
                .frame(width: 68, height: 52)
                .accessibilityLabel("Audio Output")
            if route.availableSources.count > 1 { sourcesMenu }
            if route.episodes.count > 1 { episodesMenu }
        }
        .sheet(isPresented: $showSubtitleAppearance) {
            SubtitleAppearanceView(session: session)
        }
    }

    private var resizeMenu: some View {
        Menu {
            ForEach(PlayerResizeMode.allCases) { mode in
                Button {
                    onInteraction()
                    session.setResizeMode(mode)
                } label: {
                    selectedLabel(mode.title, selected: session.resizeMode == mode)
                }
            }
        } label: {
            controlLabel(session.resizeMode.title, symbol: session.resizeMode.symbol)
        }
        .buttonStyle(.bordered)
        .focused($focusedMenu, equals: .resize)
        .accessibilityLabel("Video Size")
    }

    private var speedMenu: some View {
        Menu {
            ForEach(speeds, id: \.self) { speed in
                Button {
                    onInteraction()
                    session.setSpeed(speed)
                } label: {
                    selectedLabel(speedTitle(speed), selected: session.speed == speed)
                }
            }
        } label: {
            controlLabel(speedTitle(session.speed), symbol: "speedometer")
        }
        .buttonStyle(.bordered)
        .focused($focusedMenu, equals: .speed)
        .accessibilityLabel("Playback Speed")
    }

    private var subtitlesMenu: some View {
        Menu {
            Button {
                onInteraction()
                session.selectSubtitle(id: nil)
            } label: {
                selectedLabel("Off", selected: !session.subtitleTracks.contains(where: \.isSelected))
            }
            if !session.subtitleTracks.isEmpty { Divider() }
            ForEach(session.subtitleTracks) { track in
                Button {
                    onInteraction()
                    session.selectSubtitle(id: track.id)
                } label: {
                    selectedLabel(track.displayName, selected: track.isSelected)
                }
            }
            Divider()
            Button {
                onInteraction()
                showSubtitleAppearance = true
            } label: {
                Label("Appearance and Timing", systemImage: "textformat")
            }
        } label: {
            controlLabel("Subtitles", symbol: "captions.bubble")
        }
        .buttonStyle(.bordered)
        .focused($focusedMenu, equals: .subtitles)
        .accessibilityLabel("Subtitles")
    }

    private var audioMenu: some View {
        Menu {
            ForEach(session.audioTracks) { track in
                Button {
                    onInteraction()
                    session.selectAudio(id: track.id)
                } label: {
                    selectedLabel(track.displayName, selected: track.isSelected)
                }
            }
        } label: {
            controlLabel("Audio", symbol: "waveform")
        }
        .buttonStyle(.bordered)
        .focused($focusedMenu, equals: .audio)
        .accessibilityLabel("Audio Track")
    }

    private var sourcesMenu: some View {
        Menu {
            ForEach(route.availableSources) { source in
                Button {
                    onInteraction()
                    onSelectSource(source)
                } label: {
                    selectedLabel(
                        sourceMenuTitle(source),
                        selected: source.url == selectedSourceURL
                    )
                }
            }
        } label: {
            controlLabel("Sources", symbol: "arrow.left.arrow.right")
        }
        .buttonStyle(.bordered)
        .focused($focusedMenu, equals: .sources)
        .accessibilityLabel("Sources")
    }

    private var episodesMenu: some View {
        Menu {
            ForEach(route.episodes) { episode in
                Button {
                    onInteraction()
                    onSelectEpisode(episode)
                } label: {
                    selectedLabel(episodeLabel(episode), selected: episode.id == route.contentID)
                }
            }
        } label: {
            controlLabel("Episodes", symbol: "rectangle.stack")
        }
        .buttonStyle(.bordered)
        .focused($focusedMenu, equals: .episodes)
        .accessibilityLabel("Episodes")
    }

    private func sourceMenuTitle(_ source: PlayerSourceOption) -> String {
        var title = source.name
        if let summary = source.displaySummary?.trimmedNonEmpty {
            title += " \(summary)"
        }
        return title
    }

    private func controlLabel(_ title: String, symbol: String) -> some View {
        Label(title.tvSafe, systemImage: symbol)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(minHeight: 44)
    }

    /// tvOS style selection: selected rows are bright with a trailing
    /// checkmark; unselected rows are secondary so the current choice reads
    /// instantly.
    private func selectedLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title.tvSafe)
                .foregroundStyle(selected ? .primary : .secondary)
                .fontWeight(selected ? .semibold : .regular)
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, selected ? 6 : 0)
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