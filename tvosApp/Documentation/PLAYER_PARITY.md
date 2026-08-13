# Native tvOS playback parity

Reviewed: 2026-08-11

The reference is the established Compose player under `composeApp/src/commonMain/kotlin/com/nuvio/app/features/player` plus the iOS MPV bridge implementation. This matrix records the native tvOS scope and intentional platform boundaries.

| Capability | Compose reference | Native tvOS status |
|---|---|---|
| Play, pause, seek 10 seconds | `PlayerControls.kt` | Implemented with focused buttons and system remote commands |
| Timeline seeking | `PlayerControls.kt` | Implemented with a focusable Siri Remote timeline in 10-second steps |
| Playback lifecycle and system controls | iOS `NowPlayingController.swift` | Implemented with tvOS Now Playing metadata, toggle, skip, and position commands |
| Loading and playback errors | `PlayerEngine.kt` | Implemented through MPV events and overlay states |
| Playback speed | `PlayerEngine.kt`, `PlayerControls.kt` | Implemented for 0.5x through 2x |
| Video resize | `PlayerResizeMode` | Implemented as Fit, Fill, and Original |
| Embedded audio tracks | `SubtitleAudioModels.kt` | Implemented from MPV `track-list` |
| Embedded subtitle tracks and Off | `SubtitleAudioModels.kt` | Implemented from MPV `track-list` |
| Source switching | `PlayerSourcesPanel.kt` | Implemented for playable sources already fetched for the title |
| Episode navigation | `PlayerEpisodesPanel.kt` | Implemented by returning to details with the selected episode active |
| Resume and progress persistence | `PlayerScreenRuntimePlaybackActions.kt` | Implemented locally, resumes from 15 seconds through 92 percent, keeps the newest 250 items |
| Source and episode metadata | `PlayerScreenArgs.kt` | Implemented in the player header and option panels |
| Network request headers | stream `behaviorHints.proxyHeaders.request` | Implemented with validation and MPV `http-header-fields` |
| Skip intro, recap, and ending | `SkipIntroRepository.kt`, Anime Skip, AniSkip | Implemented with synchronized mobile integration settings and focused in-player skip actions. Anime Skip reads its client identifier from the profile settings blob; the current mobile contract separates that credential into a provider credential flow, so Anime Skip may be enabled without a usable credential until that flow is ported. |
| Addon subtitle discovery | `SubtitleRepository.kt` | Deferred until the tvOS service implements the subtitle resource endpoint |
| Subtitle size and delay | `SubtitleStylePanel.kt` | Implemented with native MPV font-size controls and 100 ms delay adjustment |
| Next-episode autoplay | `PlayerNextEpisodeAutoPlay.kt` | Deferred, manual episode selection is available |
| Profile PIN protection | `ProfileRepository.kt`, `verify_profile_pin` | Deferred. PIN-protected profiles open without a challenge until the PIN entry flow is implemented. |
| TMDB and Trakt collection sources | `TVCollectionSource` | Deferred. Sources decode but are not resolved; provider-backed folders render empty. |
| Tracking scrobble sync | `PlayerScreenRuntimePlaybackActions.kt` | Deferred because native tvOS currently has no tracking provider repository |
| Picture in Picture | Android platform manager | Outside tvOS fullscreen television scope |
| Mobile gestures and control lock | `PlayerSurfaceGestures.kt` | Outside remote-first tvOS scope |
| External mobile players | platform launchers | Outside native Apple TV app scope |
| Torrent and P2P playback | platform P2P engines | Deferred until a tvOS-compatible engine is available |

## Focus decision

`AppShellView` marks the sidebar and content containers as separate SwiftUI `focusSection()` regions. This gives the tvOS focus engine a geometric bridge from the vertical menu to dynamic poster rails while preserving native directional propagation. Explicit `onMoveCommand` routing was rejected because a handler consumes commands even when its closure takes no action, which breaks up, down, and left behavior.

## Player UI structure

The player follows the Android TV control hierarchy while using tvOS focus and route controls:

