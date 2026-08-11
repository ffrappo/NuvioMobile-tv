import SwiftUI

struct PlayerOptionsView: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @Environment(\.dismiss) private var dismiss

    private let speeds = [0.5, 0.75, 1, 1.25, 1.5, 2]

    var body: some View {
        NavigationStack {
            List {
                Section("Playback Speed") {
                    ForEach(speeds, id: \.self) { speed in
                        Button {
                            session.setSpeed(speed)
                        } label: {
                            optionLabel(
                                title: speed == 1 ? "Normal" : "\(speed.formatted())x",
                                selected: session.speed == speed
                            )
                        }
                    }
                }

                Section("Video Size") {
                    ForEach(PlayerResizeMode.allCases) { mode in
                        Button {
                            session.setResizeMode(mode)
                        } label: {
                            Label {
                                optionLabel(title: mode.title, selected: session.resizeMode == mode)
                            } icon: {
                                Image(systemName: mode.symbol)
                            }
                        }
                    }
                }

                if !session.audioTracks.isEmpty {
                    Section("Audio") {
                        ForEach(session.audioTracks) { track in
                            Button { session.selectAudio(id: track.id) } label: {
                                optionLabel(title: track.displayName, selected: track.isSelected)
                            }
                        }
                    }
                }

                Section("Subtitles") {
                    Button { session.selectSubtitle(id: nil) } label: {
                        optionLabel(
                            title: "Off",
                            selected: !session.subtitleTracks.contains(where: \.isSelected)
                        )
                    }
                    ForEach(session.subtitleTracks) { track in
                        Button { session.selectSubtitle(id: track.id) } label: {
                            optionLabel(title: track.displayName, selected: track.isSelected)
                        }
                    }
                }

                if route.availableSources.count > 1 {
                    Section("Sources") {
                        ForEach(route.availableSources) { source in
                            Button {
                                onSelectSource(source)
                                dismiss()
                            } label: {
                                optionLabel(
                                    title: "\(source.name)  |  \(source.addonName)",
                                    selected: source.url == selectedSourceURL
                                )
                            }
                        }
                    }
                }

                if route.episodes.count > 1 {
                    Section("Episodes") {
                        ForEach(route.episodes) { episode in
                            Button {
                                onSelectEpisode(episode)
                                dismiss()
                            } label: {
                                optionLabel(
                                    title: episodeLabel(episode),
                                    selected: episode.id == route.contentID
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playback Options")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func optionLabel(title: String, selected: Bool) -> some View {
        HStack {
            Text(title.tvSafe)
            Spacer()
            if selected { Image(systemName: "checkmark") }
        }
    }

    private func episodeLabel(_ episode: PlayerEpisodeOption) -> String {
        guard let season = episode.seasonNumber, let number = episode.episodeNumber else {
            return episode.title
        }
        return "S\(season) E\(number)  \(episode.title)"
    }
}
