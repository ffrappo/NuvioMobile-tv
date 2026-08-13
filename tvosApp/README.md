# Native Apple TV app

The `tvosApp` directory contains an initial native SwiftUI port for Apple TV. It is intentionally separate from the Compose mobile app because the Compose version used by this repository does not provide the tvOS UI and Foundation targets required by the app.

The port is functional and has been tested on physical hardware. It is an early contribution with room for focused polish and broader testing. Contributions to navigation, accessibility, playback, synchronization, and platform parity are welcome.

## Current scope

Implemented:

- phone-first QR sign-in, email sign-in, and guest mode
- account profiles, library, collections, addons, Home preferences, and progress synchronization
- Home, Discover, Search, Library, details, seasons, episodes, and progressively published stream selection
- provider-aware catalogs with See All grids, genre filtering, caching, request coalescing, bounded addon fan-out, and pagination
- collection and Home catalog sources resolved through the same catalog model, with dedicated routed collection and folder browsing
- native tvOS focus and navigation, including system card focus effects and per-season episode focus restoration
- dynamic Top Shelf rows with stable deep links plus branded static fallback artwork
- MPV playback, request headers, Now Playing controls, subtitles, audio tracks, speed, video sizing, source switching, and manual episode selection
- Reduce Motion, Increase Contrast, Reduce Transparency, Larger Text, and VoiceOver-aware controls
- addon management and playback integration settings

Planned follow-up work is listed in [CONTRIBUTING.md](CONTRIBUTING.md).

See [Documentation/TVOS27_PLATFORM_AUDIT.md](Documentation/TVOS27_PLATFORM_AUDIT.md) for the current Apple API review, implementation decisions, provider receipts, and validation contract. User-visible changes are recorded in [CHANGELOG.md](CHANGELOG.md).

## Requirements

- macOS with Xcode 27 or a compatible Xcode release that includes the tvOS 27 SDK
- XcodeGen
- an Apple Developer team for physical-device signing
- the repository submodules, including `MPVKit`
- an Apple TV connected to the Mac through a USB-C cable for the documented device workflow

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

Clone the repository with submodules, or initialize them in an existing checkout:

```sh
git submodule update --init --recursive
```

## Generate the Xcode project

The checked-in Xcode project is generated from `tvosApp/project.yml`. Update the specification first, then regenerate:

```sh
xcodegen generate --spec tvosApp/project.yml
```

The specification uses public development defaults:

- `TVOS_BUNDLE_IDENTIFIER = com.nuvio.app.tvos.dev`
- `TVOS_TEST_BUNDLE_IDENTIFIER = com.nuvio.app.tvos.dev.tests`

Override these as Xcode build settings when signing with your own Apple Developer account. Generated project changes should match the specification change that produced them.

## Build without signing

A generic build verifies the app and package integration without requiring private signing values:

```sh
xcodegen generate --spec tvosApp/project.yml

xcodebuild \
  -project tvosApp/NuvioTV.xcodeproj \
  -scheme NuvioTV \
  -configuration Debug \
  -destination 'generic/platform=tvOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Run on a physical Apple TV through USB-C

1. Connect the Apple TV to the Mac with a USB-C cable.
2. Wake the Apple TV and approve trust or developer prompts in Xcode if requested.
3. Confirm that CoreDevice can see it:

```sh
xcrun devicectl list devices
```

4. Copy the device identifier from that output.
5. Set your signing values and run the helper:

```sh
export TVOS_DEVICE_ID='YOUR-DEVICE-IDENTIFIER'
export TVOS_DEVELOPMENT_TEAM='YOURTEAMID'
export TVOS_BUNDLE_IDENTIFIER='com.example.nuvio.tvos'
./scripts/run-tvos.sh
```

The helper generates the project, builds the signed app, installs it through CoreDevice, and launches it. It does not contain a developer team, provisioning profile, device name, device identifier, or personal bundle identifier.

## Tests

Build the test bundle with:

```sh
xcodebuild \
  -project tvosApp/NuvioTV.xcodeproj \
  -scheme NuvioTV \
  -configuration Debug \
  -destination 'generic/platform=tvOS' \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Run the unit and XCUI remote-navigation suites on an installed compatible tvOS simulator. The checked-in UI tests launch deterministic guest mode, expose the native root sidebar, exercise details Back/Menu navigation, and attach kept screenshots for expanded-sidebar geometry.

## Architecture

- `project.yml` is the project source of truth.
- `Sources/NuvioTVApp.swift` creates the app stores and services.
- `Sources/AppShellView.swift` owns Home, Discover, Search, Library, Addons, and Settings tabs plus details and catalog routes.
- `CatalogRepository`, `DetailsRepository`, `StreamRepository`, and `ArtworkLoader` coalesce repeated requests and isolate provider-aware loading.
- Home, Discover, Search, Library, collections, and catalog grids reuse stable native poster and rail components.
- service and store files own account, addon, collection, profile, catalog, and progress behavior.
- player files own MPV, Metal output, controls, menus, Now Playing integration, and progress persistence.
- `Tests/StremioServiceTests.swift`, `CatalogModelTests.swift`, `AsyncBatcherTests.swift`, `ArtworkLoaderTests.swift`, and `PlaybackCapabilityTests.swift` cover protocol decoding, provider-aware URL construction, catalog identity and pagination, coalescing, caching, bounded cancellation, playback capability gates, focus contracts, and progress persistence.
- `UITests/NuvioTVNavigationUITests.swift` drives `XCUIRemote` through root sidebar, details, and Back/Menu flows, with kept screenshots in `Documentation/Screenshots`.

See [PLAYER_PARITY.md](Documentation/PLAYER_PARITY.md) for the implemented playback matrix and intentional platform boundaries.

## Security and privacy

- Never commit signing teams, provisioning profile names, device names, device identifiers, or personal bundle identifiers.
- Treat provider URLs as user data. Do not add logs that expose addon tokens or full manifest URLs.
- Authentication sessions belong in Keychain-backed storage. See the contributor checklist before extending credential handling.
- Keep release signing and distribution configuration in maintainer-owned CI or Xcode settings.
