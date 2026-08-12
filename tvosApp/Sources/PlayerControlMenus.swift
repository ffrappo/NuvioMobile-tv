import SwiftUI

struct PlayerControlMenus: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onInteraction: () -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @State private var showSubtitleAppearance = false

    private let speeds = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        HStack(spacing: 18) {
            resizeMenu
            speedMenu
            subtitlesMenu
            if !session.audioTracks.isEmpty { audioMenu }
            volumeMenu
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }

    private var volumeMenu: some View {
        Menu {
            ForEach([0, 25, 50, 75, 100, 125, 130], id: \.self) { level in
                Button {
                    onInteraction()
                    session.setVolume(Double(level))
                } label: {
                    selectedLabel("\(level)%", selected: Int(session.volume) == level)
                }
            }
        } label: {
            controlLabel(volumeTitle, symbol: volumeSymbol)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Volume")
    }

    private var volumeTitle: String {
        "\(Int(session.volume))%"
    }

    private var volumeSymbol: String {
        if session.volume <= 0 { return "speaker.slash.fill" }
        if session.volume < 34 { return "speaker.wave.1.fill" }
        if session.volume < 67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func sourceMenuTitle(_ source: PlayerSourceOption) -> String {
        var title = source.name
        let info = StreamInfo.displayInfo(name: source.name, description: source.detail)
        if info.hasContent { title += " \(info.summary)" }
        return title
    }

    private func controlLabel(_ title: String, symbol: String) -> some View {
        Label(title.tvSafe, systemImage: symbol)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func selectedLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title.tvSafe)
            if selected { Image(systemName: "checkmark") }
        }
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
