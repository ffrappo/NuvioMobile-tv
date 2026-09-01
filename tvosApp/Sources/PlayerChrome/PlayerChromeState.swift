import Foundation

/// Boolean panel/dialog flags mirroring the overlay flags of the Android
/// `PlayerUiState` (PlayerScreen.kt). All flags default to false; the
/// integrator maps its presentation state onto these inputs.
struct PlayerChromeFlags: Equatable, Sendable {
    var showControls = false
    var showPauseOverlay = false
    var showStreamInfoOverlay = false
    var showEpisodesPanel = false
    var showSourcesPanel = false
    var showAudioOverlay = false
    var showSubtitleOverlay = false
    var showSubtitleStylePanel = false
    var showSubtitleDelayOverlay = false
    var showSubtitleTimingDialog = false
    var showSpeedDialog = false
    var showMoreDialog = false
    var hasError = false
    /// Android `pendingPreviewSeekPosition != nil` (scrub preview in flight).
    var hasPendingPreviewSeek = false

    init(
        showControls: Bool = false,
        showPauseOverlay: Bool = false,
        showStreamInfoOverlay: Bool = false,
        showEpisodesPanel: Bool = false,
        showSourcesPanel: Bool = false,
        showAudioOverlay: Bool = false,
        showSubtitleOverlay: Bool = false,
        showSubtitleStylePanel: Bool = false,
        showSubtitleDelayOverlay: Bool = false,
        showSubtitleTimingDialog: Bool = false,
        showSpeedDialog: Bool = false,
        showMoreDialog: Bool = false,
        hasError: Bool = false,
        hasPendingPreviewSeek: Bool = false
    ) {
        self.showControls = showControls
        self.showPauseOverlay = showPauseOverlay
        self.showStreamInfoOverlay = showStreamInfoOverlay
        self.showEpisodesPanel = showEpisodesPanel
        self.showSourcesPanel = showSourcesPanel
        self.showAudioOverlay = showAudioOverlay
        self.showSubtitleOverlay = showSubtitleOverlay
        self.showSubtitleStylePanel = showSubtitleStylePanel
        self.showSubtitleDelayOverlay = showSubtitleDelayOverlay
        self.showSubtitleTimingDialog = showSubtitleTimingDialog
        self.showSpeedDialog = showSpeedDialog
        self.showMoreDialog = showMoreDialog
        self.hasError = hasError
        self.hasPendingPreviewSeek = hasPendingPreviewSeek
    }
}

/// The single chrome layer resolved on top of everything else, following the
/// Android PlayerScreen composition: error replaces the screen, stream info
/// takes precedence over the pause overlay, the pause overlay takes precedence
/// over controls, dialogs render above controls, and side panels/overlays
/// suppress the controls layer entirely.
enum PlayerChromeLayer: Equatable, Sendable, CaseIterable {
    case none
    case controls
    case pauseOverlay
    case streamInfoOverlay
    case episodesPanel
    case sourcesPanel
    case audioOverlay
    case subtitleOverlay
    case subtitleStylePanel
    case subtitleDelayOverlay
    case subtitleTimingDialog
    case speedDialog
    case moreDialog
    case error

    /// Layers that render as a full-screen modal above the controls chrome.
    var isOverlay: Bool {
        switch self {
        case .none, .controls: return false
        default: return true
        }
    }
}

/// Pure, presentation-only chrome state machine. Feed it the boolean overlay
/// flags; read back the resolved layer, per-layer visibility rules, and the
/// Android post-play blocking rule. No player, AV, or focus code lives here.
struct PlayerChromeState: Equatable, Sendable {
    let flags: PlayerChromeFlags

    init(flags: PlayerChromeFlags = PlayerChromeFlags()) {
        self.flags = flags
    }

    // MARK: Resolved layer

    /// The topmost chrome layer. Precedence mirrors the Android z-stack:
    /// error > stream info > pause > more dialog > timing dialog >
    /// audio/subtitle/delay/style/speed panels > sources > episodes >
    /// controls > none. Panels suppress controls (Android hides the controls
    /// `AnimatedVisibility` whenever a panel or the speed dialog is open).
    var resolvedLayer: PlayerChromeLayer {
        if flags.hasError { return .error }
        if flags.showStreamInfoOverlay { return .streamInfoOverlay }
        if flags.showPauseOverlay { return .pauseOverlay }
        if flags.showMoreDialog { return .moreDialog }
        if flags.showSubtitleTimingDialog { return .subtitleTimingDialog }
        if flags.showAudioOverlay { return .audioOverlay }
        if flags.showSubtitleOverlay { return .subtitleOverlay }
        if flags.showSubtitleDelayOverlay { return .subtitleDelayOverlay }
        if flags.showSubtitleStylePanel { return .subtitleStylePanel }
        if flags.showSpeedDialog { return .speedDialog }
        if flags.showSourcesPanel { return .sourcesPanel }
        if flags.showEpisodesPanel { return .episodesPanel }
        if isControlsVisible { return .controls }
        return .none
    }

