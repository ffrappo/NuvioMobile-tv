import SwiftUI

struct PlaybackTimelineScrubber: View {
    let position: Double
    let duration: Double
    let isFocused: Bool
    let onSeek: (Double) -> Void

    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false
    @State private var trackExternalUpdates = false
    @State private var lastExternalPosition = 0.0
    @State private var shouldGlide = false

    private let stepSeconds = 10.0
    private let pollInterval: Double = 0.5
    // Maximum position delta treated as normal playback advance. Larger jumps
    // (skip-intro, source switch, resume) snap instantly instead of gliding.
    private let glideMaxDelta: Double = 2.0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(.white)
                    .frame(width: width * progress, height: trackHeight)
                if isFocused {
                    Circle()
                        .fill(.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: max(0, width * progress - thumbSize / 2))
                }
            }
            .frame(maxHeight: .infinity)
            // The session position is polled at 0.5 s intervals. Glide between
            // consecutive samples with a linear tween that matches the poll
            // cadence, so the playhead moves continuously at the display refresh
            // rate instead of ratcheting every 500 ms. Scrubbing, seeks, and
            // discontinuous jumps snap instantly so manual input and skip
            // actions track immediately.
            .animation(
                isScrubbing || !shouldGlide ? nil : .linear(duration: pollInterval),
                value: scrubPosition
            )
        }
        .frame(height: isFocused ? 28 : 14)
        .focusable(false)
        .onAppear {
            scrubPosition = position
            lastExternalPosition = position
        }
        .onChange(of: position) { _, position in
            trackExternalUpdates = true
            let delta = position - lastExternalPosition
            shouldGlide = delta > 0 && delta <= glideMaxDelta
            lastExternalPosition = position
            if !isScrubbing { scrubPosition = position }
        }
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .left: scrub(by: -stepSeconds)
            case .right: scrub(by: stepSeconds)
            default: break
            }
        }
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    private var trackHeight: Double { isFocused ? 10 : 7 }
    private var thumbSize: Double { 24 }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(scrubPosition / duration, 0), 1)
    }

    private func scrub(by seconds: Double) {
        isScrubbing = true
        shouldGlide = false
        scrubPosition = min(max(scrubPosition + seconds, 0), max(duration, 0))
        onSeek(scrubPosition)
        isScrubbing = false
    }
}
