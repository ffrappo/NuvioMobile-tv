# tvOS 27 platform audit receipt

Reviewed: 2026-08-13

## Toolchain

- Xcode 27.0, build `27A5228h`, and AppleTVOS 27.0 SDK interfaces reviewed to verify availability and the next-SDK interruption replacement
- Apple tvOS 26.6 release notes state that the tvOS 26.6 SDK ships with Xcode 26.6
- current Apple Support article 102337, published May 15, 2026, reviewed for Siri Remote transport and volume behavior
- current Apple TV User Guide volume-control article reviewed under its `/26/tvos/26` content route
- current Apple DocC JSON reviewed for `outputVolume`, `.playback`, `setActive`, interruption notifications, `AVRoutePickerView`, and `MPRemoteCommandCenter`
- Deployment target: tvOS 18.0
- XcodeGen 2.45.4

## Apple sources reviewed

- [Designing for tvOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos)
- [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [Top Shelf](https://developer.apple.com/design/human-interface-guidelines/top-shelf)
- [Collections](https://developer.apple.com/design/human-interface-guidelines/collections)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [What’s new in SwiftUI, WWDC25 session 256](https://developer.apple.com/videos/play/wwdc2025/256/)
- [Optimize SwiftUI performance with Instruments, WWDC25 session 306](https://developer.apple.com/videos/play/wwdc2025/306/)
- [TV Services](https://developer.apple.com/documentation/tvservices)
- [TVTopShelfContentProvider](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)
- [TVTopShelfSectionedContent](https://developer.apple.com/documentation/tvservices/tvtopshelfsectionedcontent)
- [TVTopShelfSectionedItem](https://developer.apple.com/documentation/tvservices/tvtopshelfsectioneditem)
- [TVTopShelfItem](https://developer.apple.com/documentation/tvservices/tvtopshelfitem)
- [TVTopShelfAction](https://developer.apple.com/documentation/tvservices/tvtopshelfaction)
- [CardButtonStyle](https://developer.apple.com/documentation/swiftui/cardbuttonstyle)
- [tvOS 26.6 release notes](https://developer.apple.com/documentation/tvos-release-notes/tvos-26_6-release-notes)
- [Apple TV 4K volume control](https://support.apple.com/guide/tv/apple-tv-4k-remote-control-receiver-atvbbe2477c9/tvos)
- [AVAudioSession outputVolume](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume)
- [AVAudioSession playback category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback)
- [AVAudioSession setActive](https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:))
- [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [AVRoutePickerView](https://developer.apple.com/documentation/avkit/avroutepickerview)
- [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter)

Installed SDK headers were also reviewed in:

- `$(xcrun --sdk appletvos --show-sdk-path)/System/Library/Frameworks/TVServices.framework/Headers`
- `$(xcrun --sdk appletvos --show-sdk-path)/System/Library/Frameworks/AVFAudio.framework/Headers`
- `$(xcrun --sdk appletvos --show-sdk-path)/System/Library/Frameworks/UIKit.framework/Headers/UIPress.h`

## Decisions

- Use SwiftUI `CardButtonStyle` for focusable artwork and row cards. Apple recommends system-provided focus effects; custom focus effects are reserved for cases where system effects cannot express the interaction.
- Keep the Home hero as a full-screen direct-content interaction. It is the one `.plain` button exception because the focus target fills the cinematic surface and the CTA provides selection feedback.
- Use a sectioned Top Shelf extension with stable `type.id` identifiers, poster images, and display actions that open `nuvio://details` URLs.
- Omit Top Shelf `playAction` until Nuvio can guarantee direct playback without presenting source selection. A details deep link is a display action, not a play action.
- Return `nil` when dynamic Top Shelf loading fails so tvOS presents the branded static fallback image.
- Resolve Increase Contrast and Reduce Transparency in one root environment palette. Material surfaces become opaque under either accessibility preference.
- Generate layered icon and Top Shelf fallback assets from the repository's original `NuvioLogo` file. No logo is recreated from memory.
- Treat tvOS 26.6 system output volume as user-owned. Apple documents `AVAudioSession.outputVolume` as the systemwide volume set by the user, and Apple TV routes Siri Remote volume through its Remotes and Devices configuration using Auto, HDMI-CEC, receiver IR, TV IR, or a learned device. Nuvio exposes no local volume control and pins MPV to unity gain.
- Keep `.playback` with `.moviePlayback` and activate the session after MPV initializes. This declares nonmixable movie playback and does not set output volume. Deactivate on teardown with `.notifyOthersOnDeactivation`.
- Pause MPV when the system interrupts the audio session. Resume only when playback was active before the interruption and the system recommends resumption. Use `AVAudioSession.interruptionNotification` on tvOS 26.6 and the replacement deactivation and resumption notifications on tvOS 27.
- Keep `AVRoutePickerView` as system route-selection UI. Apple documents it as a receiver picker, and route selection is separate from app-owned gain.
- Register custom MPV transport through `MPRemoteCommandCenter`. The current `UIPress.PressType` surface has no volume-up or volume-down case, so the app cannot consume Siri Remote volume events.
- Use a dedicated Discover root for catalog browsing and preserve Search for explicit queries. Home rails and catalog grids share provider-aware descriptors so details continue through the addon that supplied the title.
- Cap addon catalog and source fan-out at three, publish completed batches incrementally, and make every view-owned request cancellable. Repositories coalesce identical in-flight work and use bounded caches.
- Preserve stable focus identity while async results arrive. Use lazy stacks and grids, `.card` for artwork, `.bordered` controls for secondary actions, and `focusSection` to keep remote movement predictable.
- Reserve a 360-point leading exclusion zone for every root tab while the sidebar is expanded. A 1920 by 1080 simulator receipt confirmed that the hero title, description, CTA, and catalog rail remain outside the system sidebar.
- Keep regular seasons in ascending order and place Specials last. Restore the last focused episode independently for each season.
- Show compatible and incompatible stream sources together. Disable unsupported playback while retaining a concise reason instead of hiding the source.

## Catalog and performance receipt

The redesign uses four small actor-backed coordination points:

- `CatalogRepository`: provider-aware pages, ten-minute cache, request coalescing, actual returned page sizes, deduplication, and repeated-page termination.
- `DetailsRepository`: provider-aware metadata, fifteen-minute cache, and in-flight coalescing.
- `StreamRepository`: ordered per-addon publication and duplicate request coalescing.
- `ArtworkLoader`: duplicate fetch coalescing, ImageIO thumbnail decoding, and bounded memory cost.

Home, Discover, Search, collections, and sources publish useful partial content before all providers finish. JSON response decoding executes in detached work rather than on UI-isolated tasks. These changes remove the previously confirmed structural freeze risks. A literal cooperative-pool deadlock was not reproduced and is not claimed. Final Time Profiler, SwiftUI body-update, network, and cancellation measurements remain part of physical-device acceptance.

## Provider receipts

Both public catalog requests were reviewed on 2026-08-13:

- `https://v3-cinemeta.strem.io/catalog/movie/top.json`
- `https://v3-cinemeta.strem.io/catalog/series/top.json`

Observed response contract:

- HTTP `307` to `cinemeta-catalogs.strem.io`, followed by HTTP `200`
- `Cache-Control: public, max-age=10800`
- JSON object with `metas` entries containing `id`, `type`, `name`, `poster`, and `background`

The extension uses an ephemeral `URLSession`, 5-second request timeout, 8-second resource timeout, cache-first request policy, parallel requests, and ten items per section.

## Validation contract

A complete Debug generic-tvOS build must prove:

- asset catalog compiles with no app-icon or Top Shelf warnings
- `NuvioTopShelf.appex` embeds in `Nuvio.app/PlugIns`
- `ValidateEmbeddedBinary` succeeds
- built app declares `nuvio` under `CFBundleURLTypes`
- extension declares `com.apple.tv-top-shelf` and the correct principal class
- all source files remain at or below 400 lines

## Validation results

Completed on 2026-08-13:

- generic tvOS Debug build succeeded with signing disabled
- the current tvOS 27 simulator suite passed 54 tests with zero failures after the catalog, detail, source, artwork, player-control, playback-volume, and interruption corrections
- scheme-level `build-for-testing` succeeded
- asset compilation, extension embedding, and `ValidateEmbeddedBinary` succeeded
- live Cinemeta movie and series catalog decoding succeeded
- a signed development build installed and launched on an Apple TV running tvOS 26.6
- a `nuvio://details` display action launched the installed app and the process remained healthy
- the physical-device XCTest suite passed 30 tests with zero failures
- the outgoing nine-commit range passed `gitleaks` with zero findings
- changed Swift, test, and Python source files remain at or below 400 lines
- `graphify update` completed with 14,229 nodes, 33,233 edges, and 710 communities
- simulator visual review confirmed the large Home hero, loaded catalog rail, See All action, and expanded-sidebar content exclusion at 1920 by 1080

Physical screen review remains the final human acceptance step for Top Shelf placement, native card tilt, directional focus, Back/Menu behavior, VoiceOver, Larger Text, Increase Contrast, Reduce Motion, Reduce Transparency, Siri Remote transport, cancellation during navigation, and the TV or receiver volume route. CoreDevice screenshot capture returned error `25004`, so automated evidence does not include a new physical television screenshot for this redesign.
