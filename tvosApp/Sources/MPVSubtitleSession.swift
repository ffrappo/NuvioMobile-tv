import Foundation

@MainActor
extension MPVPlaybackSession {
    func setSubtitleDelay(milliseconds: Int) {
        let clamped = min(max(milliseconds, -60_000), 60_000)
        updateSubtitle(delayMilliseconds: clamped)
        controller?.setSubtitleDelay(milliseconds: clamped)
    }

    func setSubtitleFontSize(_ size: Int) {
        let clamped = min(max(size, 24), 96)
        updateSubtitle(fontSize: clamped)
        controller?.setSubtitleFontSize(clamped)
    }
}
