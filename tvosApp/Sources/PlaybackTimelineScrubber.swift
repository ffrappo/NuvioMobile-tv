import SwiftUI

struct PlaybackTimelineScrubber: View {
    let position: Double
    let duration: Double
    let isFocused: Bool
    let onPreview: (Double) -> Void
    let onSeek: (Double) -> Void
    let onInteraction: () -> Void

    @State private var previewPosition = 0.0
    @State private var isScrubbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(isFocused ? 0.38 : 0.25))
                    .frame(height: isFocused ? 11 : 7)
                Capsule()
                    .fill(.white)
                    .frame(width: proxy.size.width * progress, height: isFocused ? 11 : 7)
                if isFocused {
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .offset(x: max(0, proxy.size.width * progress - 13))
                }
                TVTimelinePanControl(
                    progress: progress,
                    isEnabled: isFocused,
                    onChanged: preview,
                    onEnded: commitPreview
                )
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: isFocused ? 34 : 18)
        .focusable(true, interactions: .edit)
        .focusEffectDisabled()
        .onAppear { previewPosition = position }
        .onChange(of: position) { _, value in
            if !isScrubbing { previewPosition = value }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left: commit(previewPosition - 10)
            case .right: commit(previewPosition + 10)
            default: break
            }
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(previewPosition + 10)
            case .decrement: commit(previewPosition - 10)
            @unknown default: break
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isFocused)
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(previewPosition / duration, 0), 1)
    }

    private func preview(_ progress: Double) {
        guard duration > 0 else { return }
        isScrubbing = true
        previewPosition = progress * duration
        onPreview(previewPosition)
        onInteraction()
    }

    private func commitPreview() {
        guard isScrubbing else { return }
        isScrubbing = false
        commit(previewPosition)
    }

    private func commit(_ position: Double) {
        let clamped = min(max(position, 0), duration)
        previewPosition = clamped
        onPreview(clamped)
        onSeek(clamped)
        onInteraction()
    }
}
