# Delta for settings-ui

## ADDED Requirements

### Requirement: Image Picker Integration

When the "Mío" segment is selected, if `{appDir}/user_background.png` does NOT exist, the system MUST open `ImagePicker.pickImage(source: ImageSource.gallery)` automatically. If the file exists, the system SHALL display a thumbnail of the stored image with a "Replace" option. The picked image MUST be saved to `{appDir}/user_background.png` (overwriting any previous file). After saving, the preview MUST regenerate with the new photo.

#### Scenario: First-time selection opens picker

- GIVEN the user selects "Mío" AND `{appDir}/user_background.png` does NOT exist
- WHEN the segment changes
- THEN `ImagePicker.pickImage()` MUST be called with `ImageSource.gallery`
- AND the background source remains "App" until the picker succeeds

#### Scenario: Image stored shows thumbnail + replace

- GIVEN the user selects "Mío" AND `{appDir}/user_background.png` exists
- WHEN the segment changes
- THEN the stored image thumbnail MUST be displayed
- AND a "Replace" button SHALL be visible

#### Scenario: Picked image saved and preview updates

- GIVEN the user picks an image from the gallery
- WHEN the picker returns the selected image
- THEN the image MUST be saved to `{appDir}/user_background.png`
- AND `useMyWallpaper` MUST be set to `true`
- AND the preview MUST regenerate using the new photo

#### Scenario: Picker cancelled reverts to "App"

- GIVEN the user selects "Mío" AND no image is stored
- WHEN the user cancels the image picker
- THEN `useMyWallpaper` MUST remain (or be reset to) `false`
- AND the SegmentedButton MUST revert to "App"

#### Scenario: Replace overwrites old file

- GIVEN `{appDir}/user_background.png` exists
- WHEN the user taps "Replace" and picks a new image
- THEN the old file MUST be overwritten
- AND the preview MUST regenerate with the new photo

## MODIFIED Requirements

### Requirement: Background Source Toggle

The Settings screen SHALL display a `SegmentedButton<string>` with segments "App" and "Mío" in the Appearance section, labeled by `AppLocalizations.backgroundSourceLabel`. The default selection SHALL be "App". The choice MUST persist via `SettingsProvider.useMyWallpaper` → SharedPreferences key `use_my_wallpaper`. Toggling the source SHALL invalidate the cached `_previewImagePath`. The SegmentedButton SHALL always be visible — no probe needed.

(Previously: SegmentedButton hidden when live wallpaper detected via probe. Probe removed — `image_picker` works on all Android versions.)

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

## REMOVED Requirements

### Requirement: Live Wallpaper Detection

(Reason: No probe needed — `getWallpaper` MethodChannel is removed and `image_picker` works on all Android versions. The SegmentedButton is always visible.)
(Migration: Remove `_probeWallpaper()` method, `_wallpaperProbeOk` field, `initState()` call to probe, and the conditional rendering that hid the SegmentedButton.)

### Requirement: Fallback SnackBar Warning

(Reason: No probe means no surprise fallback at toggle time. File read failures in wallpaper-gen still fall back defensively but the UI no longer shows a `fallbackToNature` SnackBar.)
(Migration: Remove `lastFallback` check and SnackBar from "Change Now" and permission dialog flows in `settings_screen.dart`.)
