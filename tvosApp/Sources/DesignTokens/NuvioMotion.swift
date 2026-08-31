import SwiftUI

public struct NuvioEasingCurve: Equatable, Sendable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    public func animation(duration: TimeInterval) -> Animation {
        .timingCurve(x1, y1, x2, y2, duration: duration)
    }
}

public enum NuvioMotionTransition: CaseIterable, Hashable, Sendable {
    case quick
    case focus
    case content
    case overlay
    case hero
    case shimmer
}

public enum NuvioReducedMotionSubstitute: Sendable {
    case instant
    case crossFade
}

public enum NuvioMotion {
    public static let instant: TimeInterval = 0
    public static let quickTransition: TimeInterval = 0.125
    public static let focusTransition: TimeInterval = 0.18
    public static let contentTransition: TimeInterval = 0.35
    public static let overlayTransition: TimeInterval = 0.4
    public static let heroTransition: TimeInterval = 0.45
    public static let shimmerCycle: TimeInterval = 1.2
    public static let crossFadeTransition: TimeInterval = 0.18

    public static let sidebarLabelIn: TimeInterval = 0.125
    public static let sidebarLabelOut: TimeInterval = 0.145
    public static let sidebarPanelIn: TimeInterval = 0.345
    public static let sidebarPanelOut: TimeInterval = 0.385
    public static let sidebarBloomOut: TimeInterval = 0.395
    public static let sidebarEnter: TimeInterval = 0.385
    public static let sidebarExit: TimeInterval = 0.145

    /// Compose FastOutSlowInEasing: cubic-bezier(0.4, 0, 0.2, 1).
    public static let standardEasing = NuvioEasingCurve(
        x1: 0.4,
        y1: 0,
        x2: 0.2,
        y2: 1
    )
    public static let emphasizedEasing = NuvioEasingCurve(
        x1: 0.2,
        y1: 0,
        x2: 0,
        y2: 1
    )
    public static let decelerateEasing = NuvioEasingCurve(
        x1: 0,
        y1: 0,
        x2: 0.2,
        y2: 1
    )
    public static let accelerateEasing = NuvioEasingCurve(
        x1: 0.4,
        y1: 0,
        x2: 1,
        y2: 1
    )

    public static func duration(for transition: NuvioMotionTransition) -> TimeInterval {
        switch transition {
        case .quick: quickTransition
        case .focus: focusTransition
        case .content: contentTransition
        case .overlay: overlayTransition
        case .hero: heroTransition
        case .shimmer: shimmerCycle
        }
    }

    public static func resolvedDuration(
        for transition: NuvioMotionTransition,
        reduceMotion: Bool,
        substitute: NuvioReducedMotionSubstitute = .instant
    ) -> TimeInterval {
        guard reduceMotion else { return duration(for: transition) }
        switch substitute {
        case .instant: return instant
        case .crossFade: return crossFadeTransition
        }
    }

    public static func animation(
        for transition: NuvioMotionTransition,
        reduceMotion: Bool,
        substitute: NuvioReducedMotionSubstitute = .instant
    ) -> Animation? {
        let resolved = resolvedDuration(
            for: transition,
            reduceMotion: reduceMotion,
            substitute: substitute
        )
        guard resolved > 0 else { return nil }
        if reduceMotion {
            return decelerateEasing.animation(duration: resolved)
        }
        return standardEasing.animation(duration: resolved)
    }
}
