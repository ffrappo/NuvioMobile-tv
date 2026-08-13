# Apple TV validation record

Reviewed: 2026-08-13
Contributor: Francesco Frapporti

## Scope

This record covers the initial native SwiftUI Apple TV port under `tvosApp`.

## Toolchain reviewed

- XcodeGen 2.45.4
- Xcode 27.0, build 27A5228h
- AppleTVOS 27.0 SDK
- Apple Swift 6.4 compiler in Swift 5 language mode
- CoreDevice `devicectl` 642.4
- deployment target tvOS 18.0

Installed help and SDK interfaces were reviewed for XcodeGen project generation, CoreDevice listing, app installation, process launch, SwiftUI focus, navigation, search, and AVKit audio routing.

## Sources reviewed

- Apple SwiftUI focus: https://developer.apple.com/documentation/swiftui/focus
- Apple navigation stack: https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack
- Apple playback experience: https://developer.apple.com/documentation/avkit/customizing-the-tvos-playback-experience
- Apple AVRoutePickerView: https://developer.apple.com/documentation/avkit/avroutepickerview
- libmpv client API: https://mpv.io/manual/master/#client-api
- XcodeGen project specification: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
- Stremio addon protocol: https://stremio.github.io/stremio-addon-sdk/protocol.html
- Stremio manifest format: https://stremio.github.io/stremio-addon-sdk/api/responses/manifest.html

## Build verification

The following checks passed during development:

- XcodeGen project generation
- generic tvOS Debug build with signing disabled
- generic tvOS test build
- signed physical-device Debug build
- installation and launch on a physical Apple TV
- running-process check after launch
- 1920 by 1080 screenshot capture from the physical device
- QR account-session start and polling against the production account service
- email sign-in, session refresh, sign-out, guest mode, and account addon pull
- MPVKit GPL package integration, including libmpv, FFmpeg, VideoToolbox, MoltenVK, libplacebo, and libass

XCTest execution requires a compatible installed tvOS Simulator runtime. That runtime was not available in the validation environment. The test bundle compiled and linked successfully, and zero tests executed.

The physical-device workflow used a USB-C cable between the Mac and Apple TV. Private signing identifiers, provisioning details, device names, and device identifiers are intentionally omitted.

## Runtime verification

Verified behaviors included:

- Home catalog loading and refresh
- account library pull
- profile and collection decoding
- addon manifest loading and concurrent stream lookup
- request-header forwarding to MPV
- progress resume after the MPV file-loaded event
- local and account-backed progress persistence
- phone-first QR sign-in
- native tab navigation and search
- player transport, timeline, menus, subtitle controls, audio routing, and Now Playing commands

## Redesign validation, 2026-08-13

The Android TV app at commit `88517217f9100b50036579cc343aa05009864685` was the primary organization reference. The shared Compose app was the secondary parity reference. The native redesign was validated against the current checkout through these receipts:

- Catalog browsing moved from blank Search into the dedicated Discover root, with type, catalog, and provider-supplied genre filters.
- Home, Discover, Search, collections, and source loading use bounded concurrency of three and publish completed batches without waiting for every addon.
- Home collections open dedicated routed folder screens, keeping collection hierarchy out of catalog rails. Each folder retains separate addon source rails instead of flattening providers into one grid.
- Catalog requests share a provider-aware repository with request coalescing, ten-minute caching, actual-page-size pagination, cancellation, duplicate filtering, and a repeated-page stop guard.
- Stream sources publish in addon order through a coalescing repository and remove stale partial results when a new title request starts.
- Detail requests are provider-aware, coalesced, and cached for fifteen minutes. Large JSON decoding runs away from UI-isolated work.
- Artwork requests coalesce and use ImageIO thumbnail decoding with bounded memory cost.
- Home, catalogs, Discover, Search, Library, details, seasons, episodes, and sources use native SwiftUI focusable controls, stable identity, lazy containers, and reusable poster cards.
- Season order is numeric with Specials last. Episode focus is restored per season, and in-progress episodes show progress.
- Unsupported playback sources remain visible with a compatibility explanation and cannot launch.
- Simulator review at 1920 by 1080 confirmed catalog loading, the large Home hero, See All rails, collapsed-sidebar safe areas, and the expanded-sidebar exclusion margin. Screenshot receipt: `/tmp/nuvio-home-safe360.png`.

