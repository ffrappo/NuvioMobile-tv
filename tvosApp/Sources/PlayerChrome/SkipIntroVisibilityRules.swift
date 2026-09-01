import Foundation

/// Pure port of Android `SkipIntroVisibilityRules.kt` plus the skip label
/// mapping from `SkipIntroButton.kt`. All functions are side-effect free.
enum SkipIntroVisibilityRules {
    /// Android `SKIP_INTRO_AUTO_HIDE_TIMEOUT_MS`.
    static let autoHideTimeoutMs: Int = 10_000

    /// Android `findActiveSkipInterval`: the first interval whose window
    /// contains the position. Window is half-open in seconds
    /// (`startTime <= position < endTime`). The tvOS session reports
    /// positions in seconds, matching `SkipInterval.contains`.
    static func findActiveSkipInterval(
        _ intervals: [SkipInterval],
        positionSeconds: Double
    ) -> SkipInterval? {
        guard !intervals.isEmpty else { return nil }
        return intervals.first { interval in
            positionSeconds >= interval.startTime && positionSeconds < interval.endTime
        }
    }

    /// Android `nextActiveSkipInterval` (identical to findActiveSkipInterval).
    static func nextActiveSkipInterval(
        _ intervals: [SkipInterval],
        positionSeconds: Double
    ) -> SkipInterval? {
        findActiveSkipInterval(intervals, positionSeconds: positionSeconds)
    }

    /// Android `isSkipIntroButtonVisible`: the button shows while an interval
    /// is active; a dismissal or auto-hide is waived while controls are
    /// visible (controls re-reveal the button without restarting the
    /// countdown).
    static func isSkipIntroButtonVisible(
        hasActiveInterval: Bool,
        dismissed: Bool,
        controlsVisible: Bool,
        autoHidden: Bool
    ) -> Bool {
        let shouldShow = hasActiveInterval && (!dismissed || controlsVisible)
        return shouldShow && (!autoHidden || controlsVisible)
    }

    /// Android `isSkipIntroCanFocus`: while the subtitle selection overlay is
    /// open the button stays on screen but must not accept D-pad focus
    /// (Android issue #2874).
    static func isSkipIntroCanFocus(subtitleOverlayVisible: Bool) -> Bool {
        !subtitleOverlayVisible
    }

    /// Android `skipIntroAutoHideRemainingMs`: remaining auto-hide time in
    /// milliseconds for a countdown at `progress` (0...1), clamped to at
    /// least 1 ms so the animation always has a positive duration.
    static func autoHideRemainingMs(
        progress: Double,
        totalTimeoutMs: Int = autoHideTimeoutMs
    ) -> Int {
        let clamped = min(max(progress, 0), 1)
        let remaining = (1 - clamped) * Double(totalTimeoutMs)
        return max(Int(remaining), 1)
    }

    /// Android `getSkipLabel`: label for a skip interval type.
    static func skipLabel(forType type: String?) -> String {
        switch type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "op", "opening", "mixed-op", "intro":
            return "Skip Intro"
        case "ed", "ending", "mixed-ed", "outro", "credits":
            return "Skip Ending"
        case "recap":
            return "Skip Recap"
        default:
            return "Skip"
        }
    }
}
