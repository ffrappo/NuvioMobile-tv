import Foundation
import UIKit

@MainActor
final class MPVPlaybackSession: ObservableObject {
    @Published private(set) var isPaused = false
    @Published private(set) var isLoading = true
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var speed: Double = 1
    @Published private(set) var resizeMode: PlayerResizeMode = .fit
    @Published private(set) var audioTracks: [PlaybackTrack] = []
    @Published private(set) var subtitleTracks: [PlaybackTrack] = []
    @Published private(set) var subtitleDelayMilliseconds = 0
    @Published private(set) var subtitleFontSize = 52
    @Published private(set) var errorMessage: String?
    @Published private(set) var activeSourceName = ""
    @Published private(set) var streamParameters = PlayerStreamParameters()

    func updateStreamParameters(_ parameters: PlayerStreamParameters) {
        streamParameters = parameters
    }
    @Published private(set) var isEnded = false
    var onControlPress: (() -> Void)?

    weak var controller: MPVPlayerController?

    func toggle() {
        controller?.togglePlayback()
    }

    func play() { controller?.setPaused(false) }
    func pause() { controller?.setPaused(true) }

    func load(
        url: URL,
        startPosition: Double? = nil,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String] = [:]
    ) {
        controller?.load(
            url: url,
            startPosition: startPosition,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders
        )
    }
    func seek(by seconds: Double) { controller?.seek(by: seconds) }
    func seek(to seconds: Double) { controller?.seek(to: seconds) }
    func setSpeed(_ speed: Double) { controller?.setSpeed(speed) }
    func setResizeMode(_ mode: PlayerResizeMode) { controller?.setResizeMode(mode) }
    func selectAudio(id: Int64) { controller?.selectAudio(id: id) }
    func selectSubtitle(id: Int64?) { controller?.selectSubtitle(id: id) }
    func setSubtitleDelay(milliseconds: Int) {
        controller?.setSubtitleDelay(milliseconds: milliseconds)
    }
    func setSubtitleFontSize(_ size: Int) { controller?.setSubtitleFontSize(size) }

    /// Adds an external subtitle (addon-provided) and selects it
    /// (Android `selectExternalSubtitle`, MPV `sub-add <url> select`).
    func addExternalSubtitle(url: String, title: String, language: String) {
        controller?.addExternalSubtitle(url: url, title: title, language: language)
    }

    /// Applies the parity subtitle style (Android `SubtitleStyleOptions`)
    /// through the controller; named distinctly to avoid colliding with the
    /// session facade below.
    func controllerApplySubtitleStyle(_ style: SubtitleStyleOptions) {
        controller?.applySubtitleStyle(style)
    }
    func updateActiveSourceName(_ name: String) { activeSourceName = name }
    func switchSource(url: URL) { controller?.load(url: url) }
    func stop() { controller?.stop() }

    func beginLoading() {
        isLoading = true
        errorMessage = nil
        audioTracks = []
        subtitleTracks = []
    }

    /// Equality-guarded writes so a 0.5 s polling tick only invalidates the
    /// session when something actually changed. `@Published` has no built-in
    /// equality check, so unconditional assignments would re-render every
    /// observing view (overlay, menus, and now-playing mirror) on every tick
    /// even when the values are identical.
    func update(paused: Bool? = nil, loading: Bool? = nil, error: String? = nil) {
        if let paused, paused != isPaused { isPaused = paused }
        if let loading, loading != isLoading { isLoading = loading }
        if let error, error != errorMessage { errorMessage = error }
    }

    /// Playback reached EOF: post-play takes over from the controls.
    func markEnded() {
        isEnded = true
    }

    /// Replay flows clear the ended flag.
    func clearEnded() {
        isEnded = false
    }

    func update(position: Double, duration: Double) {
        if position != self.position { self.position = position }
        if duration != self.duration { self.duration = duration }
    }

    func updateSubtitle(delayMilliseconds: Int? = nil, fontSize: Int? = nil) {
        if let delayMilliseconds, delayMilliseconds != subtitleDelayMilliseconds {
            subtitleDelayMilliseconds = delayMilliseconds
        }
        if let fontSize, fontSize != subtitleFontSize {
            subtitleFontSize = fontSize
        }
    }

    func update(
        speed: Double,
        resizeMode: PlayerResizeMode? = nil,
        audioTracks: [PlaybackTrack]? = nil,
        subtitleTracks: [PlaybackTrack]? = nil
    ) {
        if speed != self.speed { self.speed = speed }
        if let resizeMode, resizeMode != self.resizeMode { self.resizeMode = resizeMode }
        if let audioTracks, audioTracks != self.audioTracks { self.audioTracks = audioTracks }
        if let subtitleTracks, subtitleTracks != self.subtitleTracks { self.subtitleTracks = subtitleTracks }
    }

    func updateTrackSelection(audioID: Int64? = nil, subtitleID: Int64? = nil, subtitlesOff: Bool = false) {
        if let audioID {
            audioTracks = audioTracks.map { track in
                PlaybackTrack(
                    id: track.id,
                    kind: track.kind,
                    title: track.title,
                    language: track.language,
                    isSelected: track.id == audioID
                )
            }
        }
        if subtitlesOff || subtitleID != nil {
            subtitleTracks = subtitleTracks.map { track in
                PlaybackTrack(
                    id: track.id,
                    kind: track.kind,
                    title: track.title,
                    language: track.language,
                    isSelected: !subtitlesOff && track.id == subtitleID
                )
            }
        }
    }

#if DEBUG
    func mockForAudit(duration: Double = 3600, position: Double = 1240, isPaused: Bool = false) {
        self.duration = duration
        self.position = position
        self.isPaused = isPaused
        self.isLoading = false
        self.errorMessage = nil
        self.activeSourceName = "1080p HEVC • Torrentio"
        self.audioTracks = [
            PlaybackTrack(id: 1, kind: .audio, title: "English (Original)", language: "eng", isSelected: true),
            PlaybackTrack(id: 2, kind: .audio, title: "Spanish (Doblaje)", language: "spa", isSelected: false),
            PlaybackTrack(id: 3, kind: .audio, title: "Italian (Doppiaggio)", language: "ita", isSelected: false)
        ]
        self.subtitleTracks = [
            PlaybackTrack(id: 1, kind: .subtitle, title: "English [CC]", language: "eng", isSelected: true),
            PlaybackTrack(id: 2, kind: .subtitle, title: "Spanish", language: "spa", isSelected: false),
            PlaybackTrack(id: 3, kind: .subtitle, title: "Italian", language: "ita", isSelected: false),
            PlaybackTrack(id: 4, kind: .subtitle, title: "French", language: "fra", isSelected: false)
        ]
        self.streamParameters = PlayerStreamParameters(
            videoCodec: "hevc",
            videoWidth: 1920,
            videoHeight: 1080,
            videoFrameRate: 23.976,
            audioCodec: "eac3",
            audioChannels: "5.1"
        )
    }
#endif
}
