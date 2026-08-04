# Home UX Specification

## Purpose

Refinements to the Home tab: a living wallpaper card with last-updated context and a trigger action, a wallpaper-focused layout with a gold circular FAB primary action, full localization of remaining hardcoded strings, and locale-aware verse text. Serves F3, F8, and F10.

## Requirements

### UX-HOME-001: Wallpaper Card Shows Last-Updated Context

When a wallpaper exists (`lastWallpaperPath` set), the Home card SHALL display a localized "Updated {time}" label. The system SHALL persist a `lastWallpaperTimestamp` in `SettingsProvider` alongside `last_wallpaper_path`. The card SHALL remain tappable to trigger a new wallpaper generation.

- **Finding**: F3

#### Scenario: Card shows updated label when file exists

- GIVEN `lastWallpaperPath` is set and a timestamp is stored
- WHEN the Home screen renders the wallpaper card
- THEN a localized "Updated {...}" caption is shown

#### Scenario: Tapping card triggers generation

- GIVEN a wallpaper exists on the Home card
- WHEN the user taps the card image or its action affordance
- THEN a new wallpaper generation is triggered

#### Scenario: Empty state unchanged

- GIVEN no `lastWallpaperPath` exists
- WHEN the Home screen renders
- THEN the empty-state prompt is shown (tap to generate first)
- AND no updated-time caption appears

### UX-HOME-002: Activity Confined to Home Primary CTA

The primary "Change now" CTA SHALL be a gold circular FAB on Home. The wallpaper card SHALL remain tappable as a secondary affordance triggering the same generation flow. Settings MAY retain a contextual "Change now" action as secondary.
(Previously: primary action was a full-width AsyncActionButton rendered below the card)

- **Finding**: F3

#### Scenario: FAB is Home primary action

- GIVEN the user is on Home with a wallpaper present
- WHEN they tap the gold circular FAB
- THEN wallpaper generation starts from Home

#### Scenario: Card tap still triggers generation

- GIVEN a wallpaper exists on the Home card
- WHEN the user taps the wallpaper card
- THEN the same permission-gated generation flow is triggered

### UX-HOME-004: No Hardcoded Spanish Strings

The system MUST localize all user-facing Home strings via ARB — including the share message (`shareApp`) and the copy-to-clipboard confirmation (`emailCopied`) — and localize time units used by `_formatMinutes` via ARB keys (or `intl`). The same ARB keys MUST be reused by Settings to avoid duplication.

- **Finding**: F8

#### Scenario: Share message localized

- GIVEN the locale is EN
- WHEN the user taps share on Home
- THEN the share text uses the EN value of the `shareApp` ARB key

#### Scenario: Copy confirmation localized

- GIVEN the locale is PT
- WHEN an email address is copied
- THEN the confirmation uses the PT value of `emailCopied`

#### Scenario: Time units localized

- GIVEN the locale is ES and frequency formats a value
- WHEN the time string renders
- THEN the unit word resolves from an ARB key
- AND no raw `min`/`hora` literal is hardcoded in Dart

### UX-HOME-005: Locale-Aware Verse Text

The system SHALL expose a `textFor(locale)` getter on `Verse` that returns `textPt` when the locale is Portuguese and `textPt` is non-empty, otherwise falling back to `textEs`. `VerseTile` SHALL use this getter for display. This covers only es/pt — there is no `textEn` field.

- **Finding**: F10

#### Scenario: Portuguese locale shows textPt

- GIVEN the active locale is PT and `textPt` is non-empty
- WHEN `VerseTile` renders a verse
- THEN the PT text is displayed

#### Scenario: Missing textPt falls back to textEs

- GIVEN the active locale is PT and `textPt` is null or empty
- WHEN `VerseTile` renders the verse
- THEN the ES text is displayed
- AND no empty string is shown

### UX-HOME-006: Wallpaper Card Fraction-Height

The wallpaper card on Home SHALL fill 85-88% of visible vertical space, computed as a fraction of viewport height. The system MUST NOT use fixed-pixel sizing.

#### Scenario: Card fills majority of viewport

- GIVEN the user is on Home tab (index 0)
- WHEN the Home screen renders
- THEN the card height is between 85% and 88% of visible vertical space

#### Scenario: Empty state preserves fraction

- GIVEN no wallpaper exists
- WHEN the Home screen renders
- THEN the empty-state card occupies the same 85-88% height fraction

#### Scenario: Card does not push FAB off-screen

- GIVEN a wallpaper card at 88% height with a long-verse caption
- WHEN the Home screen renders
- THEN the gold circular FAB remains visible and tappable in its bottom-right position

### UX-HOME-007: Gold Circular FAB Primary Action

A gold circular FloatingActionButton SHALL be the primary wallpaper-change action on Home. The FAB MUST use `colorScheme.secondary` for its background. Tapping the FAB SHALL trigger the existing permission-gated generation flow. The FAB MUST NOT render on tab index 1.

#### Scenario: FAB triggers generation with permission granted

- GIVEN the user is on Home tab with storage permission granted
- WHEN the gold circular FAB is tapped
- THEN wallpaper generation starts

#### Scenario: FAB shows permission dialog when needed

- GIVEN the user is on Home tab without storage permission
- WHEN the gold circular FAB is tapped
- THEN the permission dialog appears
- AND generation proceeds only after permission is granted

#### Scenario: FAB absent on verse list tab

- GIVEN the user is on tab index 1 (verse list)
- WHEN the Scaffold renders
- THEN the gold FAB MUST NOT be visible
- AND the existing add-verse FAB SHALL render instead
