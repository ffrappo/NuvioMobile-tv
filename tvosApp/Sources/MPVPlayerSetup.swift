import Libmpv
import UIKit

/// MPV bootstrap: layer wiring, instance creation, and the option set that
/// pins tvOS platform ownership (system volume, audio session, Vulkan
/// rendering configuration).
extension MPVPlayerController {
    func configureLayer() {
        metalLayer.contentsGravity = .resize
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(metalLayer)
    }

    func setupMPV() {
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
        // MPV's tvOS AudioUnit backend otherwise adds mixWithOthers when the
        // stream opens. Keep primary movie playback on the system media route.
        setOption(mpv, "audio-exclusive", "yes")
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
                    let parameters = PlayerStreamParameters.read(from: mpv)
                    Task { @MainActor in
                        self.session.update(paused: false, loading: false)
                        self.session.updateStreamParameters(parameters)
                        self.publishPlaybackOptions()
                    }
                case MPV_EVENT_END_FILE:
                    if let data = event.pointee.data {
                        let end = UnsafePointer<mpv_event_end_file>(OpaquePointer(data)).pointee
                        if end.reason == MPV_END_FILE_REASON_ERROR {
                            let text = String(cString: mpv_error_string(end.error))
                            Task { @MainActor in self.session.update(loading: false, error: text) }
                        } else if end.reason == MPV_END_FILE_REASON_EOF {
                            // Natural end: post-play decisions observe this.
                            Task { @MainActor in self.session.markEnded() }
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

    func setOption(_ mpv: OpaquePointer, _ name: String, _ value: String) {
        _ = mpv_set_option_string(mpv, name, value)
    }

    func setOption(_ mpv: OpaquePointer, _ name: String, format: mpv_format, value: inout Int64) {
        _ = mpv_set_option(mpv, name, format, &value)
    }
}
