# Delta for Wallpaper Generation

## MODIFIED Requirements

### Requirement: Random Verse Selection

The system MUST load a random verse from local storage filtered by the active locale. On failure (no verses for locale, storage error), the system MUST return a `WallpaperResult.error` variant with a domain reason code. The system MUST NOT return user-visible strings directly. The UI layer SHALL map failure reasons to a generic localized message.
(Previously: system reported errors with a clear message string directly)

#### Scenario: No verses for locale returns result type

- GIVEN no verses exist for the active locale "PT"
- WHEN the system requests a random verse
- THEN it MUST return `WallpaperResult.error(reason: noVersesForLocale)`
- AND wallpaper generation MUST NOT proceed
- AND the specific reason is logged to console

#### Scenario: Storage failure returns result type

- GIVEN the local database is unavailable
- WHEN the system requests a random verse
- THEN it MUST return `WallpaperResult.error(reason: storageFailure)`
- AND the UI shows a generic localized error message

## ADDED Requirements

### Requirement: WallpaperResult Type

The generator MUST return a sealed `WallpaperResult` type with variants: `.success(wallpaperPath, verseReference)` and `.error(reason)`. The `reason` SHALL be a domain enum (`noVersesForLocale | backgroundMissing | storageFailure`). The UI layer MUST map each variant to a localized string via `AppLocalizations`. Wallpaper specs referencing hardcoded error strings SHALL be considered superseded.

#### Scenario: Success maps to localized message

- GIVEN `WallpaperResult.success(wallpaperPath: "/cache/img.jpg")`
- WHEN the UI receives the result
- THEN it displays the localized equivalent of "Wallpaper updated"
- AND the path is available for preview

#### Scenario: Error maps to generic message

- GIVEN `WallpaperResult.error(reason: backgroundMissing)`
- WHEN the UI receives the result
- THEN it displays the localized "Error generating wallpaper"
- AND the specific reason is logged to the developer console only
