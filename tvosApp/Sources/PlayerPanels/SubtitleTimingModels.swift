import Foundation

/// One subtitle cue used by the sync-by-line timing dialog, port of Android
/// `SubtitleSyncCue`.
struct SubtitleSyncCue: Equatable, Identifiable {
    let startTimeMs: Int
    let endTimeMs: Int
    let text: String

    /// Port of `subtitleCueListItemKey`.
    var id: String { "\(startTimeMs):\(endTimeMs):\(text.hashValue)" }

    init(startTimeMs: Int, endTimeMs: Int, text: String) {
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.text = text
    }
}

/// Delay bounds ported from `SubtitleDelayConfig.kt`.
enum SubtitleDelayRange {
    static let minMilliseconds = -180_000
    static let maxMilliseconds = 180_000
    static let stepMilliseconds = 100
    static let overlayTimeoutMilliseconds: Int = 20_000

    static func clamp(_ milliseconds: Int) -> Int {
        min(max(milliseconds, minMilliseconds), maxMilliseconds)
    }
}

/// Presentation state for the subtitle timing dialog: the current delay plus
/// the auto-sync (sync-by-line) session state from
/// `PlayerRuntimeControllerSubtitleTiming.kt`.
struct SubtitleTimingDialogState: Equatable {
    enum Stage: Equatable {
        /// Waiting for the user to capture the current playback position.
        case waitForSync
        /// A position was captured; the user picks the matching cue line.
        case pickLine
    }

    var delayMilliseconds: Int = 0
    var stage: Stage = .waitForSync
    var capturedVideoMs: Int?
    var statusMessage: String?
    var errorMessage: String?
    var isLoadingCues = false
    var selectedExternalTrackID: String?
    var cues: [SubtitleSyncCue] = []

    init(delayMilliseconds: Int = 0) {
        self.delayMilliseconds = SubtitleDelayRange.clamp(delayMilliseconds)
    }

    /// Adjusts the delay by a delta in milliseconds and clamps to the Android
    /// range (`OnAdjustSubtitleDelay`).
    mutating func adjustDelay(byMilliseconds delta: Int) {
        delayMilliseconds = SubtitleDelayRange.clamp(delayMilliseconds + delta)
    }

    /// One stepper step later (`OnAdjustSubtitleDelay(+STEP_MS)`).
    mutating func incrementDelay() {
        adjustDelay(byMilliseconds: SubtitleDelayRange.stepMilliseconds)
    }

    /// One stepper step earlier (`OnAdjustSubtitleDelay(-STEP_MS)`).
    mutating func decrementDelay() {
        adjustDelay(byMilliseconds: -SubtitleDelayRange.stepMilliseconds)
    }

    /// `OnResetSubtitleDelay`.
    mutating func resetDelay() {
        delayMilliseconds = 0
    }

    /// `captureSubtitleAutoSyncTime`.
    mutating func captureSyncTime(atPlaybackPositionMs positionMs: Int) {
        capturedVideoMs = max(0, positionMs)
        statusMessage = nil
        errorMessage = nil
        stage = .pickLine
    }

    /// `applySubtitleAutoSyncCue`: computes the delay that aligns the selected
    /// cue with the captured position (minus the 300 ms reaction-time
    /// compensation), clamps it, and closes the pick-line stage.
    @discardableResult
    mutating func applySyncCue(_ cue: SubtitleSyncCue) -> Int {
        let captured = capturedVideoMs ?? 0
        let newDelay = SubtitleTimingMath.autoSyncDelay(
            capturedPositionMs: captured,
            cueStartMs: cue.startTimeMs
        )
        delayMilliseconds = newDelay
        stage = .waitForSync
        return newDelay
    }
}

/// Pure timing math ported from `PlayerRuntimeControllerSubtitleTiming.kt`,
/// `SubtitleTimingDialog.kt`, and the delay overlay in `PlayerScreen.kt`.
enum SubtitleTimingMath {
    /// `AUTO_SYNC_REACTION_COMPENSATION_MS`.
    static let autoSyncReactionCompensationMs = 300

    /// Delay that aligns `cueStartMs` with the captured playback position:
    /// `(capture - cueStart - 300ms)` clamped to the delay range.
    static func autoSyncDelay(capturedPositionMs: Int, cueStartMs: Int) -> Int {
        SubtitleDelayRange.clamp(
            capturedPositionMs - cueStartMs - autoSyncReactionCompensationMs
        )
    }

    /// Port of `selectAutoSyncVisibleCues`: cues within ±`marginMs` of the
    /// anchor, capped to `maxVisible` centered on the cue nearest the anchor;
    /// when the window is empty, the cues nearest the anchor are used.
    static func visibleCues(
        _ cues: [SubtitleSyncCue],
        anchorTimeMs: Int,
        marginMs: Int = 180_000,
        maxVisible: Int = 90
    ) -> [SubtitleSyncCue] {
        if cues.isEmpty { return [] }
        let sorted = cues.sorted { $0.startTimeMs < $1.startTimeMs }
        let lower = max(anchorTimeMs - marginMs, 0)
        let upper = anchorTimeMs + marginMs
        let inWindow = sorted.filter { $0.startTimeMs >= lower && $0.startTimeMs <= upper }
        if !inWindow.isEmpty {
            if inWindow.count <= maxVisible { return inWindow }
            let centerIndex = nearestIndex(inWindow, to: anchorTimeMs)
            return takeCentered(inWindow, centerIndex: centerIndex, maxVisible: maxVisible)
        }
        let nearestIndex = nearestIndex(sorted, to: anchorTimeMs)
        return takeCentered(sorted, centerIndex: nearestIndex, maxVisible: maxVisible)
    }