Executed evidence:

- `xcodegen generate --spec tvosApp/project.yml` succeeded.
- Signing-disabled generic tvOS Debug build succeeded with Xcode 27.0 and AppleTVOS 27.0 SDK.
- The simulator XCTest suite passed 53 tests with zero failures on destination `C88E5129-768F-4C58-8DF3-ADA7D514FBD6`. Log: `/tmp/nuvio-tests-2.log`. Deterministic tests verify bounded ordered batching, cancellation, concurrent catalog request coalescing, cache expiry, and cache clearing.
- All 9,770 Swift source and test lines remain in files at or below 400 lines. The largest is `MPVPlayerController.swift` at 400 lines.
- `git diff --check` passed, and `graphify update` rebuilt a 14,229-node graph with 33,233 edges.

The installed SDK is tvOS 27.0. tvOS 26.6-specific availability was reviewed through Apple documentation, while compilation and runtime evidence in this pass comes from SDK 27.0 with a tvOS 18.0 deployment target. Directional focus, Back/Menu, VoiceOver, Larger Text, Reduce Motion, Reduce Transparency, cancellation under live navigation, and source switching still require a final physical Apple TV acceptance pass for this redesign.

## Security hardening

The initial port received a security and privacy review before this submission. The following issues were addressed in the contribution:

- Authentication token endpoints now build their URL with URLComponents so the Supabase grant_type query is delivered as a query. The earlier appending(path:) call percent-encoded the question mark and folded the grant type into the path, which broke email sign-in and token refresh.
- Concurrent access-token refresh is coalesced into a single task. Several sync stores call validAccessToken in parallel, and Supabase rotates the refresh token on use. Without coalescing, parallel callers raced on the same token and could invalidate the session.
- Sign out now clears the shared URL cache and removes the cross-account sync client identifier, so cached addon responses and the prior account correlation identifier do not survive a logout.
- Authentication sessions are stored in a Keychain generic password item with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.

## Current limitations and deferred follow-up

These areas are intentionally left for follow-up and are documented for reviewers:

- XCTest execution requires a compatible installed tvOS Simulator runtime. Test compilation and linking passed when runtime execution was unavailable.
- Profile PIN protection is not enforced. PIN-enabled profiles can be opened without a challenge.
- Addon base URLs, which can carry token query parameters, are stored in UserDefaults and mirror the mobile local storage pattern. Moving credential-bearing addon URLs to Keychain-backed storage is follow-up work.
- App Transport Security allows arbitrary loads to support legacy HTTP addon streams, matching the existing iOS app configuration. A narrower exception policy is follow-up work.
- Watch progress synchronization pulls a remote snapshot and pushes the merged local array. Records deleted on another client can reappear until the shared deletion contract is implemented.
- TMDB and Trakt collection sources decode but are not resolved. Folders backed only by those providers render as empty until the resolvers are implemented.
- Anime Skip synchronization reads the client identifier from the profile settings blob. The current mobile contract separates that credential into a provider credential flow, so the identifier may not be located until that flow is ported.
- Next-episode autoplay remains deferred.
- Tracking-provider scrobble synchronization remains deferred.
- Torrent and P2P playback remains deferred.
- A PrivacyInfo.xcprivacy manifest and full App Store licensing and acknowledgements review remain before any public release.

## Reproduction

Public setup and validation commands are documented in `tvosApp/README.md`. Device installation is documented through `scripts/run-tvos.sh`, with private values supplied through environment variables.
