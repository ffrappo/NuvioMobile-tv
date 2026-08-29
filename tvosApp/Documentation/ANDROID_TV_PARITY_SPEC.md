# Android TV parity specification

Reviewed: 2026-08-29

## Decision

Nuvio for Apple TV will use the current Android TV application as its product and visual reference. The default target is the Android `HomeLayout.MODERN` experience. Classic and Grid remain later compatibility modes.

A faithful replica is feasible. The result can match screen composition, spacing, media geometry, typography, colors, gradients, artwork hierarchy, navigation destinations, focus targets, motion timing, loading states, and feature behavior. Platform-owned interactions remain native to tvOS:

- SwiftUI and UIKit own focus movement and Siri Remote routing.
- The system search field owns dictation and keyboard presentation.
- `MPRemoteCommandCenter` owns external transport commands.
- tvOS, HDMI-CEC, IR, or the selected receiver owns output volume.
- accessibility preferences can reduce motion, increase contrast, or remove transparency.
- system parallax and lighting can supplement the Nuvio focus ring.

This is a product-sized native port. It is not a theme change over the current shell.

## Reference receipt

### Android source

- Repository: `https://github.com/NuvioMedia/NuvioTV`
- Branch: `dev`
- Pulled on: 2026-08-29
- Commit: `eca648a86de8021a47299549d6dedbf0420b7188`
- Commit subject: `perf: use offscreen compositing for gradient overlays`
- Release tags visible at review: through `0.8.10-beta`
- Stack: Kotlin, Jetpack Compose, Android TV Material 3, Media3

The previous local checkout was the shallow `0.8.4-beta` snapshot at `88517217`. Pulling current `dev` added about 31,000 lines across Home, profiles, focus, themes, details, search, library, source selection, player overlays, and post-play.

### Runtime visuals

Official screenshots were reviewed from the current Play Store page:

- `https://play.google.com/store/apps/details?id=com.nuvio.app`
- Store update date observed: 2026-08-25
- TV screenshots reviewed at 1920 by 1080 class resolution: profile selection, Modern Home, sidebar Home, details, and player-facing title actions

The Play Store listing mixes phone and television images. Only the five 16:9 images are television references.

### Apple sources

Reviewed on 2026-08-29:

- `https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos`
- `https://developer.apple.com/design/human-interface-guidelines/focus-and-selection`
- `https://developer.apple.com/design/human-interface-guidelines/remotes`
- `https://developer.apple.com/design/human-interface-guidelines/collections`
- `https://developer.apple.com/design/human-interface-guidelines/playing-video`
- `https://developer.apple.com/videos/play/wwdc2025/256/`
- `https://developer.apple.com/videos/play/wwdc2025/306/`

Installed toolchain:

- Xcode 27.0, build `27A5228h`
- AppleTVOS SDK 27.0
- Swift 6.4, app compiled in Swift 5 language mode

## Scale of the current gap

At the reviewed commits:

| Surface | Android TV | Apple TV |
| --- | ---: | ---: |
| UI source files | 316 Kotlin files | 78 Swift source files |
| UI or app source lines | about 136,000 UI Kotlin lines | about 9,400 Swift lines |
| screen entry files | 39 `*Screen.kt` files | 21 files declaring a SwiftUI view or screen |
| navigation destinations | over 30 routes | 6 roots and 3 pushed routes |

The Apple TV app has a credible native foundation: account sync, addon catalogs, Home data, search fan-out, details, episodes, source selection, MPV playback, progress, native focus, Top Shelf, and player transport. It implements a thin presentation subset of the current Android product.

## Android design source of truth

### Primitives

Port these values from `app/src/main/java/com/nuvio/tv/ui/theme/` into native Swift tokens.

| Token | Android value | Apple TV target |
| --- | --- | --- |
| canvas | `#000000` / `#0D0D0D` | exact |
| elevated surfaces | `#1A1A1A`, `#242424` | exact |
| secondary text | `#B3B3B3` | exact unless contrast requires brighter text |
| focus stroke | 2 dp | 2 pt brand overlay plus native focus depth |
| poster | 126 by 189 | 126 by 189 design units, scaled for tvOS safe area |
| backdrop | 320 by 180 | exact 16:9 ratio and relative size |
| episode | 320 by 207 | exact relative geometry |
| poster radius | 12 | 12 pt |
| backdrop radius | 16 | 16 pt |
| side panel radius | 20 | 20 pt |
| settings container radius | 28 | 28 pt |
| screen safe margin | 48 horizontal, 24 vertical | exact at 1920 by 1080 |
| rail item gap | 12 | exact |
| rail row gap | 24 | exact |
| focus scale | 1.02 | exact brand scale, with native parallax preserved |
| pressed scale | 0.98 | exact |
| focus transition | 180 ms | exact unless Reduce Motion is enabled |
| medium transition | 350 ms | exact |
| hero transition | 450 ms | exact |
| shimmer cycle | 1200 ms | exact |
| soft blur | 12 | equivalent SwiftUI blur |
| panel blur | 26 | material plus controlled blur |
| strong blur | 40 | equivalent where GPU cost is acceptable |

