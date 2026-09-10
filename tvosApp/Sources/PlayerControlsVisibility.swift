import SwiftUI

@MainActor
final class PlayerControlsVisibility: ObservableObject {
    @Published private(set) var isVisible = true
    private var dismissTask: Task<Void, Never>?
    private var keepVisible = false
    private var focusHoldsVisibility = false
    private let autoHideInterval: Duration

    init(autoHideInterval: Duration = .seconds(5)) {
        self.autoHideInterval = autoHideInterval
    }

    /// Any remote input or in-player interaction: reveal the controls and
    /// restart the auto-hide countdown.
    func registerInteraction(keepVisible: Bool = false) {
        self.keepVisible = keepVisible
        if !isVisible { isVisible = true }
        scheduleDismissal()
    }

    /// Focus sitting inside the chrome (transport buttons, control strip,
    /// skip button) holds the controls on screen, matching the Apple TV
    /// player where navigating controls never hides them mid-use.
    func setFocusHoldsVisibility(_ holds: Bool) {
        guard focusHoldsVisibility != holds else { return }
        focusHoldsVisibility = holds
        if holds {
            if !isVisible { isVisible = true }
            dismissTask?.cancel()
            dismissTask = nil
        } else {
            scheduleDismissal()
        }
    }

    /// Playback resumed: drop any focus hold and start the countdown so the
    /// chrome fades while the video plays, like the system player.
    func resumeAutoHide() {
        focusHoldsVisibility = false
        scheduleDismissal()
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        keepVisible = false
        focusHoldsVisibility = false
        if isVisible { isVisible = false }
    }

    func cancel() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func scheduleDismissal() {
        dismissTask?.cancel()
        guard !keepVisible, !focusHoldsVisibility else {
            dismissTask = nil
            return
        }
        dismissTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.autoHideInterval)
            guard !Task.isCancelled else { return }
            self.isVisible = false
        }
    }
}
