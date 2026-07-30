# Proposal: User Background via Image Picker

## Intent
Replace the broken `getWallpaper` MethodChannel (blocked on Android 13+) with an `image_picker` flow. When the user selects "Mío", they pick a photo from their gallery. The app saves the photo to private storage and uses it as the compositing background.

## Why
`WallpaperManager.getDrawable()` is restricted on API 33+ and throws `SecurityException` on API 34+. There is no permission that allows reading the current wallpaper without root/system access. An image picker works on all Android versions, does not require special permissions, and gives the user control over which photo to use.

## Approach

1. Add `image_picker` dependency
2. Add `_userBackgroundPath` field to `SettingsProvider` with SharedPreferences key `user_background_path`
3. In SettingsScreen, when "Mío" is selected:
   - If no background image is stored → open image picker → save to `{appDir}/user_background.png`
   - If an image is already stored → show option to replace it
4. In `WallpaperGenerator._getBackgroundBytes()`:
   - `useMyWallpaper: false` → `ImageCacheService` (unchanged)
   - `useMyWallpaper: true` → read from `{appDir}/user_background.png` (instead of MethodChannel)
5. Remove `getWallpaper` from MainActivity.kt MethodChannel handler
6. Keep `suggestDesiredDimensions` in the channel (still needed for wallpaper setting)
7. The live wallpaper probe becomes unnecessary — remove it entirely
8. Add `replaceImage` option in Settings when "Mío" is selected and image exists

## Scope
- Modify: `pubspec.yaml`, `wallpaper_generator.dart`, `settings_provider.dart`, `settings_screen.dart`, `MainActivity.kt`
- Tests: update `_getBackgroundBytes` tests, widget tests for image picker flow
- No changes to backup service (it still uses MethodChannel but can fail gracefully)

## Non-goals
- Reading the system wallpaper via MethodChannel (removed)
- Live wallpaper detection (probe removed)
- Multiple user images (only one at a time, replaced manually)
