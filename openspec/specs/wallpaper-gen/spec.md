# Wallpaper Generation Specification

## Purpose

Generate a wallpaper image combining a random Bible verse with a nature background photo. The verse text is overlaid with a 40% dark overlay, dynamic font sizing with word-wrap, and centered vertically in the active locale.

## Requirements

### Requirement: Random Verse Selection

The system MUST load a random verse from local storage filtered by the active locale. On failure (no verses for locale, storage error), the system MUST return a `WallpaperResult.error` variant with a domain reason code. The system MUST NOT return user-visible strings directly. The UI layer SHALL map failure reasons to a generic localized message.

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

### Requirement: Verse Text Overlay

The system MUST render verse text over a nature background image with a 40% dark overlay. Text MUST use dynamic font sizing with word-wrap: start at a base size and reduce incrementally until all text fits, down to a minimum of 12px. If text still overflows at 12px, it MUST be truncated with "...".

#### Scenario: Text fits at base font size

- GIVEN a verse with short text fitting the overlay area
- WHEN the system renders the wallpaper
- THEN the text MUST be displayed at the base font size
- AND the full text MUST be visible without truncation

#### Scenario: Text requires font reduction

- GIVEN a long verse that overflows at base font size
- WHEN the system renders the wallpaper
- THEN it MUST reduce font size step by step until all text fits
- AND the final font size MUST be >= 12px

#### Scenario: Text still overflows at minimum font size

- GIVEN a very long verse that still overflows at 12px
- WHEN the system renders the wallpaper
- THEN it MUST truncate the visible text with "..." appended
- AND the text SHOULD preserve the verse reference at the end

### Requirement: Locale Consistency

The system MUST NOT mix locales in the wallpaper output. Both the verse text and the verse reference MUST be in the same locale.

#### Scenario: Same locale enforced

- GIVEN the active locale is "PT"
- WHEN generating a wallpaper
- THEN the verse text MUST be in Portuguese
- AND the verse reference MUST also be in Portuguese

#### Scenario: Mixed locale rejected

- GIVEN verse data contains text in "ES" and reference in "PT"
- WHEN the system validates the verse for rendering
- THEN it MUST reject the verse
- AND select a different verse that is fully consistent

### Requirement: Visual Composition

The generated wallpaper MUST compose a nature background image with a 40% darkness overlay, verse text centered vertically on the canvas, and text color in white or high-contrast light shade.

#### Scenario: Standard visual composition

- GIVEN a nature background image and a rendered verse
- WHEN the system generates the final wallpaper
- THEN the overlay MUST reduce brightness by 40%
- AND the verse text MUST be centered vertically and horizontally
- AND the text color MUST be a light, high-contrast shade

#### Scenario: Background image missing

- GIVEN the nature background asset is unavailable
- WHEN the system attempts to generate the wallpaper
- THEN it MUST report an error
- AND MUST NOT produce a corrupt or partial image

### Requirement: Extractable Composite Pipeline

The system MUST extract compositing from file-writing. A private `_composite()` method MUST accept source image bytes and target dimensions, apply the 40% dark overlay, render and composite verse text, and return the composited result as `Uint8List` (PNG-encoded bytes). The existing `_render()` method SHALL call `_composite()` then write the returned bytes to a file. The compositing logic MUST remain visually identical to the original inline implementation.

#### Scenario: Composite returns valid PNG bytes

- GIVEN valid background image bytes and target dimensions
- WHEN `_composite()` is called
- THEN it MUST return `Uint8List` containing a valid PNG image
- AND the returned image MUST have the requested width and height

#### Scenario: Corrupt bytes returns null

- GIVEN corrupt background image bytes
- WHEN `_composite()` is called
- THEN it MUST return null
- AND no file is written

### Requirement: Preview Renderer

The system MUST provide a `renderPreview()` method that calls `_composite()` at approximately one-quarter screen resolution. The method MUST return `Uint8List?` (PNG bytes) without writing to disk. The preview MUST be visually identical to a full render at the same settings, differing only in resolution. `renderPreview()` SHALL accept the same layout parameters (`horizontalOffset`, `verticalAlignment`, `fontScale`, `calibratedInset`) as the full render pipeline.

#### Scenario: Preview returns at lower resolution

- GIVEN screen dimensions 1080×2340
- WHEN `renderPreview()` is called
- THEN the returned width MUST be approximately 270 (¼)
- AND the returned height MUST be approximately 585 (¼)
- AND the bytes MUST decode to a valid PNG

#### Scenario: Preview matches full render compositing

- GIVEN the same background image and verse
- WHEN both `renderPreview()` and `_render()` are called with identical parameters
- THEN the overlay opacity, text content, and compositing order MUST be identical
- AND only the resolution SHALL differ

#### Scenario: Preview returns null when background fails

- GIVEN the background image source returns null
- WHEN `renderPreview()` is called
- THEN it MUST return null
- AND the existing `_render()` error path MUST be preserved unchanged

### Requirement: Background Source Selection

`generateAndSetWallpaper()`, `_render()`, `renderOnly()`, `renderPreview()`, and `preGenerateWallpapers()` MUST accept a `useMyWallpaper` boolean parameter. When `false`, the system SHALL use `ImageCacheService.getNextRandomImage()` (unchanged). When `true`, the system SHALL read background bytes from `{appDir}/user_background.png` via `File.readAsBytes()`. The `_composite()` method SHALL be called with the resolved bytes regardless of source.

(Previously: read wallpaper bytes via `getWallpaper` MethodChannel when `useMyWallpaper == true`)

#### Scenario: Nature source selected

- GIVEN `useMyWallpaper` is `false`
- WHEN `generateAndSetWallpaper()` is called
- THEN background bytes MUST come from `ImageCacheService.getNextRandomImage()`
- AND the wallpaper MUST use a random cached nature image

#### Scenario: User background file source selected

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` exists
- WHEN `generateAndSetWallpaper()` is called
- THEN background bytes MUST come from `{appDir}/user_background.png`
- AND the composited wallpaper MUST use the user's picked photo

#### Scenario: Preview from user background file

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` exists
- WHEN `renderPreview()` is called
- THEN the preview MUST read bytes from `{appDir}/user_background.png`
- AND the returned PNG MUST visually match a full render at the same settings

### Requirement: Fallback to Nature Images

When `useMyWallpaper` is `true` and `{appDir}/user_background.png` does NOT exist or `File.readAsBytes()` fails, the system MUST fall back to `ImageCacheService.getNextRandomImage()`. The system MUST log the fallback reason and MUST NOT crash. The composited wallpaper SHALL use a nature image as if `useMyWallpaper` were `false`.

(Previously: fall back when `getWallpaper` MethodChannel returns null or throws `PlatformException`)

#### Scenario: User background file missing

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` does not exist
- WHEN `_getBackgroundBytes()` is called
- THEN the system MUST fall back to a nature image
- AND wallpaper generation MUST complete successfully
- AND the fallback reason MUST be logged

#### Scenario: File read fails

- GIVEN `useMyWallpaper` is `true` AND `File.readAsBytes()` throws an exception
- WHEN `_getBackgroundBytes()` is called
- THEN the system MUST catch the exception
- AND fall back to `ImageCacheService.getNextRandomImage()`
- AND the exception details MUST be logged
