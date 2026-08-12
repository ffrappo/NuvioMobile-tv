import SwiftUI

@MainActor
final class PlayerControlsVisibility: ObservableObject {
    @Published private(set) var isVisible = true
    private var dismissTask: Task<Void, Never>?
    private var keepVisible = false

    func registerInteraction(keepVisible: Bool = false) {
        self.keepVisible = keepVisible
        if !isVisible { isVisible = true }
        guard !keepVisible else {
            dismissTask?.cancel()
            dismissTask = nil
            return
        }
        scheduleDismissal()
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        keepVisible = false
        if isVisible { isVisible = false }
    }

    func cancel() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func scheduleDismissal() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.isVisible = false
        }
    }
}
