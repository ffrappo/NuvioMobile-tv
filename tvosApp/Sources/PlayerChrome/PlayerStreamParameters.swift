import Foundation
import Libmpv

/// Video/audio parameters read from MPV after the file loads, feeding the
/// parity stream info overlay (Android `StreamInfoOverlay.kt`).
struct PlayerStreamParameters: Equatable, Sendable {
    var videoCodec: String?
    var videoWidth: Int?
    var videoHeight: Int?
    var videoFrameRate: Double?
    var audioCodec: String?
    var audioChannels: String?

    static func read(from mpv: OpaquePointer) -> PlayerStreamParameters {
        var parameters = PlayerStreamParameters()
        if let format = mpvString(mpv, "video-format") {
            parameters.videoCodec = format
        }
        if let width = mpvInt(mpv, "width") {
            parameters.videoWidth = width
        }
        if let height = mpvInt(mpv, "height") {
            parameters.videoHeight = height
        }
        if let fps = mpvDouble(mpv, "container-fps") {
            parameters.videoFrameRate = fps
        }
        if let codec = mpvString(mpv, "audio-codec-name") {
            parameters.audioCodec = codec
        }
        if let channels = mpvInt(mpv, "audio-params/channel-count") {
            parameters.audioChannels = channels == 1 ? "mono" : channels == 2 ? "stereo" : "\(channels) ch"
        }
        return parameters
    }

    private static func mpvString(_ mpv: OpaquePointer, _ name: String) -> String? {
        guard let cString = mpv_get_property_string(mpv, name) else { return nil }
        defer { mpv_free(cString) }
        let value = String(cString: cString)
        return value.isEmpty ? nil : value
    }

    private static func mpvInt(_ mpv: OpaquePointer, _ name: String) -> Int? {
        var value = Int64(0)
        guard mpv_get_property(mpv, name, MPV_FORMAT_INT64, &value) >= 0 else { return nil }
        return Int(value)
    }

    private static func mpvDouble(_ mpv: OpaquePointer, _ name: String) -> Double? {
        var value = Double(0)
        guard mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &value) >= 0 else { return nil }
        return value
    }
}
