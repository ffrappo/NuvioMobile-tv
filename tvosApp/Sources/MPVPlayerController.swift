import AVFoundation
import Libmpv
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

    fileprivate weak var controller: MPVPlayerController?

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
        resizeMode: PlayerResizeMode,
        audioTracks: [PlaybackTrack],
        subtitleTracks: [PlaybackTrack]
    ) {
        if speed != self.speed { self.speed = speed }
        if resizeMode != self.resizeMode { self.resizeMode = resizeMode }
        if audioTracks != self.audioTracks { self.audioTracks = audioTracks }
        if subtitleTracks != self.subtitleTracks { self.subtitleTracks = subtitleTracks }
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
}

final class MPVPlayerController: UIViewController {
    let session: MPVPlaybackSession
    let metalLayer = MPVMetalLayer()
    let eventQueue = DispatchQueue(label: "nuvio.tv.mpv.events", qos: .userInitiated)
    var mpv: OpaquePointer?
    private var progressTimer: Timer?
    private var pendingURL: URL?
    private var pendingStartPosition: Double?
    var didConfigureAudioSession = false
    lazy var audioSession = TVAudioSessionCoordinator(
        isPlaying: { [weak self] in !(self?.session.isPaused ?? true) },
        pause: { [weak self] in self?.setPaused(true) },
        resume: { [weak self] in self?.setPaused(false) }
    )

    init(session: MPVPlaybackSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
        session.controller = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureLayer()
        setupMPV()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.scheduleProgressPoll()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        metalLayer.frame = view.bounds
        metalLayer.drawableSize = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        CATransaction.commit()
        if let url = pendingURL, view.window != nil, view.bounds.width > 1 {
            pendingURL = nil
            command("loadfile", url.absoluteString, "replace")
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let wakesControls = presses.contains { press in
            switch press.type {
            case .upArrow, .downArrow, .leftArrow, .rightArrow, .select, .playPause:
                return true
            default:
                return false
            }
        }
        if wakesControls { session.onControlPress?() }
        super.pressesBegan(presses, with: event)
    }

    func load(
        url: URL,
        startPosition: Double? = nil,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String] = [:]
    ) {
        applyRequestHeaders(requestHeaders, responseHeaders: responseHeaders)
        pendingStartPosition = startPosition
        Task { @MainActor in
            session.beginLoading()
        }
        if view.window == nil || view.bounds.width <= 1 {
            pendingURL = url
        } else {
            command("loadfile", url.absoluteString, "replace")
        }
    }

    func setSubtitleDelay(milliseconds: Int) {
        guard let mpv else { return }
        let clamped = min(max(milliseconds, -60_000), 60_000)
        var seconds = Double(clamped) / 1_000
        mpv_set_property(mpv, "sub-delay", MPV_FORMAT_DOUBLE, &seconds)
        Task { @MainActor in session.updateSubtitle(delayMilliseconds: clamped) }
    }
    func applyPendingStartPosition() {
        guard let position = pendingStartPosition, position > 0 else { return }
        pendingStartPosition = nil
        command("seek", String(position), "absolute+exact")
    }

    func togglePlayback() {
        setPaused(!session.isPaused)
    }

    func setPaused(_ paused: Bool) {
        guard let mpv else { return }
        var value: Int32 = paused ? 1 : 0
        mpv_set_property(mpv, "pause", MPV_FORMAT_FLAG, &value)
        Task { @MainActor in session.update(paused: paused) }
    }

    func seek(by seconds: Double) {
        command("seek", String(seconds), "relative+exact")
    }

    func seek(to seconds: Double) {
        command("seek", String(seconds), "absolute+exact")
    }

    func setSpeed(_ speed: Double) {
        guard let mpv else { return }
        var value = speed
        mpv_set_property(mpv, "speed", MPV_FORMAT_DOUBLE, &value)
        publishPlaybackOptions()
    }

    func setResizeMode(_ mode: PlayerResizeMode) {
        guard let mpv else { return }
        switch mode {
        case .fit:
            mpv_set_property_string(mpv, "panscan", "0")
            mpv_set_property_string(mpv, "video-unscaled", "no")
        case .fill:
            mpv_set_property_string(mpv, "panscan", "1")
            mpv_set_property_string(mpv, "video-unscaled", "no")
        case .original:
            mpv_set_property_string(mpv, "panscan", "0")
            mpv_set_property_string(mpv, "video-unscaled", "downscale-big")
        }
        publishPlaybackOptions(resizeMode: mode)
    }

