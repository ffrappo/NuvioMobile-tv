import SwiftUI

/// The parity overlay composition for the player: the chrome state, the
/// overlay layer host, and the payload builders feeding the pause and
/// stream info overlays.
extension PlayerView {
    /// The parity overlay stack (Android PlayerScreen z-order): stream info
    /// above the pause overlay above the controls, resolved by
    /// PlayerChromeState from the boolean flags.
    var chrome: PlayerChromeState {
        PlayerChromeState(flags: PlayerChromeFlags(
            showControls: controls.isVisible,
            showPauseOverlay: session.isPaused && !controls.isVisible && !session.isEnded,
            showStreamInfoOverlay: showsStreamInfo,
            hasError: session.errorMessage != nil
        ))
    }

    var playerOverlayLayers: some View {
        PlayerOverlayLayers(
            chrome: chrome,
            pauseContent: pauseOverlayContent,
            streamInfo: streamInfoData,
            onDismissPauseOverlay: {},
            onDismissStreamInfoOverlay: { showsStreamInfo = false }
        )
    }

    private var pauseOverlayContent: PlayerPauseOverlayContent {
        var content = PlayerPauseOverlayContent()
        content.title = route.title
        content.episodeTitle = route.episodeTitle
        content.season = route.seasonNumber
        content.episode = route.episodeNumber
        content.year = route.summary.releaseInfo
        content.type = route.summary.type
        content.description = route.summary.description
        content.showClock = PersistedPlaybackSetting.toggle("playback.osdClock", default: true)
        return content
    }

    private var streamInfoData: PlayerStreamInfoData? {
        var data = PlayerStreamInfoData()
        data.streamName = route.sourceName
        let parameters = session.streamParameters
        data.videoCodec = parameters.videoCodec
        data.videoWidth = parameters.videoWidth
        data.videoHeight = parameters.videoHeight
        data.videoFrameRate = parameters.videoFrameRate
        data.audioCodec = parameters.audioCodec
        data.audioChannels = parameters.audioChannels
        return data
    }
}
