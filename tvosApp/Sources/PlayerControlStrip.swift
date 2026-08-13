import SwiftUI

struct PlayerControlStrip: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onInteraction: () -> Void
    let onModalPresentationChanged: (Bool) -> Void
    let onSubtitleSelection: (PlaybackTrack?) -> Void
    let onSubtitleAppearanceChanged: () -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void

    @State private var presentedPanel: Panel?

    enum Panel: String, Identifiable {
        case subtitles, audio, sources, episodes
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 6) {
            actionButton(accessibilityLabel: session.resizeMode.title, symbol: session.resizeMode.symbol) {
                session.setResizeMode(session.resizeMode.next)
            }
            actionButton(accessibilityLabel: speedTitle, symbol: "speedometer") {
                session.setSpeed(session.speed.nextPlaybackSpeed)
            }
            actionButton(accessibilityLabel: "Subtitles", symbol: "captions.bubble") {
                presentedPanel = .subtitles
            }
            if !session.audioTracks.isEmpty {
                actionButton(accessibilityLabel: "Audio", symbol: "waveform") {
                    presentedPanel = .audio
                }
            }
            if route.availableSources.count > 1 {
                actionButton(accessibilityLabel: "Sources", symbol: "arrow.left.arrow.right") {
                    presentedPanel = .sources
                }
            }
            if route.episodes.count > 1 {
                actionButton(accessibilityLabel: "Episodes", symbol: "rectangle.stack") {
                    presentedPanel = .episodes
                }
            }
            AudioRoutePicker(onInteraction: onInteraction)
                .frame(width: 68, height: 52)
                .accessibilityLabel("Audio Output")
        }
        .focusSection()
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .nuvioAdaptiveSurface(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(item: $presentedPanel) { panel in
            PlayerSelectionPanel(
                panel: panel,
                route: route,
                session: session,
                selectedSourceURL: selectedSourceURL,
                onSubtitleSelection: onSubtitleSelection,
                onSubtitleAppearanceChanged: onSubtitleAppearanceChanged,
                onSelectSource: onSelectSource,
                onSelectEpisode: onSelectEpisode
            )
        }
        .onChange(of: presentedPanel) { _, panel in
            onModalPresentationChanged(panel != nil)
            onInteraction()
        }
    }

    private func actionButton(
        accessibilityLabel: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            onInteraction()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 50, height: 44)
        }
        .buttonStyle(PlayerPillButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var speedTitle: String {
        session.speed == 1 ? "1x" : "\(session.speed.formatted())x"
    }
}

private struct PlayerPillButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .padding(.horizontal, 8)
            .background(
                isFocused ? Color.white : Color.clear,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension PlayerResizeMode {
    var next: PlayerResizeMode {
        let modes = Self.allCases
        guard let index = modes.firstIndex(of: self) else { return .fit }
        return modes[(index + 1) % modes.count]
    }
}

private extension Double {
    var nextPlaybackSpeed: Double {
        let speeds = [0.5, 0.75, 1, 1.25, 1.5, 2]
        guard let index = speeds.firstIndex(of: self) else { return 1 }
        return speeds[(index + 1) % speeds.count]
    }
}
