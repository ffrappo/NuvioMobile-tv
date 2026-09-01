import Foundation

// MARK: - Playback option enums (PlayerSettingsDataStore.kt)

public enum NuvioStreamAutoPlayMode: String, CaseIterable, Hashable, Sendable {
    case manual = "MANUAL"
    case firstStream = "FIRST_STREAM"
    case regexMatch = "REGEX_MATCH"
}

public enum NuvioStreamAutoPlaySource: String, CaseIterable, Hashable, Sendable {
    case allSources = "ALL_SOURCES"
    case installedAddonsOnly = "INSTALLED_ADDONS_ONLY"
    case enabledPluginsOnly = "ENABLED_PLUGINS_ONLY"
}

public enum NuvioVodCacheSizeMode: String, CaseIterable, Hashable, Sendable {
    case auto = "AUTO"
    case manual = "MANUAL"
}

public enum NuvioFrameRateMatchingMode: String, CaseIterable, Hashable, Sendable {
    case off = "OFF"
    case start = "START"
    case startStop = "START_STOP"
}

public enum NuvioNextEpisodeThresholdMode: String, CaseIterable, Hashable, Sendable {
    case percentage = "PERCENTAGE"
    case minutesBeforeEnd = "MINUTES_BEFORE_END"
}

public enum NuvioMpvHardwareDecodeMode: String, CaseIterable, Hashable, Sendable {
    case legacyDirectCopy = "LEGACY_DIRECT_COPY"
    case autoSafe = "AUTO_SAFE"
    case hardwareCopy = "HARDWARE_COPY"
    case hardwareDirect = "HARDWARE_DIRECT"
    case disabled = "DISABLED"
}

public enum NuvioInternalPlayerEngine: String, CaseIterable, Hashable, Sendable {
    case exoplayer = "EXOPLAYER"
    case mpvPlayer = "MVP_PLAYER"
    case auto = "AUTO"
}

public enum NuvioLibassRenderType: String, CaseIterable, Hashable, Sendable {
    case cues = "CUES"
    case effectsCanvas = "EFFECTS_CANVAS"
    case effectsOpenGl = "EFFECTS_OPEN_GL"
    case overlayCanvas = "OVERLAY_CANVAS"
    case overlayOpenGl = "OVERLAY_OPEN_GL"
}

public enum NuvioDv7HandlingMode: String, CaseIterable, Hashable, Sendable {
    case auto = "AUTO"
    case hdr10BaseLayer = "HDR10_BASE_LAYER"
    case dv81Libdovi = "DV81_LIBDOVI"
    case stripDv = "STRIP_DV"
    case off = "OFF"
}

public enum NuvioAutoSkipSegmentType: String, CaseIterable, Hashable, Sendable {
    case intro = "INTRO"
    case recap = "RECAP"
    case outro = "OUTRO"
}

public enum NuvioAudioDecoderPriority: Int, CaseIterable, Hashable, Sendable {
    /// `EXTENSION_RENDERER_MODE_OFF`
    case off = 0
    /// `EXTENSION_RENDERER_MODE_ON` (default)
    case on = 1
    /// `EXTENSION_RENDERER_MODE_PREFER`
    case prefer = 2
}

public enum NuvioPlayerPreference: String, CaseIterable, Hashable, Sendable {
    case internalPlayer = "INTERNAL"
    case external = "EXTERNAL"
}

// MARK: - Network status (NetworkSettingsScreen.kt)

public enum NuvioConnectionType: String, Hashable, Sendable {
    case wifi
    case ethernet
    case offline
}

public enum NuvioNetworkTestState: String, Hashable, Sendable {
    case idle
    case testingLatency
    case testingDownload
    case done
    case error
}

public enum NuvioUpdateChannel: String, CaseIterable, Hashable, Sendable {
    case stable = "STABLE"
    case beta = "BETA"
}

// MARK: - Settings state

/// Presentation state for the entire settings tree. Defaults mirror the Android
/// `PlayerSettings`, `BufferSettings`, `SubtitleStyleSettings`, `LayoutPreferenceDataStore`,
/// and `ThemeSettingsViewModel` defaults. The integration layer owns persistence;
/// values flow in and changes flow out.
public struct NuvioSettingsState: Equatable, Sendable {
    // Layout
    public var homeLayout: NuvioHomeLayout = .modern
    public var modernLandscapePostersEnabled = false
    public var modernHeroFullScreenBackdropEnabled = false
    public var classicFocusGradientEnabled = false
    public var theme: NuvioAppTheme = .white

    // Playback: general (PlaybackSettingsSections.kt)
    public var playerPreference: NuvioPlayerPreference = .internalPlayer
    public var internalPlayerEngine: NuvioInternalPlayerEngine = .exoplayer
    public var autoSwitchInternalPlayerOnError = false
    public var loadingOverlayEnabled = true
    public var showPlayerLoadingStatus = true
    public var pauseOverlayEnabled = true
    public var osdClockEnabled = true
    public var skipIntroEnabled = true
    public var parentalGuideEnabled = true
    public var autoSkipSegmentTypes: Set<NuvioAutoSkipSegmentType> = []
    public var externalPlayerForwardSubtitles = false
    public var externalPlayerSendSkipSegments = false
    public var frameRateMatchingMode: NuvioFrameRateMatchingMode = .off
    public var resolutionMatchingEnabled = false
    public var hideTorrentStats = false

