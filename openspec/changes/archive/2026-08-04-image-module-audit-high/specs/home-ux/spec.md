# Delta for home-ux

## MODIFIED Requirements

### UX-HOME-001: Wallpaper Card Shows Last-Updated Context

When a wallpaper exists (`lastWallpaperPath` set), the Home card SHALL display a localized "Updated {time}" label. The system SHALL persist a `lastWallpaperTimestamp` in `SettingsProvider` alongside `last_wallpaper_path`. The card SHALL remain tappable to trigger a new wallpaper generation. The file-existence check MUST use a cached boolean flag updated asynchronously after generation completes; it MUST NOT invoke synchronous `File.existsSync()` during widget build.

- **Finding**: F6

(Previously: used `File.existsSync()` on the UI raster thread during every build)

#### Scenario: Card shows updated label using cached flag

- GIVEN `lastWallpaperPath` is set and the cached existence flag is `true`
- WHEN the Home screen renders the wallpaper card
- THEN a localized "Updated {...}" caption is shown
- AND no `existsSync()` call is made during build

#### Scenario: Flag updated after generation completes

- GIVEN `triggerNow` completes successfully with a new wallpaper path
- WHEN the post-frame callback fires
- THEN the cached existence flag is set to `true` in widget state
- AND subsequent rebuilds use the flag without sync I/O

#### Scenario: Tapping card triggers generation

- GIVEN a wallpaper exists on the Home card
- WHEN the user taps the card image or its action affordance
- THEN a new wallpaper generation is triggered

#### Scenario: Empty state unchanged

- GIVEN no `lastWallpaperPath` exists
- WHEN the Home screen renders
- THEN the empty-state prompt is shown (tap to generate first)
- AND no updated-time caption appears
