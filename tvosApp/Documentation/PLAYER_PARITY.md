# Native tvOS playback parity

Reviewed: 2026-08-11

The reference is the established Compose player under `composeApp/src/commonMain/kotlin/com/nuvio/app/features/player` plus the iOS MPV bridge implementation. This matrix records the native tvOS scope and intentional platform boundaries.

| Capability | Compose reference | Native tvOS status |
|---|---|---|
| Play, pause, seek 10 seconds | `PlayerControls.kt` | Implemented with focused buttons and remote play/pause |
| Timeline seeking | `PlayerControls.kt` | Implemented with explicit 10-second and 30-second focused buttons |
| Loading and playback errors | `PlayerEngine.kt` | Implemented through MPV events and overlay states |
| Playback speed | `PlayerEngine.kt`, `PlayerControls.kt` | Implemented for 0.5x through 2x |
| Video resize | `PlayerResizeMode` | Implemented as Fit, Fill, and Original |
| Embedded audio tracks | `SubtitleAudioModels.kt` | Implemented from MPV `track-list` |
| Embedded subtitle tracks and Off | `SubtitleAudioModels.kt` | Implemented from MPV `track-list` |
| Source switching | `PlayerSourcesPanel.kt` | Implemented for playable sources already fetched for the title |
| Episode navigation | `PlayerEpisodesPanel.kt` | Implemented by returning to details with the selected episode active |
| Resume and progress persistence | `PlayerScreenRuntimePlaybackActions.kt` | Implemented locally, resumes from 15 seconds through 92 percent, keeps the newest 250 items |
| Source and episode metadata | `PlayerScreenArgs.kt` | Implemented in the player header and option panels |
| Network response headers | platform engines | Deferred because the current tvOS Stremio model does not decode stream headers |
| Addon subtitle discovery | `SubtitleRepository.kt` | Deferred until the tvOS service implements the subtitle resource endpoint |
| Subtitle size and delay | `SubtitleStylePanel.kt` | Implemented with native MPV font-size controls and 100 ms delay adjustment |
| Next-episode autoplay | `PlayerNextEpisodeAutoPlay.kt` | Deferred, manual episode selection is available |
| Tracking scrobble sync | `PlayerScreenRuntimePlaybackActions.kt` | Deferred because native tvOS currently has no tracking provider repository |
| Picture in Picture | Android platform manager | Outside tvOS fullscreen television scope |
| Mobile gestures and control lock | `PlayerSurfaceGestures.kt` | Outside remote-first tvOS scope |
| External mobile players | platform launchers | Outside native Apple TV app scope |
| Torrent and P2P playback | platform P2P engines | Deferred until a tvOS-compatible engine is available |

## Focus decision

`AppShellView` marks the sidebar and content containers as separate SwiftUI `focusSection()` regions. This gives the tvOS focus engine a geometric bridge from the vertical menu to dynamic poster rails while preserving native directional propagation. Explicit `onMoveCommand` routing was rejected because a handler consumes commands even when its closure takes no action, which breaks up, down, and left behavior.

## Verification

- Xcode 27.0 build 27A5228h and AppleTVOS 27.0 SDK reviewed.
- SwiftUI installed interface confirms `focusSection()` is available on tvOS.
- Generic tvOS Debug build with signing disabled passes.
- Signed physical Apple TV Debug build and hands-on remote smoke testing remain pending until the paired device reconnects.