    // MARK: Per-layer visibility rules

    /// Android PlayerScreen controls `AnimatedVisibility`:
    /// `showControls && error == null && !pause && !streamInfo && !style &&
    ///  !delay && !episodes && !sources && !audio && !subtitle && !speed`.
    /// The more-actions dialog and subtitle timing dialog render above the
    /// controls and do NOT suppress them.
    var isControlsVisible: Bool {
        flags.showControls &&
            !flags.hasError &&
            !flags.showPauseOverlay &&
            !flags.showStreamInfoOverlay &&
            !flags.showSubtitleStylePanel &&
            !flags.showSubtitleDelayOverlay &&
            !flags.showEpisodesPanel &&
            !flags.showSourcesPanel &&
            !flags.showAudioOverlay &&
            !flags.showSubtitleOverlay &&
            !flags.showSpeedDialog
    }

    /// Pause overlay renders below stream info (Android zIndex 2.5 vs 2.6),
    /// so an open stream info overlay wins and hides the pause overlay.
    var isPauseOverlayVisible: Bool {
        flags.showPauseOverlay && !flags.hasError && !flags.showStreamInfoOverlay
    }

    var isStreamInfoOverlayVisible: Bool {
        flags.showStreamInfoOverlay && !flags.hasError
    }

    var isErrorVisible: Bool { flags.hasError }

    /// Side panels render with `flag && error == null` in Android; opening a
    /// panel closes the pause/stream-info overlays in the view model, so the
    /// flags are mutually exclusive by construction.
    var isEpisodesPanelVisible: Bool { flags.showEpisodesPanel && !flags.hasError }
    var isSourcesPanelVisible: Bool { flags.showSourcesPanel && !flags.hasError }
    var isAudioOverlayVisible: Bool { flags.showAudioOverlay && !flags.hasError }
    var isSubtitleOverlayVisible: Bool { flags.showSubtitleOverlay && !flags.hasError }
    var isSubtitleStylePanelVisible: Bool { flags.showSubtitleStylePanel && !flags.hasError }
    var isSubtitleDelayOverlayVisible: Bool { flags.showSubtitleDelayOverlay && !flags.hasError }
    var isSubtitleTimingDialogVisible: Bool { flags.showSubtitleTimingDialog && !flags.hasError }
    var isSpeedDialogVisible: Bool { flags.showSpeedDialog && !flags.hasError }
    var isMoreDialogVisible: Bool { flags.showMoreDialog && !flags.hasError }

    /// Any panel or dialog capturing key input (Android `panelOrDialogOpen`).
    var isPanelOrDialogOpen: Bool {
        flags.showEpisodesPanel || flags.showSourcesPanel ||
            flags.showAudioOverlay || flags.showSubtitleOverlay ||
            flags.showSubtitleStylePanel || flags.showSpeedDialog ||
            flags.showSubtitleDelayOverlay || flags.showSubtitleTimingDialog ||
            flags.showMoreDialog
    }

    // MARK: Derived rules

    /// Faithful port of Android `PlayerUiState.blocksPostPlayRecommendation()`:
    /// a pending scrub preview, the pause overlay, stream info, the episodes
    /// or sources panel, audio/subtitle selection, subtitle style, subtitle
    /// delay, the subtitle timing dialog, the speed dialog, or the more
    /// dialog each block the post-play recommendation.
    var blocksPostPlayRecommendation: Bool {
        flags.hasPendingPreviewSeek ||
            flags.showPauseOverlay ||
            flags.showStreamInfoOverlay ||
            flags.showEpisodesPanel ||
            flags.showSourcesPanel ||
            flags.showAudioOverlay ||
            flags.showSubtitleOverlay ||
            flags.showSubtitleStylePanel ||
            flags.showSubtitleDelayOverlay ||
            flags.showSubtitleTimingDialog ||
            flags.showSpeedDialog ||
            flags.showMoreDialog
    }

    /// Android clears the skip interval while the pause overlay (or loading /
    /// post-play, outside this machine's inputs) is visible.
    var suppressesSkipIntro: Bool {
        flags.showPauseOverlay
    }
}
