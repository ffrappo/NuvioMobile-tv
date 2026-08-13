import SwiftUI

struct PlaybackTimelineScrubber: View {
    let position: Double
    let duration: Double
    let isFocused: Bool
    let onPreview: (Double) -> Void
    let onSeek: (Double) -> Void
    let onInteraction: () -> Void

    @State private var scrubPosition = 0.0
    @State private var scrubStart = 0.0
    @State private var isScrubbing = false
    @State private var lastExternalPosition = 0.0
    @State private var shouldGlide = false
    @State private var repeatStartedAt: Date?
    @State private var repeatDirection = 0.0
    @State private var remote = SiriRemoteScrubCoordinator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            configureRemote()
        }
        .onDisappear { remote.setEnabled(false) }
        .onChange(of: isFocused) { _, focused in
            repeatStartedAt = nil
            repeatDirection = 0
            remote.setEnabled(focused)
        }
        .onChange(of: position) { _, position in
            let delta = position - lastExternalPosition
            shouldGlide = delta > 0 && delta <= glideMaxDelta
            lastExternalPosition = position
            if !isScrubbing { scrubPosition = position }
        }
        .onMoveCommand(perform: handleMove)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commitBy(TimelineScrubModel.accessibilityStep)
            case .decrement: commitBy(-TimelineScrubModel.accessibilityStep)
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

    private func configureRemote() {
        remote.onChanged = { translation in
            if !isScrubbing {
                scrubStart = scrubPosition
                isScrubbing = true
                shouldGlide = false
            }
            preview(TimelineScrubModel.position(
                start: scrubStart,
                duration: duration,
                normalizedTranslation: translation
            ))
        }
        remote.onEnded = {
            guard isScrubbing else { return }
            isScrubbing = false
            commit(scrubPosition)
        }
        remote.setEnabled(isFocused)
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        guard isFocused else { return }
        let sign: Double
        switch direction {
        case .left: sign = -1
        case .right: sign = 1
        default:
            repeatStartedAt = nil
            repeatDirection = 0
            return
        }
        if repeatDirection != sign {
            repeatDirection = sign
            repeatStartedAt = Date()
        }
        let elapsed = Date().timeIntervalSince(repeatStartedAt ?? Date())
        let destination = TimelineScrubModel.destination(
            current: scrubPosition,
            duration: duration,
            direction: sign,
            heldFor: elapsed
        )
        commit(destination)
    }

    private func preview(_ destination: Double) {
        scrubPosition = destination
        onPreview(destination)
        onInteraction()
    }

    private func commitBy(_ seconds: Double) {
        commit(min(max(scrubPosition + seconds, 0), duration))
    }

    private func commit(_ destination: Double) {
        scrubPosition = destination
        onPreview(destination)
        onSeek(destination)
        onInteraction()
    }
}
