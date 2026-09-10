import SwiftUI
import UIKit

struct PlaybackTimelineScrubber: View {
    let position: Double
    let duration: Double
    let isFocused: Bool
    let onSeek: (Double) -> Void
    let onInteraction: () -> Void

    @State private var preview = 0.0
    @State private var pending: Double?
    @State private var commitTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(isFocused ? 0.42 : 0.28))
                Capsule().fill(.white).frame(width: proxy.size.width * progress)
                if isFocused {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                        .offset(x: max(0, proxy.size.width * progress - 11))
                }
                TimelinePanControl(
                    progress: progress * 100,
                    enabled: duration > 0,
                    onChanged: { updatePreview(progress: $0 / 100) },
                    onEnded: scheduleCommit,
                    onStep: { updatePreview(by: Double($0) * step); scheduleCommit() }
                )
            }
        }
        .frame(height: isFocused ? 24 : 10)
        .onAppear { preview = position }
        .onDisappear { commitTask?.cancel() }
        .onChange(of: position) { _, value in receivePlayerPosition(value) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playback Position")
        .accessibilityValue(PlayerTimeFormatter.string(preview))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commitImmediately(preview + 10)
            case .decrement: commitImmediately(preview - 10)
            @unknown default: break
            }
        }
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: preview)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isFocused)
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(preview / duration, 0), 1)
    }

    private var step: Double { min(max(duration / 100, 15), 90) }

    private func updatePreview(progress: Double) {
        updatePreview(to: progress * duration)
    }

    private func updatePreview(by seconds: Double) {
        updatePreview(to: preview + seconds)
    }

    private func updatePreview(to value: Double) {
        commitTask?.cancel()
        preview = min(max(value, 0), duration)
        pending = preview
        onInteraction()
    }

    private func scheduleCommit() {
        guard let destination = pending else { return }
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            onSeek(destination)
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            pending = nil
            commitTask = nil
        }
    }

    private func receivePlayerPosition(_ value: Double) {
        if let pending {
            if abs(value - pending) <= 2 {
                self.pending = nil
                commitTask?.cancel()
                commitTask = nil
                preview = value
            }
        } else {
            preview = value
        }
    }

    private func commitImmediately(_ value: Double) {
        updatePreview(to: value)
        onSeek(preview)
        pending = nil
        commitTask = nil
    }
}

private struct TimelinePanControl: UIViewRepresentable {
    let progress: Double
    let enabled: Bool
    let onChanged: (Double) -> Void
    let onEnded: () -> Void
    let onStep: (Int) -> Void

    func makeUIView(context: Context) -> TimelinePanView {
        TimelinePanView(progress: progress, callbacks: callbacks)
    }

    func updateUIView(_ view: TimelinePanView, context: Context) {
        view.isEnabled = enabled
        view.update(progress: progress, callbacks: callbacks)
    }

    private var callbacks: TimelinePanView.Callbacks {
        .init(changed: onChanged, ended: onEnded, step: onStep)
    }
}

private final class TimelinePanView: UIControl {
    struct Callbacks {
        let changed: (Double) -> Void
        let ended: () -> Void
        let step: (Int) -> Void
    }

    private let damping: CGFloat = 200
    private var progress: Double
    private var startProgress = 0.0
    private var callbacks: Callbacks
    private var isPanning = false

    override var canBecomeFocused: Bool { isEnabled }

    init(progress: Double, callbacks: Callbacks) {
        self.progress = progress
        self.callbacks = callbacks
        super.init(frame: .zero)
        backgroundColor = .clear
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(progress: Double, callbacks: Callbacks) {
        if !isPanning { self.progress = progress }
        self.callbacks = callbacks
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isPanning = true
            startProgress = progress
        case .changed:
            progress = min(max(startProgress + Double(gesture.translation(in: self).x / damping), 0), 100)
            callbacks.changed(progress)
        case .ended, .cancelled:
            isPanning = false
            callbacks.ended()
        default: break
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let type = presses.first?.type else { return super.pressesEnded(presses, with: event) }
        if type == .leftArrow { callbacks.step(-1) }
        else if type == .rightArrow { callbacks.step(1) }
        else { super.pressesEnded(presses, with: event) }
    }
}
