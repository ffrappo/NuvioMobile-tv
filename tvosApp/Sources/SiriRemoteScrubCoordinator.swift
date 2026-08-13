import GameController

@MainActor
final class SiriRemoteScrubCoordinator {
    var onChanged: ((Double) -> Void)?
    var onEnded: (() -> Void)?

    private weak var gamepad: GCMicroGamepad?
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var isEnabled = false
    private var started = false
    private var startX: Float = 0

    init() {
        let center = NotificationCenter.default
        connectObserver = center.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.attach(controller) }
        }
        disconnectObserver = center.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in
                if self?.gamepad === controller.microGamepad { self?.detach() }
            }
        }
    }

    deinit {
        if let connectObserver { NotificationCenter.default.removeObserver(connectObserver) }
        if let disconnectObserver { NotificationCenter.default.removeObserver(disconnectObserver) }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            attach(GCController.current ?? GCController.controllers().first)
        } else {
            finish()
            detach()
        }
    }

    private func attach(_ controller: GCController?) {
        guard isEnabled, let next = controller?.microGamepad else { return }
        if gamepad === next { return }
        detach()
        gamepad = next
        next.reportsAbsoluteDpadValues = true
        next.dpad.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.receive(x: x, y: y) }
        }
        next.buttonA.touchedChangedHandler = { [weak self] _, _, _, touched in
            Task { @MainActor in
                guard let self else { return }
                if touched {
                    self.begin(x: next.dpad.xAxis.value)
                } else {
                    self.finish()
                }
            }
        }
    }

    private func begin(x: Float) {
        guard isEnabled else { return }
        started = true
        startX = x
        onChanged?(0)
    }

    private func receive(x: Float, y: Float) {
        guard isEnabled else { return }
        guard abs(x) >= abs(y) else { return }
        if !started { begin(x: x) }
        let translation = Double(x - startX) / 2
        onChanged?(min(max(translation, -1), 1))
    }

    private func finish() {
        guard started else { return }
        started = false
        onEnded?()
    }

    private func detach() {
        gamepad?.dpad.valueChangedHandler = nil
        gamepad?.buttonA.touchedChangedHandler = nil
        gamepad = nil
    }
}
