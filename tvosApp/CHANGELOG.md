# tvOS changelog

This file records user-visible changes to the native Apple TV app.

## Unreleased

### Added

- Continuous Siri Remote touch-surface scrubbing across the full timeline, with duration-aware acceleration for directional remotes and predictable 10-second VoiceOver adjustments.
- Persistent subtitle track selection per title and profile. Restoration tolerates track identifier changes by matching identifier, language, then display name.
- Persistent subtitle font size per profile and subtitle delay per video. Explicit subtitle Off is also remembered.
- Hardware-aware source compatibility for Apple TV HD. Direct 4K, HDR, AV1, and VP9 sources remain visible with clear compatibility messages while supported sources rank first.
- Native Audio Output selection through the tvOS route picker.

### Changed

- Playback actions use icon-only controls with descriptive accessibility labels.
- Player controls follow the direct Android TV organization for resize, speed, subtitles, audio, sources, and episodes.
- Stream display metadata is parsed once during decoding instead of during repeated SwiftUI rendering.
- Root tab chrome is simpler so page content remains the visual focus.

### Fixed

- Back/Menu now closes the current player panel, hides visible controls, or returns to title details in that order. A handled press no longer falls through to the Apple TV Home screen.
- Play/Pause uses one `MPRemoteCommandCenter` transport path with idempotent play and pause actions.
- Directional, Select, and Play/Pause presses can reveal hidden controls without taking ownership of their actions from UIKit.
- MPV stays at unity gain and uses a nonmixing AudioUnit playback session, leaving television and selected-route volume under tvOS.
- Focused subtitle, audio, source, and episode rows use explicit high-contrast text and indicators.
- Source switching reapplies stored subtitle preferences after replacement tracks become available.
- Signing out clears subtitle preferences for the profile being signed out.
