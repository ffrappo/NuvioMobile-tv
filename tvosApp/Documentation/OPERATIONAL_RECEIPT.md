# Nuvio native tvOS operational receipt

Reviewed: 2026-08-11, Europe/Rome

## Toolchain

- XcodeGen 2.45.4
- Xcode 27.0, build 27A5228h
- AppleTVOS 27.0 SDK
- Apple Swift 6.4 compiler, app language mode Swift 5
- CoreDevice `devicectl` 642.4
- Deployment target tvOS 17.0

Installed help reviewed before implementation:

- `xcodegen help generate`
- `xcrun devicectl help list devices`
- `xcrun devicectl help device install app`
- `xcrun devicectl help device process launch`
- Installed AppleTVOS SDK Swift interfaces for `NavigationStack`, `defaultFocus`, `focusable`, `onPlayPauseCommand`, `onExitCommand`, and URLSession `data(for:)`

## Official documentation

- Apple SwiftUI focus: https://developer.apple.com/documentation/swiftui/focus
- Apple navigation stack: https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack
- Apple AVPlayerViewController: https://developer.apple.com/documentation/avkit/avplayerviewcontroller
- Apple tvOS playback experience: https://developer.apple.com/documentation/avkit/customizing-the-tvos-playback-experience
- XcodeGen project spec: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
- XcodeGen repository and versioned usage: https://github.com/yonaskolb/XcodeGen
- Stremio addon protocol: https://stremio.github.io/stremio-addon-sdk/protocol.html
- Stremio manifest format: https://stremio.github.io/stremio-addon-sdk/api/responses/manifest.html
- Stremio stream guide: https://stremio.github.io/stremio-addon-guide/step5

## Provider probes

The exact production coordinates used by the app were probed before implementation.

`GET https://v3-cinemeta.strem.io/manifest.json`

```json
{"id":"com.linvo.cinemeta","version":"3.0.14","description":"The official addon for movie and series catalogs","name":"Cinemeta","resources":["catalog","meta","addon_catalog"],"types":["movie","series"],"idPrefixes":["tt"]}
```

The raw manifest also declared movie and series catalog IDs `top`, `year`, and `imdbRating`. The app uses the declared `top` entries for Home and search.

`GET https://v3-cinemeta.strem.io/catalog/movie/top.json`

```text
HTTP/1.1 307 Temporary Redirect
Location: https://cinemeta-catalogs.strem.io/top/catalog/movie/top.json
```

Following the redirect returned a JSON `metas` array. URLSession follows this redirect automatically.

`GET https://v3-cinemeta.strem.io/catalog/movie/top/search=matrix.json`

```json
{"metas":[{"id":"tt0133093","type":"movie","name":"The Matrix","releaseInfo":"1999"},{"id":"tt0234215","type":"movie","name":"The Matrix Reloaded","releaseInfo":"2003"}]}
```

`GET https://v3-cinemeta.strem.io/meta/series/tt0903747.json`

```json
{"meta":{"id":"tt0903747","type":"series","name":"Breaking Bad","releaseInfo":"2008–2013","genres":["Crime","Drama","Thriller"],"videos":[{"name":"Pilot","season":1,"number":1,"id":"tt0903747:1:1","episode":1}]}}
```

`GET https://v3-cinemeta.strem.io/stream/movie/tt0133093.json`

```text
HTTP 404
```

This matches the manifest, which does not declare `stream`. Cinemeta is therefore always used for catalogs and metadata but is never fabricated as a stream provider.

## Verification record

- `xcodegen generate --spec tvosApp/project.yml`: passed
- Generic Apple TV device Debug build with signing disabled: passed
- Signed Apple TV Debug build with team `2V6YSU4HFB` and profile `Nuvio tvOS Development`: passed
- MPVKit GPL and FFmpeg tvOS device integration: passed; binary includes libmpv, VideoToolbox, MoltenVK, libplacebo, libass, and bundled codec libraries
- Physical install and launch on Seminterrato (`AppleTV5,3`, tvOS 26.6): passed
- Installed app process remained active and a 1920x1080 device screenshot was captured
- QR account session start and pending poll against production `api.nuvio.tv`: passed
- Normal email login, refresh-token persistence, logout, guest mode, and account addon pull are implemented
- Apple Developer device registration: Seminterrato Apple TV, UDID `1898a6294f5a4b53e919fa2425a792533388465e`, enabled
- App identifier registration: `com.nuviace.app.tvos`, universal, team `2V6YSU4HFB`
- Generic Apple TV test build: passed
- Runtime unit-test execution: unavailable because no tvOS simulator runtime is installed
- Physical device deployment: passed; the signed MPV build is at `build/tvos-mpv-derived/Build/Products/Debug-appletvos/Nuvio.app`

The install script builds with the local `MPVKit` package, installs on Seminterrato, and launches Nuvio. The Apple TV required removal of an unused large game before the first install because tvOS reported its app quota as full.
