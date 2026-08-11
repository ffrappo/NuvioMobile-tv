import SwiftUI

struct PlayerRoute: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let sourceName: String
}

struct MPVPlayerView: UIViewControllerRepresentable {
    let session: MPVPlaybackSession

    func makeUIViewController(context: Context) -> MPVPlayerController {
        MPVPlayerController(session: session)
    }

    func updateUIViewController(_ controller: MPVPlayerController, context: Context) {}
}

struct PlayerView: View {
    let route: PlayerRoute

    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = MPVPlaybackSession()
    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MPVPlayerView(session: session).ignoresSafeArea()
            if controlsVisible { controls }
            if let error = session.errorMessage { errorPanel(error) }
        }
        .onAppear { session.load(url: route.url) }
        .onDisappear { session.stop() }
        .onPlayPauseCommand { session.toggle() }
        .onMoveCommand { direction in
            if direction == .left { session.seek(by: -10) }
            if direction == .right { session.seek(by: 10) }
            controlsVisible = true
        }
        .onTapGesture { controlsVisible.toggle() }
        .onExitCommand {
            session.stop()
            dismiss()
        }
    }

    private var controls: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(route.title.tvSafe).font(.title2.weight(.bold))
                        Text(route.sourceName.tvSafe).foregroundStyle(NuvioTheme.secondaryText)
                    }
                    Spacer()
                    if session.isLoading { ProgressView("Loading") }
                }
                ProgressView(value: session.position, total: max(session.duration, 1))
                    .tint(NuvioTheme.accent)
                HStack {
                    Text(time(session.position))
                    Spacer()
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    Spacer()
                    Text(time(session.duration))
                }
                .font(.callout.monospacedDigit())
            }
            .padding(32)
            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
            .padding(50)
        }
        .allowsHitTesting(false)
    }

    private func errorPanel(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 58))
                .foregroundStyle(.orange)
            Text("Playback Error").font(.title.weight(.bold))
            Text(error.tvSafe).font(.title3).multilineTextAlignment(.center)
            Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
        }
        .padding(46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