- `PlayerControlsOverlay.swift` owns the title header, focused timeline, primary transport controls, and contextual skip action.
- `PlaybackTimelineScrubber.swift` owns the remote-first timeline. tvOS has no standard SwiftUI slider, so this control uses focused left and right editing in 10-second steps.
- `PlayerControlStrip.swift` keeps resize, speed, subtitles, audio, sources, and episodes as direct actions in one centered pill strip, matching `PlayerControls.kt`. `AudioRoutePicker` is the sole tvOS-specific addition.
- Resize and speed cycle directly through the same values as Android TV. Subtitles, audio, sources, and episodes open stable modal panels.
- `PlayerSelectionPanel.swift` owns those modal rows. Every row explicitly renders white text on a dark surface when unfocused and black text on white when focused. Selected indicators inherit the same foreground color, preventing white-on-white focus states.
- `SubtitleAppearanceView.swift` owns subtitle delay and text-size adjustments.
- `PlayerView.swift` owns auto-hiding playback chrome. A remote interaction reveals the controls. Menu and Back first hide the chrome, then leave playback on a second press.
- The custom MPV player has one system transport topology: `TVNowPlayingController` registers Play, Pause, Toggle, Skip, and Position with the shared `MPRemoteCommandCenter`. No SwiftUI `onPlayPauseCommand` or `UIPressType.playPause` handler competes with it. In-app buttons call the same playback session methods directly. Explicit `play()` and `pause()` methods are idempotent; only Toggle changes state based on the current value.
- The generic press observer only refreshes chrome visibility and forwards every press to UIKit. It never switches on a press type, and the installed UIKit `UIPress.PressType` API has no volume cases.
- MPV is pinned to unity gain (`volume=100`, `volume-max=100`). tvOS owns system output volume through the Siri Remote, Control Center, HDMI-CEC, IR, HomePod, or the selected route. `AVAudioSession` activation declares long-form playback and does not set gain. `TVAudioSessionCoordinator.swift` pauses on system interruptions and only resumes when Apple recommends resumption and playback had been active before the interruption.

- The visible player no longer has **More Controls** or **Fewer Controls**. The superseded menu implementation was removed.

## Verification

- Apple TV system player conventions reviewed on 2026-08-13 against [Apple HIG: Playing video](https://developer.apple.com/design/human-interface-guidelines/playing-video), [tvOS 26.6 release notes](https://developer.apple.com/documentation/tvos-release-notes/tvos-26_6-release-notes), [Apple TV 4K volume control](https://support.apple.com/guide/tv/apple-tv-4k-remote-control-receiver-atvbbe2477c9/tvos), [`AVAudioSession.outputVolume`](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume), [`AVAudioSession.Category.playback`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback), [`setActive(_:options:)`](https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)), [handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), [`AVRoutePickerView`](https://developer.apple.com/documentation/avkit/avroutepickerview), [handling external player events](https://developer.apple.com/documentation/mediaplayer/handling-external-player-events-notifications), [Becoming a now playable app](https://developer.apple.com/documentation/mediaplayer/becoming-a-now-playable-app), [`MPRemoteCommandCenter`](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter), and [`togglePlayPauseCommand`](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter/toggleplaypausecommand).
- Apple’s current Now Playable sample was downloaded and inspected. Its tvOS implementation registers Play, Pause, Toggle, Skip, and Position through the shared remote command center and activates a playback audio session. Nuvio uses that topology for its custom MPV engine.
- Xcode 27.0 build 27A5228h and AppleTVOS 27.0 SDK reviewed.
- SwiftUI installed interface confirms `focusSection()` is available on tvOS.
- Generic tvOS Debug build passed with signing disabled. The only warning is Xcode’s expected AppIntents metadata message because the target does not link AppIntents.
- The tvOS 27 simulator suite passed 35 tests with zero failures. The first retry exposed a stale CoreSimulator registry entry whose device directory had been deleted; recreating the simulator fixed the infrastructure failure, and the unchanged tests passed.
- `StremioServiceTests.swift` was split into focused service and player-feature suites. Every Swift source and test file remains at or below 400 lines.
- The signed build uses only canonical bundle `com.nuvio.app.tvos.dev` and deploys over its existing data container. Physical Siri Remote transport, focus contrast, and television volume routing require the final at-TV acceptance pass.
