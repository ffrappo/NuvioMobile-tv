import SwiftUI

struct PlayerControlStrip: View {
    let route: PlayerRoute
    @ObservedObject var session: MPVPlaybackSession
    let selectedSourceURL: URL
    let onInteraction: () -> Void
    let onModalPresentationChanged: (Bool) -> Void
    let onSelectSource: (PlayerSourceOption) -> Void
    let onSelectEpisode: (PlayerEpisodeOption) -> Void
    var onToggleStreamInfo: () -> Void = {}
    var onFocusChanged: (Bool) -> Void = { _ in }

    @State private var presentedPanel: Panel?
    @FocusState private var focusedAction: String?

    init(
        route: PlayerRoute,
        session: MPVPlaybackSession,
        selectedSourceURL: URL,
        onInteraction: @escaping () -> Void,
        onModalPresentationChanged: @escaping (Bool) -> Void,
        onSelectSource: @escaping (PlayerSourceOption) -> Void,
        onSelectEpisode: @escaping (PlayerEpisodeOption) -> Void,
        onToggleStreamInfo: @escaping () -> Void = {},
        onFocusChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.route = route
        self.session = session
        self.selectedSourceURL = selectedSourceURL
        self.onInteraction = onInteraction
        self.onModalPresentationChanged = onModalPresentationChanged
        self.onSelectSource = onSelectSource
        self.onSelectEpisode = onSelectEpisode
        self.onToggleStreamInfo = onToggleStreamInfo
        self.onFocusChanged = onFocusChanged
    }

    enum Panel: String, Identifiable {
        case subtitles, audio, sources, episodes
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 16) {
            actionButton(session.resizeMode.title, symbol: session.resizeMode.symbol) {
                session.setResizeMode(session.resizeMode.next)
            }
            speedButton
            actionButton("Info", symbol: "info.circle") { onToggleStreamInfo() }
            actionButton("Subtitles", symbol: "captions.bubble") { presentedPanel = .subtitles }
            if !session.audioTracks.isEmpty {
                actionButton("Audio", symbol: "waveform") { presentedPanel = .audio }
            }
            if route.availableSources.count > 1 {
                actionButton("Sources", symbol: "arrow.left.arrow.right") { presentedPanel = .sources }
            }
            if route.episodes.count > 1 {
                actionButton("Episodes", symbol: "rectangle.stack") { presentedPanel = .episodes }
            }
            AudioRoutePicker(onInteraction: onInteraction)
                .frame(width: 48, height: 48)
                .accessibilityLabel("Audio Output")
        }
        .focusSection()
        .sheet(item: $presentedPanel) { panel in
            PlayerSelectionPanel(
                panel: panel,
                route: route,
                session: session,
                selectedSourceURL: selectedSourceURL,
                onSelectSource: onSelectSource,
                onSelectEpisode: onSelectEpisode
            )
        }
        .onChange(of: presentedPanel) { _, panel in
            onModalPresentationChanged(panel != nil)
            onInteraction()
        }
        .onChange(of: focusedAction) { _, focused in
            onFocusChanged(focused != nil)
        }
        .onAppear {
#if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "-audit-player-panel"),
               args.indices.contains(idx + 1),
               let panel = Panel(rawValue: args[idx + 1]) {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(2000))
                    presentedPanel = panel
                }
            }
#endif
        }
    }

    private var speedButton: some View {
        Button {
            session.setSpeed(session.speed.nextPlaybackSpeed)
            onInteraction()
        } label: {
            Text(speedTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(PlayerPillButtonStyle())
        .focused($focusedAction, equals: "speed")
        .accessibilityLabel("Playback Speed: \(speedTitle)")
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            onInteraction()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(PlayerPillButtonStyle())
        .focused($focusedAction, equals: title)
        .accessibilityLabel(title)
    }

    private var speedTitle: String {
        session.speed == 1 ? "1x" : "\(session.speed.formatted())x"
    }
}

private struct PlayerPillButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.16),
                in: Circle()
            )
            .scaleEffect(
                reduceMotion ? 1 :
                    (isFocused ? 1.08 : (configuration.isPressed ? 0.95 : 1))
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isFocused)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
