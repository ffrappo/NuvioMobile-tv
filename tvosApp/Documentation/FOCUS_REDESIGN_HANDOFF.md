# TVOS Focus Redesign Handoff

Date: 2026-08-11 (reconciled)
Author: pi session (Home focus visibility)
Status: Two sessions converged and diverged. The tree is committed and builds green, but the final committed state reintroduces the exact bug that triggered this work. See Recommendation below.

## What the user reported

On the Home screen, in the content rows below the hero, the selected (focused) card was not visible at all. Reproduction: dark background, poster cards, navigate between items in a rail.

## Root cause

The cards express focus only with a scale bump (1.06) and a black drop shadow. On the near-black background (`NuvioTheme.background = 0.035, 0.035, 0.045`) a black shadow is invisible, and a 1.06 scale on a 220 x 320 poster is too subtle to register. The poster stroke is a constant hairline (`Color.white.opacity(0.12)`) that never changes on focus. Net effect: no visible selection cue.

## Timeline of the two efforts

### Shared round 1 (committed, on device)
`ff2fdd25` redesigned the title details screen. Safe, kept.

### Session A (this session): visible Home focus
Goal: make the selected Home card clearly visible, Apple style, no accent colors.

Changed `PosterCard`, `ProgressCard`, and `FolderCard` to show a solid white 3pt stroke, a white elevation glow, and a larger scale when focused. Added a `focused` state to `FolderCard`, which previously had no focus treatment at all, and wired it in `CatalogView`. Files: `HomeCatalogViews.swift`, `HomePersonalViews.swift`, `CatalogView.swift`.

### Session B (concurrent): native focus and system controls
`bacb3af6` "adopt native focus and text input": replaced accent rings with neutral treatment, moved `NuvioButton` to system `.bordered`/`.borderedProminent` styles, kept `NuvioBareButtonStyle`, rewrote `SearchView` to the system `.searchable` flow, removed `NuvioFocusBorder`, changed the progress bar fill from accent to white, and removed the accent from the theme. This commit also carried the same white 3pt focus border on the Home cards.

`90e6ffe9` "remove poster focus border": removed the white focus border from `PosterCard`, back to a constant hairline plus black shadow and 1.06 scale.

`55ecce7f` "remove residual focus rings": removed the white focus borders from `ProgressCard` and `FolderCard`, back to a constant hairline plus black shadow.

`09e6d1f7`, `3bb896bb`: runtime audit evidence and receipts.

## Current state (HEAD = 3bb896bb)

- Build: simulator Debug `BUILD SUCCEEDED`.
- Device: signed build installed and launched on Seminterrato; runtime audit passed.
- Home cards: constant hairline stroke (`Color.white.opacity(0.12)`) on all three card types, focus expressed only by scale plus black shadow. This is the invisible-focus state the user reported.

## Assessment

Session B's cleanup is valuable and should be kept: system text input, system button styles, removal of accent focus rings, deletion of `NuvioFocusBorder`, and the `SearchView` rewrite are all correct and reduce custom code.

The one step that went too far is the removal of the white focus border on the Home cards (`90e6ffe9` and `55ecce7f`). On this near-black background, scale plus a black shadow is not a visible selection cue. The design directive banned accent-colored strokes and brand glows, but a plain white border is the Apple-default highlight and is not a custom focus ring. Removing it makes the selection invisible again.

## Recommendation: reapply the white focus border, keep the rest

The two efforts go together. Take Session B's completed tree and reapply Session A's visible focus border on the three Home card types:

- `PosterCard`: focused stroke `Color.white.opacity(0.95)`, lineWidth 3; unfocused hairline `Color.white.opacity(0.12)`, lineWidth 1; focused shadow `Color.white.opacity(0.28)`, radius 18, y 10; scale 1.08.
- `ProgressCard`: same stroke scheme; focused shadow `Color.white.opacity(0.25)`, radius 16, y 10; scale 1.06.
- `FolderCard`: same stroke scheme and shadow; keep the `focused` parameter and the `.focused` wiring in `CatalogView`.

This was the exact diff present in `bacb3af6` before `90e6ffe9` and `55ecce7f` removed it. `git show bacb3af6 -- tvosApp/Sources/HomeCatalogViews.swift tvosApp/Sources/HomePersonalViews.swift` is a ready reference.

If the intent is to keep cards borderless, the alternative is to give the focused card a visible material background (bright panel) behind or around it, or to brighten the focused poster's stroke to a clearly visible white. Scale and shadow alone will not be visible on this background.

## Verification and deploy

```bash
xcodebuild -project tvosApp/NuvioTV.xcodeproj -scheme NuvioTV \
  -configuration Debug -destination 'generic/platform=tvOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Deploy to Seminterrato:

```bash
./scripts/run-tvos.sh
```

## Constraints

- Keep every source file at or below 400 lines.
- No en or em dashes and no ampersand in UI text. `tvSafe` cleans these on render, but write clean strings anyway.
- Commit each coherent milestone.