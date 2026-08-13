import SwiftUI
import UIKit

struct TVTimelinePanControl: UIViewRepresentable {
    let progress: Double
    let isEnabled: Bool
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    func makeUIView(context: Context) -> TimelinePanControl {
        TimelinePanControl(
            progress: progress,
            onChanged: onChanged,
            onEnded: onEnded
        )
    }

    func updateUIView(_ view: TimelinePanControl, context: Context) {
        view.isUserInteractionEnabled = isEnabled
        view.update(progress: progress, onChanged: onChanged, onEnded: onEnded)
    }
}

final class TimelinePanControl: UIView {
    private var progress: Double
    private var startProgress = 0.0
    private var onChanged: (Double) -> Void
    private var onEnded: () -> Void

    init(
        progress: Double,
        onChanged: @escaping (Double) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.progress = progress
        self.onChanged = onChanged
        self.onEnded = onEnded
        super.init(frame: .zero)
        backgroundColor = .clear
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(
        progress: Double,
        onChanged: @escaping (Double) -> Void,
        onEnded: @escaping () -> Void
    ) {
        self.progress = progress
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            startProgress = progress
        case .changed:
            guard bounds.width > 0 else { return }
            progress = min(max(startProgress + Double(gesture.translation(in: self).x / bounds.width), 0), 1)
            onChanged(progress)
        case .ended, .cancelled:
            onEnded()
        default:
            break
        }
    }
}