    func selectAudio(id: Int64) {
        guard let mpv else { return }
        var value = id
        mpv_set_property(mpv, "aid", MPV_FORMAT_INT64, &value)
        Task { @MainActor in session.updateTrackSelection(audioID: id) }
    }

    func selectSubtitle(id: Int64?) {
        guard let mpv else { return }
        if var value = id {
            mpv_set_property(mpv, "sid", MPV_FORMAT_INT64, &value)
        } else {
            mpv_set_property_string(mpv, "sid", "no")
        }
        Task { @MainActor in
            session.updateTrackSelection(subtitleID: id, subtitlesOff: id == nil)
        }
    }

    func addExternalSubtitle(url: String, title: String, language: String) {
        command("sub-add", url, "cached", title, language)
        guard let mpv else { return }
        setOption(mpv, "sub-visibility", "yes")
    }

    func setSubtitleFontSize(_ size: Int) {
        guard let mpv else { return }
        let clamped = min(max(size, 24), 96)
        var value = Double(clamped)
        mpv_set_property(mpv, "sub-font-size", MPV_FORMAT_DOUBLE, &value)
        Task { @MainActor in session.updateSubtitle(fontSize: clamped) }
    }

    /// ARGB packed color -> MPV "#AARRGGBB" string.
    private static func mpvColor(_ argb: UInt32) -> String {
        String(format: "#%08X", argb)
    }

    /// Android `NuvioMpvSurfaceView.applySubtitleStyle`: scale, geometry,
    /// border style, colors, and the SDH filter, property for property.
    func applySubtitleStyle(_ style: SubtitleStyleOptions) {
        guard let mpv else { return }
        var scale = min(max(Double(style.sizePercent) / 100.0, 0.5), 3.0)
        let offsetRange = SubtitleStyleOptions.verticalOffsetRange
        let clampedOffset = min(
            max(style.verticalOffset, offsetRange.lowerBound),
            offsetRange.upperBound
        )
        let normalized = Double(clampedOffset - offsetRange.lowerBound)
            / Double(offsetRange.upperBound - offsetRange.lowerBound)
        // MPV_SUB_POS_AT_BOTTOM 103.4 .. MPV_SUB_POS_AT_TOP 72.4.
        var subPos = 103.4 - normalized * (103.4 - 72.4)
        // MPV_SUB_MARGIN_Y_MIN 0 .. MAX 60.
        var subMarginY: Int64 = Int64(normalized * 60)
        let outlineSize: Double = style.outlineEnabled
            ? Double(min(max(style.outlineWidth, 1), 6))
            : 0
        let backgroundAlpha = Int((style.backgroundColorARGB >> 24) & 0xFF)
        let borderStyle = backgroundAlpha > 0 ? "background-box" : "outline-and-shadow"
        // In background-box mode sub-shadow-offset is the box padding.
        var shadowOffset: Double = backgroundAlpha > 0 ? 5.0 : 0.0

        mpv_set_property(mpv, "sub-scale", MPV_FORMAT_DOUBLE, &scale)
        mpv_set_property(mpv, "sub-pos", MPV_FORMAT_DOUBLE, &subPos)
        mpv_set_property(mpv, "sub-margin-y", MPV_FORMAT_INT64, &subMarginY)
        mpv_set_property(mpv, "sub-shadow-offset", MPV_FORMAT_DOUBLE, &shadowOffset)
        mpv_set_property_string(mpv, "sub-bold", style.bold ? "yes" : "no")
        mpv_set_property_string(mpv, "sub-outline-size", String(Int(outlineSize)))
        mpv_set_property_string(mpv, "sub-border-style", borderStyle)
        mpv_set_property_string(mpv, "sub-color", Self.mpvColor(style.textColorARGB))
        mpv_set_property_string(mpv, "sub-back-color", Self.mpvColor(style.backgroundColorARGB))
        mpv_set_property_string(mpv, "sub-outline-color", Self.mpvColor(style.outlineColorARGB))
        mpv_set_property_string(mpv, "sub-filter-sdh", style.stripSdh ? "yes" : "no")
        mpv_set_property_string(mpv, "sub-filter-sdh-harder", style.stripSdh ? "yes" : "no")
    }

    func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        command("stop")
        if didConfigureAudioSession { audioSession.stop() }
    }


    deinit {
        progressTimer?.invalidate()
        if let mpv { mpv_terminate_destroy(mpv) }
    }
}
