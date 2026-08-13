import AVFoundation
import Foundation

@MainActor
final class TVAudioSessionCoordinator {
    private let session = AVAudioSession.sharedInstance()
    private var observers: [NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false
    private var isStopped = false
    private let isPlaying: () -> Bool
    private let pause: () -> Void
    private let resume: () -> Void

    init(
        isPlaying: @escaping () -> Bool,
        pause: @escaping () -> Void,
        resume: @escaping () -> Void
    ) {
        self.isPlaying = isPlaying
        self.pause = pause
        self.resume = resume
        observeInterruptions()
    }

    func activate() {
        guard !isStopped else { return }
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            AppLog.playback.error(
                "Audio session activation failed detail=\(AppLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        wasPlayingBeforeInterruption = false
        removeObservers()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            AppLog.playback.error(
                "Audio session deactivation failed detail=\(AppLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        if #available(tvOS 27.0, *) {
            observers.append(center.addObserver(
                forName: AVAudioSession.didBecomeInactiveNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.handleDeactivation(notification) }
            })
            observers.append(center.addObserver(
                forName: AVAudioSession.resumptionRecommendationNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.handleResumption(notification) }
            })
        } else {
            observers.append(center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.handleLegacyInterruption(notification) }
            })
        }
    }

    @available(tvOS 27.0, *)
    private func handleDeactivation(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
                as? AVAudioSession.DeactivationContext,
              context.source == .system else { return }
        pauseForInterruption()
    }

    @available(tvOS 27.0, *)
    private func handleResumption(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.resumptionContextKey]
                as? AVAudioSession.ResumptionContext else { return }
        resumeAfterInterruption(if: context.recommendation == .shouldResume)
    }

    private func handleLegacyInterruption(_ notification: Notification) {
        guard let rawType = (notification.userInfo?[AVAudioSessionInterruptionTypeKey]
                as? NSNumber)?.uintValue,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            pauseForInterruption()
        case .ended:
            let rawOptions = (notification.userInfo?[AVAudioSessionInterruptionOptionKey]
                as? NSNumber)?.uintValue ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            resumeAfterInterruption(if: options.contains(.shouldResume))
        @unknown default:
            break
        }
    }

    private func pauseForInterruption() {
        guard !isStopped else { return }
        wasPlayingBeforeInterruption = isPlaying()
        if wasPlayingBeforeInterruption { pause() }
    }

    private func resumeAfterInterruption(if recommended: Bool) {
        guard !isStopped else { return }
        let shouldResume = recommended && wasPlayingBeforeInterruption
        wasPlayingBeforeInterruption = false
        guard shouldResume else { return }
        activate()
        resume()
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