    // Audio (PlaybackAudioSettings.kt)
    public var preferredAudioLanguage = "device"
    public var secondaryPreferredAudioLanguage: String?
    public var skipSilence = false
    public var rememberAudioDelayPerDevice = true
    public var audioDecoderPriority: NuvioAudioDecoderPriority = .on
    public var downmixEnabled = false
    public var audioOutputChannelCount = 0
    public var maintainOriginalAudioOnDownmix = true
    public var tunneledAudioEnabled = false
    public var forceOpticalPassthrough = false
    public var dv7HandlingMode: NuvioDv7HandlingMode = .auto
    public var dv7ToDv81PreserveMappingEnabled = false
    public var dv5ToDv81Enabled = false
    public var stripHdr10PlusSei = false
    public var mpvHardwareDecodeMode: NuvioMpvHardwareDecodeMode = .autoSafe

    // Subtitles (PlaybackSubtitleSettings.kt)
    public var preferredSubtitleLanguage = "en"
    public var isPreferredSubtitleLanguageSystemDefault = true
    public var secondaryPreferredSubtitleLanguage: String?
    public var useForcedSubtitles = false
    public var showOnlyPreferredSubtitleLanguages = false
    public var stripSdh = false
    public var subtitleSizePercent = 120
    public var subtitleVerticalOffsetPercent = 5
    public var subtitleBold = false
    public var subtitleOutlineEnabled = true
    public var useLibass = false
    public var libassRenderType: NuvioLibassRenderType = .overlayOpenGl

    // Autoplay (PlaybackAutoPlaySettings.kt)
    public var streamReuseLastLinkEnabled = false
    public var streamReuseLastLinkCacheHours = 24
    public var streamAutoPlayMode: NuvioStreamAutoPlayMode = .manual
    public var streamAutoPlayTimeoutSeconds = 3
    public var postPlayRecommendationsEnabled = true
    public var postPlayMovieThresholdPercent = 90
    public var streamAutoPlayNextEpisodeEnabled = false
    public var streamAutoPlayNextEpisodeFallbackEnabled = true
    public var stillWatchingEnabled = false
    public var stillWatchingEpisodeThreshold = 3
    public var streamAutoPlayPreferBingeGroupForNextEpisode = true
    public var streamAutoPlayReuseBingeGroup = true
    public var nextEpisodeThresholdMode: NuvioNextEpisodeThresholdMode = .percentage
    public var nextEpisodeThresholdPercent = 99.0
    public var nextEpisodeThresholdMinutesBeforeEnd = 2.0
    public var streamAutoPlaySource: NuvioStreamAutoPlaySource = .allSources
    public var streamAutoPlaySelectedAddonCount = 0
    public var streamAutoPlayRegex = ""

    // Buffer and network (PlaybackBufferNetworkSettings.kt)
    public var nuvioPerformanceModeEnabled = false
    public var bufferEngineEnabled = false
    public var minBufferSeconds = 15
    public var maxBufferSeconds = 45
    public var bufferForPlaybackSeconds = 5
    public var bufferForPlaybackAfterRebufferSeconds = 3
    public var backBufferSeconds = 15
    public var bufferBudgetManaged = true
    public var targetBufferSizeMb = 150
    public var allowLargeTargetBuffer = false
    public var vodCacheEnabled = false
    public var vodCacheSizeMode: NuvioVodCacheSizeMode = .auto
    public var vodCacheSizeMb = 500
    public var parallelNetworkEnabled = false
    public var enableHttp2 = false
    public var useParallelConnections = false
    public var parallelConnectionCount = 2
    public var parallelChunkSizeKb = 16 * 1024
    public var deviceMaxHeapMb = 512

    // Network (NetworkSettingsScreen.kt)
    public var connectionType: NuvioConnectionType = .offline
    public var networkTestState: NuvioNetworkTestState = .idle
    public var latencyMs: Int?
    public var downloadMbps: Double?
    public var streamTestState: NuvioNetworkTestState = .idle
    public var streamLatencyMs: Int?
    public var streamDownloadMbps: Double?

    // Advanced (NetworkSettingsScreen.kt advanced groups)
    public var fastHorizontalNavigationEnabled = false
    public var nuvioFocusScrollEnabled = true
    public var rememberLastProfileEnabled = false
    public var confirmExitEnabled = false

    // Diagnostics
    public var sentryReportsEnabled = false
    public var playbackIssueReportsEnabled = false
    public var playerStatsHudEnabled = false

    // About
    public var appVersion = "1.0"
    public var updateChannel: NuvioUpdateChannel = .stable
    public var updateBannerEnabled = true

    public init() {}
}
