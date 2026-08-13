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
    private let metalLayer = MPVMetalLayer()
    let eventQueue = DispatchQueue(label: "nuvio.tv.mpv.events", qos: .userInitiated)
    var mpv: OpaquePointer?
    private var progressTimer: Timer?
    private var pendingURL: URL?
    private var pendingStartPosition: Double?
    private var didConfigureAudioSession = false
    private lazy var audioSession = TVAudioSessionCoordinator(
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
    private func applyPendingStartPosition() {
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

    func setSubtitleFontSize(_ size: Int) {
        guard let mpv else { return }
        let clamped = min(max(size, 24), 96)
        var value = Double(clamped)
        mpv_set_property(mpv, "sub-font-size", MPV_FORMAT_DOUBLE, &value)
        Task { @MainActor in session.updateSubtitle(fontSize: clamped) }
    }

    func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        command("stop")
        if didConfigureAudioSession { audioSession.stop() }
    }

    private func configureLayer() {
        metalLayer.contentsGravity = .resize
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(metalLayer)
    }

    private func setupMPV() {
        mpv = mpv_create()
        guard let mpv else {
            Task { @MainActor in session.update(loading: false, error: "Could not initialize the MPV player.") }
            return
        }
        mpv_request_log_messages(mpv, "warn")
        var layerPointer = Int64(Int(bitPattern: Unmanaged.passUnretained(metalLayer).toOpaque()))
        setOption(mpv, "wid", format: MPV_FORMAT_INT64, value: &layerPointer)
        setOption(mpv, "vo", "gpu-next")
        setOption(mpv, "gpu-api", "vulkan")
        setOption(mpv, "gpu-context", "moltenvk")
        setOption(mpv, "hwdec", "videotoolbox")
        setOption(mpv, "ao", "audiounit")
        setOption(mpv, "audio-channels", "auto")
        setOption(mpv, "audio-fallback-to-null", "yes")
        // tvOS owns output volume through the Siri Remote, Control Center,
        // HDMI-CEC, or IR. Keep mpv at unity gain and never expose software
        // amplification as a competing volume layer.
        setOption(mpv, "volume", "100")
        setOption(mpv, "volume-max", "100")
        setOption(mpv, "vulkan-swap-mode", "fifo")
        setOption(mpv, "vulkan-queue-count", "1")
        setOption(mpv, "vulkan-async-compute", "no")
        setOption(mpv, "vulkan-async-transfer", "no")
        setOption(mpv, "vulkan-disable-interop", "yes")
        setOption(mpv, "keep-open", "yes")
        setOption(mpv, "target-colorspace-hint", "yes")
        setOption(mpv, "tone-mapping", "auto")
        setOption(mpv, "hdr-compute-peak", "yes")
        guard mpv_initialize(mpv) >= 0 else {
            Task { @MainActor in session.update(loading: false, error: "MPV initialization failed.") }
            return
        }
        didConfigureAudioSession = true
        audioSession.activate()
        mpv_set_wakeup_callback(mpv, { context in
            guard let context else { return }
            Unmanaged<MPVPlayerController>.fromOpaque(context).takeUnretainedValue().readEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func readEvents() {
        eventQueue.async { [weak self] in
            guard let self, let mpv = self.mpv else { return }
            while true {
                guard let event = mpv_wait_event(mpv, 0), event.pointee.event_id != MPV_EVENT_NONE else { return }
                switch event.pointee.event_id {
                case MPV_EVENT_FILE_LOADED, MPV_EVENT_PLAYBACK_RESTART:
                    self.applyPendingStartPosition()
                    Task { @MainActor in
                        self.session.update(paused: false, loading: false)
                        self.publishPlaybackOptions()
                    }
                case MPV_EVENT_END_FILE:
                    if let data = event.pointee.data {
                        let end = UnsafePointer<mpv_event_end_file>(OpaquePointer(data)).pointee
                        if end.reason == MPV_END_FILE_REASON_ERROR {
                            let text = String(cString: mpv_error_string(end.error))
                            Task { @MainActor in self.session.update(loading: false, error: text) }
                        }
                    }
                default: break
                }
            }
        }
    }

    func command(_ values: String...) {
        guard let mpv else { return }
        var cStrings: [UnsafePointer<CChar>?] = values.map { value in
            guard let pointer = strdup(value) else { return nil }
            return UnsafePointer(pointer)
        }
        cStrings.append(nil)
        defer { cStrings.dropLast().forEach { pointer in
            if let pointer { free(UnsafeMutablePointer(mutating: pointer)) }
        } }
        _ = mpv_command(mpv, &cStrings)
    }

    private func setOption(_ mpv: OpaquePointer, _ name: String, _ value: String) {
        _ = mpv_set_option_string(mpv, name, value)
    }

    private func setOption(_ mpv: OpaquePointer, _ name: String, format: mpv_format, value: inout Int64) {
        _ = mpv_set_option(mpv, name, format, &value)
    }

    deinit {
        progressTimer?.invalidate()
        if let mpv { mpv_terminate_destroy(mpv) }
    }
}
