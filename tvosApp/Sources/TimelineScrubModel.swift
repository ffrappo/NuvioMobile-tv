import Foundation

struct TimelineScrubModel {
    static let accessibilityStep = 10.0
    static let repeatThresholds = [0.0, 0.45, 1.2, 2.4]

    static func destination(
        current: Double,
        duration: Double,
        direction: Double,
        heldFor elapsed: TimeInterval
    ) -> Double {
        guard duration > 0, direction != 0 else { return current }
        let step = repeatedStep(duration: duration, heldFor: elapsed)
        return min(max(current + copysign(step, direction), 0), duration)
    }

    static func repeatedStep(duration: Double, heldFor elapsed: TimeInterval) -> Double {
        let base = max(10, duration / 120)
        switch elapsed {
        case ..<repeatThresholds[1]: return base
        case ..<repeatThresholds[2]: return max(30, duration / 60)
        case ..<repeatThresholds[3]: return max(90, duration / 24)
        default: return max(180, duration / 12)
        }
    }

    static func position(
        start: Double,
        duration: Double,
        normalizedTranslation: Double
    ) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(start + normalizedTranslation * duration, 0), duration)
    }
}
