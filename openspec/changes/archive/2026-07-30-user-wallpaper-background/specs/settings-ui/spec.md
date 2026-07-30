# Delta for Settings UI

## ADDED Requirements

### Requirement: Background Source Toggle

The Settings screen SHALL display a `SegmentedButton<string>` with segments "App" and "Mío" in the Appearance section, labeled by `AppLocalizations.backgroundSourceLabel`. The default selection SHALL be "App". The choice MUST persist via `SettingsProvider.useMyWallpaper` → SharedPreferences key `use_my_wallpaper`. Toggling the source SHALL invalidate the cached `_previewImagePath`.

#### Scenario: Default segment is "App"

- GIVEN no persisted `use_my_wallpaper` value exists
- WHEN the Settings screen loads
- THEN the "App" segment MUST be selected
- AND `useMyWallpaper` returns `false`

#### Scenario: Toggle persists across restarts

- GIVEN the user selects "Mío"
- WHEN the app is restarted
- THEN the SegmentedButton MUST show "Mío" as selected
- AND `SharedPreferences` key `use_my_wallpaper` MUST be `true`

#### Scenario: Preview invalidated on toggle

- GIVEN a preview image is cached from "App" source
- WHEN the user toggles to "Mío"
- THEN `_previewImagePath` MUST be set to null
- AND the preview MUST regenerate with the new source

### Requirement: Live Wallpaper Detection

On Settings screen load, the system MUST probe `getWallpaper` MethodChannel. If it returns null, the SegmentedButton MUST be hidden and a localized explanation text (`AppLocalizations.liveWallpaperNotSupported`) MUST be displayed instead. If `getWallpaper` returns valid bytes, the SegmentedButton MUST be shown normally.

#### Scenario: Live wallpaper detected — toggle hidden

- GIVEN the device has a live wallpaper
- WHEN `getWallpaper` returns null on Settings load
- THEN the SegmentedButton MUST NOT be rendered
- AND the localized explanation text MUST be displayed
- AND `useMyWallpaper` MUST remain `false`

#### Scenario: Static wallpaper detected — toggle shown

- GIVEN the device has a static wallpaper
- WHEN `getWallpaper` returns valid bytes on Settings load
- THEN the SegmentedButton MUST be rendered with "App" | "Mío"

### Requirement: Fallback SnackBar Warning

When a wallpaper generation falls back to nature images because `getWallpaper` failed at compositing time (after the Settings probe passed), the system MUST show a `SnackBar` with `AppLocalizations.fallbackToNature`.

#### Scenario: SnackBar on runtime fallback

- GIVEN `useMyWallpaper` is `true` and Settings probe passed
- WHEN `generateAndSetWallpaper()` falls back to nature images
- THEN a SnackBar MUST appear with the localized fallback message
- AND the SnackBar MUST auto-dismiss