Source files:

- `PrimitiveTokens.kt`
- `SpacingTokens.kt`
- `SizeTokens.kt`
- `ShapeTokens.kt`
- `MotionFocusTokens.kt`
- `StrokeElevationEffectTokens.kt`
- `LayoutMediaTokens.kt`
- `ComponentTokens.kt`
- `FocusRingStyle.kt`
- `Theme.kt`
- `Type.kt`

### Typography

Android defaults to Inter and offers DM Sans and Open Sans. Its token hierarchy is 48/56 display, 36/44 compact display, 28/36 headline, 24/32 section title, 16/24 card title and body, 14/20 compact body, and 12/16 metadata.

Apple TV should bundle the same variable font assets for brand typography. System controls can continue using San Francisco where tvOS owns their presentation. Artwork title logos take priority over rendered title text when providers expose them.

### Focus and motion

The Android grammar uses a theme-colored or gradient 2-point focus ring, 1.02 scale, focused elevation, high-contrast button inversion, and explicit destination restoration. Apple TV will use the native focus engine and add the same Nuvio ring, scale, surface color, and motion timing. System parallax, lighting, touch-surface tilt, VoiceOver, and Reduce Motion remain active.

Focus parity includes destination and restoration behavior, not only appearance. Returning from details must restore the exact row, item, and scroll offset. Back from a row can return to its header or navigation surface according to the Android route contract. Replacing content during loading must preserve the focused identity.

## Screen parity matrix

| Area | Android source | Current Apple TV gap | Target |
| --- | --- | --- | --- |
| Root shell | `MainActivity.kt`, `NuvioNavHost.kt`, `SidebarNavigation.kt`, `ModernSidebarBlurPanel.kt` | system `TabView` sidebar with six roots, no Android top-nav or modern sidebar mode | shared route coordinator, Modern floating top navigation, optional sidebar mode, exact focus restoration |
| Home | `ModernHomeContent.kt`, `ModernHomeHero.kt`, `ModernHomeRows.kt`, `HeroCarousel.kt` | simple rotating hero and catalog rails | full-bleed hero scene, title logos, metadata badges, trailer/backdrop transitions, pagination, dynamic focused-card expansion, Continue Watching, Upcoming, collections, rows |
| Home modes | `ClassicHomeContent.kt`, `GridHomeContent.kt`, layout preference store | one fixed layout | Modern default, then Classic and Grid preferences |
| Poster cards | `ContentCard.kt`, `GridContentCard.kt`, `CardDepthEffect.kt` | native card with limited status and metadata | poster labels, year, watched/library badge, progress, focus ring, depth, backdrop expansion, long-press options |
| Search | `SearchScreen.kt`, `SearchViewModel.kt`, `SearchDiscoverSection.kt` | system field plus flat merged grid, separate Discover root | recent searches, provider suggestions, native keyboard completions, voice-reactive presentation around system dictation, per-catalog result rails, integrated Discover, persisted selection |
| Details | `MetaDetailsScreen.kt`, `HeroSection.kt` and detail sections | hero, facts, credits, episodes | title logo, primary actions, ratings, cast, writers/directors, trailers, more-like-this, collection, companies, comments, episode ratings, section tabs and focus map |
| Episodes | `EpisodesSection.kt`, `EpisodeOptionsOverlay.kt` | season selector and episode cards | watched states, ratings, episode options, layout styles, cross-season focus rules, comments and metadata |
| Library | `LibraryScreen.kt`, `LibraryViewModel.kt` | flat saved grid | Saved, Trakt, and cloud modes, type/list tabs, provider filters, local search, genre/year/watched filters, sort, personal-list management, focus persistence |
| Collections | collection screens and folder view models | synced collection browsing | management, editor, source pickers, tabbed grid, follow-layout rendering, exact focus state |
| Profiles | `ProfileSelectionScreen.kt`, background and editor components | profile selector inside Settings | startup gateway, primary/locked badges, backgrounds, add/manage, editor tabs, inheritance, transactional profile switch |
| Themes | `Theme.kt`, `ThemeColors.kt`, supporter palettes, settings | one adaptive dark palette | White plus supported color themes, Inter/DM Sans/Open Sans, focus gradients, branding assets, accessibility variants |
| Settings | settings design system and route files | account, Home, integrations, cache | full two-pane settings IA, layout, theme, playback, subtitle, audio, network, providers, tracking, diagnostics, about |
| Addons | addon manager and catalog order screens | add/remove manifest URL | enabled state, order, names, catalog order, credentials, plugin surfaces, stable account sync |
| Sources | `StreamScreen.kt`, `StreamSourcesSidePanel.kt`, stream components | grid and addon filters | background/title context, status filters, autoplay states, badges, sorting, file info, restore selection, side-panel focus behavior |
| Player | `PlayerScreen.kt`, overlay scaffold and side panels | native MPV controls, timeline, track/source/episode panels, skip | exact bottom chrome, pause/loading artwork, stream info, debug HUD, next episode, side panels, source restore, subtitle timing/style, contextual actions |
| Post-play | post-play controller, state, player window, overlay | absent | recommendation paging, trailer prefetch/player window, ratings, countdown/timing, details and play actions, focus retention |

