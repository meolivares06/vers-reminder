# Delta for Wallpaper Generation

## MODIFIED Requirements

### Requirement: Visual Composition

The generated wallpaper MUST compose a nature background image resized to device screen dimensions. The system MUST apply a 40% darkness overlay, center verse text vertically and horizontally on the canvas, and render text in white or high-contrast light shade.

Background resize MUST happen before text overlay compositing. Both layers MUST share the same canvas dimensions. Text positioning, font sizing, word-wrap, and locale behavior remain unchanged.

Screen dimensions MUST be resolved with this priority:
1. Cached dimensions from SharedPreferences (written once at app startup from PlatformDispatcher).
2. Fallback 1080×1920 when no cache exists.

(Previously: background was composited at native photo resolution, not screen dimensions.)

#### Scenario: Standard visual composition at screen dimensions

- GIVEN cached screen dimensions of 1080×2340 and a nature background image
- WHEN the system generates the final wallpaper
- THEN the background MUST be resized to 1080×2340 before overlaying
- AND the overlay MUST reduce brightness by 40%
- AND the verse text MUST be centered and in a light, high-contrast shade

#### Scenario: Fallback dimensions when cache is empty

- GIVEN no cached screen dimensions exist
- WHEN the system generates the wallpaper
- THEN it MUST use 1080×1920 as output dimensions
- AND the compositing behavior MUST be identical to the cached case

#### Scenario: Background image missing

- GIVEN the nature background asset is unavailable
- WHEN the system attempts to generate the wallpaper
- THEN it MUST report an error
- AND MUST NOT produce a corrupt or partial image

## ADDED Requirements

### Requirement: Screen Dimension Resolution

The system MUST detect and cache device screen dimensions for wallpaper output sizing.

At app startup on the UI thread, the system MUST read the primary display size and cache width and height in SharedPreferences. This write MUST happen once per app install.

In the background isolate, the system MUST read dimensions from the SharedPreferences cache.

The system MUST fall back to 1080×1920 when cached dimensions are unavailable.

#### Scenario: Dimensions cached on first launch

- GIVEN the app launches for the first time
- WHEN the UI thread initializes
- THEN screen width and height MUST be written to SharedPreferences
- AND subsequent launches MUST NOT overwrite the cached value

#### Scenario: Background isolate reads cached dimensions

- GIVEN SharedPreferences contains cached screen dimensions
- WHEN wallpaper generation runs in the background isolate
- THEN the generator MUST receive the cached width and height

#### Scenario: Fallback on missing cache

- GIVEN SharedPreferences contains no screen dimension entry
- WHEN wallpaper generation starts in any isolate
- THEN the system MUST use width=1080 and height=1920
