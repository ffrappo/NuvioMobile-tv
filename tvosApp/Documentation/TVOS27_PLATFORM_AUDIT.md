# tvOS 27 platform audit receipt

Reviewed: 2026-08-13

## Toolchain

- Xcode 27.0, build `27A5228h`
- Apple tvOS SDK 27.0
- Deployment target: tvOS 18.0
- XcodeGen 2.45.4

## Apple sources reviewed

- [Designing for tvOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos)
- [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [Top Shelf](https://developer.apple.com/design/human-interface-guidelines/top-shelf)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [TV Services](https://developer.apple.com/documentation/tvservices)
- [TVTopShelfContentProvider](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)
- [TVTopShelfSectionedContent](https://developer.apple.com/documentation/tvservices/tvtopshelfsectionedcontent)
- [TVTopShelfSectionedItem](https://developer.apple.com/documentation/tvservices/tvtopshelfsectioneditem)
- [TVTopShelfItem](https://developer.apple.com/documentation/tvservices/tvtopshelfitem)
- [TVTopShelfAction](https://developer.apple.com/documentation/tvservices/tvtopshelfaction)
- [CardButtonStyle](https://developer.apple.com/documentation/swiftui/cardbuttonstyle)

Installed SDK headers were also reviewed in:

`$(xcrun --sdk appletvos --show-sdk-path)/System/Library/Frameworks/TVServices.framework/Headers`

## Decisions

- Use SwiftUI `CardButtonStyle` for focusable artwork and row cards. Apple recommends system-provided focus effects; custom focus effects are reserved for cases where system effects cannot express the interaction.
- Keep the Home hero as a full-screen direct-content interaction. It is the one `.plain` button exception because the focus target fills the cinematic surface and the CTA provides selection feedback.
- Use a sectioned Top Shelf extension with stable `type.id` identifiers, poster images, and display actions that open `nuvio://details` URLs.
- Omit Top Shelf `playAction` until Nuvio can guarantee direct playback without presenting source selection. A details deep link is a display action, not a play action.
- Return `nil` when dynamic Top Shelf loading fails so tvOS presents the branded static fallback image.
- Resolve Increase Contrast and Reduce Transparency in one root environment palette. Material surfaces become opaque under either accessibility preference.
- Generate layered icon and Top Shelf fallback assets from the repository's original `NuvioLogo` file. No logo is recreated from memory.

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