## Current visual defects to remove

The current Apple TV screenshots show issues that are independent of missing feature breadth:

- hero text can inherit dark artwork colors and lose contrast;
- the hero artwork composition can show bright vertical edge bands instead of blending into the black canvas;
- the hero lacks title logos, metadata hierarchy, page indicators, and controlled directional gradients;
- catalog cards are much larger and sparser than the Android 126 by 189 grammar;
- section labels and provider/type context do not follow Android hierarchy;
- navigation consumes a large opaque sidebar region and changes the intended cinematic composition;
- loading and partial-failure status surfaces compete with the hero;
- focus behavior is native, but branded ring, glow, elevation, label motion, and restoration state are incomplete.

## Architecture for the port

### Design foundation

Create small Swift files, each below 400 lines:

- `NuvioDesignTokens.swift`: color, spacing, size, shape, and media tokens.
- `NuvioTypography.swift`: bundled Inter/DM Sans/Open Sans and semantic styles.
- `NuvioMotion.swift`: timing, easing, reduced-motion resolution.
- `NuvioFocusStyle.swift`: brand ring, scale, glow, pressed state, accessibility.
- `NuvioArtworkView.swift`: poster/backdrop/logo loading, stale-while-revalidate, downsampling, transition.
- `NuvioLoadingViews.swift`: shimmer and skeleton grammar.

### Product state

The current view-owned stores need a shared presentation contract before screen expansion:

- one app route coordinator;
- one profile transaction that switches every profile-scoped store together;
- persisted screen, row, item, and scroll focus state;
- complete profile and layout preference models;
- provider-aware metadata enrichment for title logos, ratings, cast, trailers, and recommendations;
- addon enabled/order/name preservation;
- stable player and post-play session state.

### Rendering boundaries

- Keep image decode, JSON decode, sorting, deduplication, and presentation building outside the main actor.
- Publish immutable presentation snapshots to SwiftUI.
- Keep visible rows lazy and cap simultaneous artwork decode.
- Use Instruments 26 SwiftUI body-update and hitch analysis for every milestone.
- Preserve cancellation for changing profile, query, route, or focused hero.

## Implementation waves

### Wave 1: visual foundation and Modern Home

1. Port design, typography, motion, and focus tokens.
2. Replace the root visual shell with the Modern navigation composition while retaining native focus semantics.
3. Rebuild Home using a full-bleed hero scene and dense Android-sized rails.
4. Add title-logo and metadata enrichment.
5. Add focus restoration, pagination, watched/library badges, progress, and shimmer.
6. Validate at 1920 by 1080 against official Android screenshots and on physical Apple TV.

This wave delivers the largest visible improvement and establishes reusable primitives for every later screen.

### Wave 2: details, search, library, collections

1. Port the details section map and presentation model.
2. Port Android Search behavior around native tvOS dictation and keyboard suggestions.
3. Port Library modes, filters, sorting, and list management.
4. Port collection management and follow-layout folder rendering.

### Wave 3: source selection and player

1. Recompose source selection using Android context, filters, badges, sorting, and focus restoration.
2. Match player chrome and overlay state priority.
3. Add loading, pause, stream-info, stats, next-episode, and contextual side panels.
4. Add the post-play recommendation system.

### Wave 4: profiles, settings, themes, addon management

1. Add the startup profile gateway and transactional profile switching.
2. Port full profile schema, backgrounds, editor, locks, inheritance, and cosmetics.
3. Port layout, theme, playback, subtitle, audio, network, integration, and diagnostics settings.
4. Port enabled/order/name-safe addon management and provider credential contracts.
5. Add Classic and Grid layout modes.

## Parity acceptance

A screen reaches parity only when all of these pass:

1. **Composition:** 1920 by 1080 screenshot overlay matches the Android reference for safe margins, hierarchy, media geometry, and gradients.
2. **State:** loading, empty, partial, error, focused, pressed, watched, saved, disabled, and offline states match the reference contract.
3. **Motion:** focus, hero, panel, shimmer, and content transition timings match, with a Reduce Motion variant.
4. **Focus:** every destination and return path is deterministic with the Siri Remote and VoiceOver.
5. **Performance:** no long SwiftUI body update or interaction hitch appears in Instruments for the tested route.
6. **Accessibility:** labels, values, contrast, Reduce Transparency, Increase Contrast, and Larger Text remain usable.
7. **Platform ownership:** search/dictation, transport, volume, Menu/Back, route selection, and system interruptions remain native.
8. **Regression:** generic tvOS Debug build, complete unit suite, UI navigation suite, physical install, and physical Siri Remote checks pass.

## Feasibility verdict

A highly faithful Apple TV replica is achievable. The correct target is the same Nuvio product rendered with native tvOS mechanics, not an Android binary or Compose UI transplanted to tvOS.

The first milestone should be the design foundation plus Modern Home. It addresses the visible quality gap immediately and creates the primitives required for the rest of the port. Full product parity requires all four waves because Android’s advantage comes from its state models and screen breadth as much as from gradients and effects.
