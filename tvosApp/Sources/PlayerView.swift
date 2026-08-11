import AVFoundation
import AVKit
import SwiftUI

struct PlayerRoute: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let sourceName: String
}

struct PlayerView: View {
    let route: PlayerRoute

    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = PlayerSession()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            SystemPlayerController(player: session.player)
                .ignoresSafeArea()

            if let errorMessage = session.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(.orange)
                    Text("Playback Error")
                        .font(.title.weight(.bold))
                    Text(errorMessage.tvSafe)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            }
        }
        .onAppear {
            session.load(url: route.url)
        }
        .onDisappear {
            session.stop()
        }
        .onPlayPauseCommand {
            session.togglePlayback()
        }
        .onExitCommand {
            session.stop()
            dismiss()
        }
    }
}

struct SystemPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}

@MainActor
final class PlayerSession: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var errorMessage: String?

    private var statusObservation: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?

    func load(url: URL) {
        errorMessage = nil
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                self?.errorMessage = item.error?.localizedDescription ?? "The video could not be played."
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in
                self?.errorMessage = error?.localizedDescription ?? "Playback stopped unexpectedly."
            }
        }
        player.play()
    }

    func togglePlayback() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation = nil
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }
    }

    deinit {
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
    }
}
