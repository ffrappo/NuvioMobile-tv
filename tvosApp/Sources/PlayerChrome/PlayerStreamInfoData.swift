import Foundation

/// Technical stream readout mirroring Android `StreamInfoData`
/// (PlayerUiState.kt). Presentation-only: the integrator fills it from its
/// player/session; the stream info overlay renders it.
struct PlayerStreamInfoData: Equatable, Sendable {
    // Stream source
    var addonName: String?
    var addonLogoURL: URL?
    var streamName: String?
    var streamDescription: String?
    // File info
    var filename: String?
    var fileSize: Int64?
    // Video
    var videoCodec: String?
    var videoWidth: Int?
    var videoHeight: Int?
    var videoFrameRate: Double?
    var videoBitrate: Int?
    var fileBitrate: Int?
    // Audio
    var audioCodec: String?
    var audioChannels: String?
    var audioSampleRate: Int?
    var audioLanguage: String?
    // Subtitle
    var subtitleName: String?
    var subtitleCodec: String?
    var subtitleLanguage: String?
    var subtitleSource: String?
    var playerEngine: String?

    init(
        addonName: String? = nil,
        addonLogoURL: URL? = nil,
        streamName: String? = nil,
        streamDescription: String? = nil,
        filename: String? = nil,
        fileSize: Int64? = nil,
        videoCodec: String? = nil,
        videoWidth: Int? = nil,
        videoHeight: Int? = nil,
        videoFrameRate: Double? = nil,
        videoBitrate: Int? = nil,
        fileBitrate: Int? = nil,
        audioCodec: String? = nil,
        audioChannels: String? = nil,
        audioSampleRate: Int? = nil,
        audioLanguage: String? = nil,
        subtitleName: String? = nil,
        subtitleCodec: String? = nil,
        subtitleLanguage: String? = nil,
        subtitleSource: String? = nil,
        playerEngine: String? = nil
    ) {
        self.addonName = addonName
        self.addonLogoURL = addonLogoURL
        self.streamName = streamName
        self.streamDescription = streamDescription
        self.filename = filename
        self.fileSize = fileSize
        self.videoCodec = videoCodec
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoFrameRate = videoFrameRate
        self.videoBitrate = videoBitrate
        self.fileBitrate = fileBitrate
        self.audioCodec = audioCodec
        self.audioChannels = audioChannels
        self.audioSampleRate = audioSampleRate
        self.audioLanguage = audioLanguage
        self.subtitleName = subtitleName
        self.subtitleCodec = subtitleCodec
        self.subtitleLanguage = subtitleLanguage
        self.subtitleSource = subtitleSource
        self.playerEngine = playerEngine
    }
}

/// Pure formatting helpers ported from Android `StreamInfoOverlay.kt`.
enum PlayerStreamInfoFormat {
    /// Android `formatFileSize`.
    static func fileSize(_ bytes: Int64) -> String {
        switch bytes {
        case 1_073_741_824...:
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
        case 1_048_576...:
            return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        case 1_024...:
            return String(format: "%.1f KB", Double(bytes) / 1_024.0)
        default:
            return "\(bytes) B"
        }
    }

    /// Android `formatBitrate`.
    static func bitrate(_ bps: Int) -> String {
        switch bps {
        case 1_000_000...:
            return String(format: "%.1f Mbps", Double(bps) / 1_000_000.0)
        case 1_000...:
            return String(format: "%.0f kbps", Double(bps) / 1_000.0)
        default:
            return "\(bps) bps"
        }
    }

    /// Android `formatResolution`: "W × H (label)" with the label derived
    /// from the largest dimension.
    static func resolution(width: Int, height: Int) -> String {
        let maxDim = max(width, height)
        let label: String
        switch maxDim {
        case 3600...: label = "4K"
        case 2400..<3600: label = "1440p"
        case 1800..<2400: label = "1080p"
        case 1200..<1800: label = "720p"
        case 800..<1200: label = "480p"
        default: label = "\(min(width, height))p"
        }
        return "\(width) × \(height) (\(label))"
    }

    /// Android renders the frame rate as "%.3f fps".
    static func frameRate(_ fps: Double) -> String {
        String(format: "%.3f fps", fps)
    }

    /// Android renders the sample rate as "<hz / 1000> kHz".
    static func sampleRate(_ hz: Int) -> String {
        "\(hz / 1_000) kHz"
    }

    /// Android `languageCodeToName`: display name for a BCP-47/ISO code.
    static func languageName(forCode code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return code }
        let locale = Locale(identifier: "en_US")
        if let name = locale.localizedString(forLanguageCode: trimmed), !name.isEmpty {
            return name
        }
        if let name = locale.localizedString(forLanguageCode: String(trimmed.prefix(2))),
            !name.isEmpty {
            return name
        }
        return trimmed
    }
}
