import SwiftUI

struct PlaybackTimelineScrubber: View {
    let position: Double
    let duration: Double
    let isFocused: Bool
    let onSeek: (Double) -> Void
    let onInteraction: () -> Void

    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false
    @State private var lastExternalPosition = 0.0
    @State private var shouldGlide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stepSeconds = 10.0
    private let pollInterval = 0.5
    private let glideMaxDelta = 2.0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(isFocused ? 0.38 : 0.25))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(.white)
                    .frame(width: width * progress, height: trackHeight)
                if isFocused {
                    Circle()
                        .fill(.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .offset(x: max(0, width * progress - thumbSize / 2))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(
                isScrubbing || !shouldGlide || reduceMotion ? nil : .linear(duration: pollInterval),
                value: scrubPosition
            )
        }
        .frame(height: isFocused ? 34 : 18)
        .focusable(true, interactions: .edit)
        .focusEffectDisabled()
        .onAppear {
            scrubPosition = position
            lastExternalPosition = position
        }
        .onChange(of: position) { _, position in
            let delta = position - lastExternalPosition
            shouldGlide = delta > 0 && delta <= glideMaxDelta
            lastExternalPosition = position
            if !isScrubbing { scrubPosition = position }
        }
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .left:
                scrub(by: -stepSeconds)
            case .right:
                scrub(by: stepSeconds)
            default:
                return
            }
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: scrub(by: stepSeconds)
            case .decrement: scrub(by: -stepSeconds)
            @unknown default: break
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isFocused)
    }

    private var trackHeight: Double { isFocused ? 11 : 7 }
    private var thumbSize: Double { 26 }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(scrubPosition / duration, 0), 1)
    }

    private func scrub(by seconds: Double) {
        guard duration > 0 else { return }
        isScrubbing = true
        shouldGlide = false
        scrubPosition = min(max(scrubPosition + seconds, 0), duration)
        onSeek(scrubPosition)
        onInteraction()
        isScrubbing = false
    }
}
