# Apple TV 2026 interface review and refinement

Reviewed: 2026-08-11

## Official guidance reviewed

The review used current official Apple design guidance and the installed Xcode 27.0, Swift 6.4, and AppleTVOS 27.0 SDK interfaces:

- [Designing for tvOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos)
- [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [Remotes](https://developer.apple.com/design/human-interface-guidelines/remotes)
- [Navigation and search](https://developer.apple.com/design/human-interface-guidelines/navigation-and-search)
- [Playing video](https://developer.apple.com/design/human-interface-guidelines/playing-video)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [SwiftUI focusSection](https://developer.apple.com/documentation/swiftui/focussection())
- [SwiftUI searchable](https://developer.apple.com/documentation/swiftui/searchable(text:placement:prompt:))

Installed SDK evidence confirmed that tvOS exposes `CardButtonStyle` from tvOS 14 and the `Tab` content API plus `SidebarAdaptableTabViewStyle` from tvOS 18. Nuvio now targets tvOS 18 so top-level navigation can use the native adaptive tab system.

## Expert review conclusions

### What was already strong

- Search used native `searchable`, which preserves the system keyboard and Siri Remote dictation.
- The MPV player used system Now Playing commands and retained the complete iOS player capability set.
- Core actions already used system bordered button styles.
- Home had clear media rails, useful resume metadata, and remote-readable artwork sizes.
- Network, account, profile, collection, skip-segment, and playback functionality was separated from view code.

### What needed refinement

- The hand-built 310-point sidebar reproduced behavior owned by the native tvOS tab system.
- Media cards manually recreated focus with borders, scale, shadows, foreground swaps, and disabled focus effects.
- Settings mixed account, profiles, Home organization, integrations, device diagnostics, and cache controls in one 295-line file.
- Sign-in presented email typing as the first path even though QR sign-in is faster from a living-room device.
- Addon status relied partly on green and orange text, and removal happened without confirmation.
- Empty, error, and status presentation varied between pages.
- Several shared controls carried a `focused` argument that had no effect.
- Some page focus defaults lived in nested components, creating competing ownership.

## Refinements applied

### App shell and navigation

`AppShellView.swift` now uses `TabView`, `Tab`, `.sidebarAdaptable`, and the search tab role. This removes the custom sidebar, its manual focus state, fixed width, focus sections, color calculations, and bespoke navigation button styling. The file fell from 153 lines to 61 lines.

### Shared UI

`NuvioControls.swift` now owns:

- the simplified system-styled `NuvioButton`;
- `NuvioPanel` for consistent material grouping;
- `NuvioPageHeader` for consistent page hierarchy;
- `NuvioUnavailableView` for native empty states;
- `NuvioStatusMessage` for icon plus text status communication.

The unused button `focused` argument and the custom bare card style were removed.

### Home, Search, and Library

Poster, progress, folder, episode, search, library, and source cards now use native `.card` button style. Manual focus borders, scale, shadows, foreground swaps, and focus-effect suppression were removed. Search keeps native dictation and now uses the shared actionable error state. Library uses the shared page header and unavailable state.

### Addons

Addon management now has a living-room-oriented page hierarchy, explicit URL-entry guidance for iPhone keyboard and dictation, a disabled Add button until input exists, icon plus text status messages, clearer capability descriptions, and destructive removal confirmation.

### Settings

Settings was reduced from one 295-line view to four focused files, each below 110 lines:

- `SettingsView.swift`
- `SettingsAccountSection.swift`
- `SettingsHomeSection.swift`
- `SettingsIntegrationsSection.swift`

The page now groups account and profile, Home preferences, playback integrations, and storage by user intent. Reorder actions disable at list boundaries. Device and version information moved to a concise storage footer.

### Account onboarding

Phone QR sign-in is now the primary path. Email and password entry appears through progressive disclosure. QR instructions are explicit and accessible, guest continuation remains available, and account restoration has a combined loading announcement.

### Details and sources

Episodes and sources use native card focus. Source errors use icon plus text status. Programmatic episode selection moves focus to the selected episode without adding a redundant focus scope.

### Player

The existing native-menu player redesign remains. Player errors moved into `PlayerErrorView.swift`, using the shared panel language and a contained accessibility structure.

## Code reduction

The refinement removed custom navigation and focus code while splitting dense settings and onboarding responsibilities. All Swift source files remain below the repository's 400-line limit. The total source count is 6,538 lines, including services, models, stores, and MPV integration.

## Verification

Completed on 2026-08-11:

- Generic tvOS Debug build with signing disabled: passed.
- tvOS Simulator `build-for-testing`: passed.
- Signed physical Apple TV Debug build for Seminterrato: passed.
- Installation on Seminterrato: passed.
- Launch on Seminterrato: passed.
- Running process confirmed as PID 1005.
- Source contract updated to require native adaptive tabs and search role.
- Every Swift source file is at or below 400 lines.

## Remaining device-only checks

A human should perform a complete Siri Remote pass on the television for subjective spatial behavior and legibility:

1. Move through every top-level tab and confirm return focus feels predictable.
2. Traverse Home rails in all directions and verify native card lift has no clipping.
3. Open system Search, dictate a query, select a result, and return.
4. Exercise empty and populated Library states.
5. Add and remove a test addon, including removal cancellation.
6. Change every Settings control and reorder the first, middle, and last Home sections.
7. Complete QR sign-in, email sign-in, and guest entry.
8. Traverse Details, episodes, sources, and player menus.
9. Test VoiceOver, Increase Contrast, Reduce Motion, and larger accessibility text.
10. Confirm player control reveal, auto-hide, scrub, Back behavior, and subtitle sheet with the Siri Remote.