    private static func nearestIndex(_ cues: [SubtitleSyncCue], to anchorTimeMs: Int) -> Int {
        cues.indices.min(by: {
            abs(cues[$0].startTimeMs - anchorTimeMs) < abs(cues[$1].startTimeMs - anchorTimeMs)
        }) ?? 0
    }

    private static func takeCentered(
        _ items: [SubtitleSyncCue],
        centerIndex: Int,
        maxVisible: Int
    ) -> [SubtitleSyncCue] {
        if items.count <= maxVisible { return items }
        let half = maxVisible / 2
        var start = max(centerIndex - half, 0)
        let end = min(start + maxVisible, items.count)
        if end - start < maxVisible {
            start = max(end - maxVisible, 0)
        }
        return Array(items[start..<end])
    }

    /// Port of `formatAutoSyncTimestamp`: `m:ss` or `h:mm:ss`.
    static func timestamp(_ positionMs: Int) -> String {
        let totalSeconds = max(positionMs / 1_000, 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Port of `formatSubtitleDelay` (delay overlay): `+1500ms` / `-250ms` / `0ms`.
    static func delayMillisecondsLabel(_ delayMs: Int) -> String {
        switch delayMs {
        case ..<0: return "\(delayMs)ms"
        case 1...: return "+\(delayMs)ms"
        default: return "0ms"
        }
    }

    /// Port of `formatAutoSyncDelay` (auto-sync status): `+1.500s` / `-0.250s`.
    static func delaySecondsLabel(_ delayMs: Int) -> String {
        let sign = delayMs >= 0 ? "+" : "-"
        let absMs = abs(delayMs)
        return String(format: "%@%d.%03ds", sign, absMs / 1_000, absMs % 1_000)
    }

    /// Port of `sanitizeCuePreviewText`: strips ASS override tags and line
    /// breaks so a cue renders as a single preview line.
    static func sanitizedCuePreviewText(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(
                of: #"\{\\[^{}]*\}"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\N", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }
}

/// SDH text filter ported from `SubtitleSdhFilter.kt`: removes sound
/// descriptions (square brackets, parentheses), speaker chevrons, and speaker
/// labels from caption text.
enum SubtitleSdhTextFilter {
    private static let speakerChevrons = try! NSRegularExpression(pattern: "[<>]{2,}[ \t]*")
    private static let speakerLabel = try! NSRegularExpression(
        pattern: "(?m)^([ \\t]*-[ \\t]*)?(?:[A-Za-z0-9 ()'#.,]+|\\[[^]\\r\\n]*]):(?=\\s|$)[ \\t]*"
    )
    private static let squareBrackets = try! NSRegularExpression(pattern: "\\[[^]]*][ \t]*")
    private static let parentheses = try! NSRegularExpression(
        pattern: "(?:\\((?=[A-Za-z0-9 '#.,\\\"\\\\\\-\\r\\n]*\\))(?![0-9]*\\))[^)]*\\)|"
            + "\u{FF08}(?=[A-Za-z0-9 '#.,\\\"\\\\\\-\\r\\n]*\u{FF09})(?![0-9]*\u{FF09})[^\u{FF09}]*\u{FF09})[ \t]*"
    )

    /// Port of `filterPlainText`: returns nil when the whole cue is SDH
    /// annotation and nothing readable remains.
    static func filterPlainText(_ text: String) -> String? {
        var filtered = replace(speakerChevrons, in: text, with: "")
        filtered = replace(speakerLabel, in: filtered, with: "$1")
        filtered = replace(squareBrackets, in: filtered, with: "")
        filtered = replace(parentheses, in: filtered, with: "")
        let keptLines = filtered
            .components(separatedBy: .newlines)
            .filter { line in line.contains { !$0.isWhitespace && $0 != "-" } }
        let joined = keptLines.joined(separator: "\n")
        return joined.isBlank ? nil : joined
    }

    /// Cue-level filter used for previews: keeps the original text when the
    /// filter would remove everything.
    static func filterCueText(_ text: String) -> String {
        filterPlainText(text) ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The cue list the timing dialog shows, with SDH annotations removed
    /// from the preview text when the filter is enabled. The Android filter
    /// runs on rendered cues; this applies the same rules to the visible
    /// sync-by-line list.
    static func visibleCues(
        _ cues: [SubtitleSyncCue],
        stripSdh: Bool
    ) -> [SubtitleSyncCue] {
        guard stripSdh else { return cues }
        return cues.map { cue in
            SubtitleSyncCue(
                startTimeMs: cue.startTimeMs,
                endTimeMs: cue.endTimeMs,
                text: filterCueText(cue.text)
            )
        }
    }

    private static func replace(
        _ expression: NSRegularExpression,
        in text: String,
        with template: String
    ) -> String {
        expression.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}

private extension String {
    var isBlank: Bool { allSatisfy(\.isWhitespace) }
}
