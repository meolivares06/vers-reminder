# Home UX Specification

## Purpose

Refinements to the Home tab: a living wallpaper card with last-updated context and a trigger action, a localized and navigable active-categories tile, full localization of remaining hardcoded strings, and locale-aware verse text. Serves F3, F5, F8, and F10.

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

The primary "Change now" CTA SHALL live on Home. Settings MAY retain a contextual "Change now" in its Actions section, but it SHALL be clearly secondary relative to the Home action.

- **Finding**: F3

#### Scenario: Home owns primary action

- GIVEN the user is on Home with a wallpaper present
- WHEN they trigger the card action
- THEN wallpaper generation starts from Home

### UX-HOME-003: Localized Active-Categories Count

The Home active-categories tile SHALL render a localized count via an ARB key with a count placeholder (e.g. `activeCategoriesCount`). Tapping the tile SHALL navigate to Settings (Categories). No hardcoded Spanish `activas` literal SHALL remain in Dart.

- **Finding**: F5

#### Scenario: Localized count renders

- GIVEN the locale is EN and 3 categories are active
- WHEN the Home screen renders the categories tile
- THEN the subtitle shows the localized pluralized count for 3

#### Scenario: Tile navigates to settings

- GIVEN the user taps the active-categories tile
- WHEN the tap is handled
- THEN the Settings screen opens

#### Scenario: Count updates live

- GIVEN a category is toggled in Settings
- WHEN the user returns to Home
- THEN the count subtitle reflects the new active count

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
