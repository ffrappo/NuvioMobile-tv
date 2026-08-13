# tvOS player review proposal

Status: ready for maintainer discussion
Validated: 2026-08-13
Integrated branch: `tvos-initial-port`
Physical build: `d45fef6b`
Validation documentation: committed with this proposal

## Review request

This work changes player behavior and player UI, so it should be proposed to maintainers before opening a pull request. The repository contribution policy requires an approved issue for a larger directional change. If maintainers approve the direction, link that issue in the pull request and split the branch into focused review units where practical.

Suggested issue title:

> Approve the native tvOS player compatibility and remote-control corrections

## Problem statement

The native tvOS player had several reproducible problems on Apple TV HD:

- player chrome could become unreachable after hiding
- Play/Pause had competing or state-inverting paths
- MPV changed the shared audio session to `mixWithOthers` when AudioUnit opened, which broke physical Siri Remote volume on the selected tvOS route
- stream metadata work repeated during SwiftUI rendering
- incompatible 4K, HDR, AV1, and VP9 sources could be selected on Apple TV HD
- focused selection rows could render white text on white
- the More Controls hierarchy did not match the established Android TV player organization
- source and episode presentation lacked the established mobile metadata hierarchy

## Proposed behavior

- Use one `MPRemoteCommandCenter` transport topology for Play, Pause, Toggle, Skip, and Position.
- Wake hidden controls only for directional, Select, and Play/Pause press types, then forward every press to UIKit.
- Keep MPV at unity gain with no app-owned volume UI or mutable volume state.
- Start MPV's tvOS AudioUnit backend with `audio-exclusive=yes`. In MPV 0.41 this prevents the backend from adding `mixWithOthers`, preserving Apple's nonmixing primary-playback session and system-route volume behavior.
- Parse stream display metadata once, rank supported sources first, and prevent incompatible direct streams from being selected on Apple TV HD while keeping them visible with an explanation.
- Present resize, speed, subtitles, audio, sources, and episodes as direct player actions. Audio Output remains the sole tvOS-specific addition.
- Use explicit black-on-white focused rows and white-on-dark unfocused rows.
- Preserve the source-card and Android TV-style series-page improvements.

## Physical acceptance

Validated on Apple TV HD (`AppleTV5,3`) running tvOS 26.6 with canonical bundle `com.nuvio.app.tvos.dev`:

- directional and Select input reveal the player controls
- subtitles and audio controls are reachable
- Play/Pause responds to a physical Siri Remote press
- physical Volume Up and Volume Down control the selected tvOS audio route during Nuvio playback
- no Nuvio software-volume control is present
- one canonical Nuvio process was observed after installation

The final acceptance used the physical Siri Remote. It did not use software-remote automation.

## Automated verification

- Generic tvOS Debug build passed with Xcode 27.0 and AppleTVOS 27.0 SDK.
- The tvOS 27 simulator suite passed 54 tests with zero failures after integration with the catalog redesign.
- All Swift source and test files are at or below 400 lines.
- The Top Shelf extension embedded and validated.
- Detailed evidence is in:
  - `tvosApp/Documentation/VALIDATION.md`
  - `tvosApp/Documentation/PLAYER_PARITY.md`
  - `tvosApp/Documentation/TVOS27_PLATFORM_AUDIT.md`

## Suggested review units

The current branch records the work as coherent milestones. To fit the repository's focused-PR policy, propose the full direction in one issue, then submit approved units in this order:

1. **Playback compatibility and metadata caching**
   - stream metadata decode caching
   - Apple TV HD capability ranking and compatibility messages
   - focused compatibility tests

2. **Siri Remote transport and audio-session correction**
   - one `MPRemoteCommandCenter` path
   - idempotent Play and Pause
   - allowlisted control wake path
   - MPV unity gain and nonmixing AudioUnit session
   - removal of the inapplicable indirect-input plist key

3. **Player focus and control hierarchy**
   - focused row contrast correction
   - direct Android TV-style control strip
   - tvOS Audio Output action

4. **Source and series presentation**
   - source metadata hierarchy
   - Android TV-style season and episode layout

Maintainers may instead approve one larger PR. Record that approval in the linked issue before opening it.

## Integration note

The player work was originally isolated at `de178d08` while catalog development continued concurrently. Its net player milestones and physical validation receipts are now integrated into `tvos-initial-port`; the superseded worktree and branch can be removed. Any upstream pull request still requires maintainer approval under the repository contribution policy, a linked issue, and current before-and-after evidence from the integrated branch.

## Suggested pull request text

Use `.github/PULL_REQUEST_TEMPLATE.md` and replace placeholders only after an issue has explicit maintainer approval.

### Summary

Correct the native tvOS player on Apple TV HD by caching stream metadata, gating incompatible direct streams, consolidating Siri Remote transport, preserving the nonmixing system audio session, fixing focused-row contrast, and aligning the player controls with the existing Android TV information architecture.

### Why

The previous player could become difficult to control, could present unsuitable streams on Apple TV HD, and could lose physical Siri Remote volume because MPV's AudioUnit backend changed the playback session to `mixWithOthers`. Focused selection rows could also become unreadable.

### Issue or approval

Approved in `#ISSUE_NUMBER`.

### Testing

- Xcode 27.0 generic tvOS Debug build
- tvOS 27 simulator, 54 tests, 0 failures
- Apple TV HD (`AppleTV5,3`), tvOS 26.6
- physical directional, Select, Play/Pause, Volume Up, and Volume Down acceptance
- subtitle and audio menu navigation
- canonical bundle installation and single-process check

### Screenshots or video

Attach before and after player screenshots, plus a short physical-remote video if maintainers request transport and volume proof.

### Breaking changes

None.

## Scope boundaries

- No app-owned volume slider or gain state.
- No runtime MPV volume changes.
- No new dependency.
- No torrent or P2P playback.
- No next-episode autoplay.
- No tracking-provider scrobble synchronization.
- No production deployment or push is part of this proposal.
