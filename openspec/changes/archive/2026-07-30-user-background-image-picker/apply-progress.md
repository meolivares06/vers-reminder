# Apply Progress: User Background via Image Picker

**Mode**: Standard
**Delivery**: size:exception (single PR, user explicitly approved)

## Summary

Completed all 21 tasks across 7 phases. Implementation replaces the broken `getWallpaper` MethodChannel (blocked on API 33+) with `image_picker` gallery flow. The user picks a photo when selecting "Mío", which is saved to `{appDocDir}/user_background.png`. `_getBackgroundBytes(useMyWallpaper: true)` reads from that file instead of calling the MethodChannel.

## Completed Tasks

### Phase 1: Dependencies
- [x] 1.1 Added `image_picker: ^1.0.0` to pubspec.yaml and ran `flutter pub get`

### Phase 2: WallpaperGenerator
- [x] 2.1 Rewrote `_getBackgroundBytes(useMyWallpaper: true)` — reads `user_background_path` from SharedPreferences, then `File(path).readAsBytes()`. Returns null if path absent or file missing
- [x] 2.2 Kept `import 'package:flutter/services.dart'` — `_suggestDesiredDimensions` still uses MethodChannel
- [x] 2.3 Removed static `lastGenerationHadFallback` field and all assignments

### Phase 3: SettingsProvider
- [x] 3.1 Added `_userBackgroundPath` String? field, getter, and `setUserBackgroundPath(String? path)`
- [x] 3.2 Loads `_userBackgroundPath` in `init()` from SharedPreferences key `user_background_path`
- [x] 3.3 Removed `lastFallback` getter

### Phase 4: SettingsScreen (core UX)
- [x] 4.1 Removed `_probeWallpaper()`, `_wallpaperProbeOk`, initState probe call, probe-gated branches
- [x] 4.2 Added image_picker import
- [x] 4.3 Auto-opens picker on Mío toggle when no image; saves to `{appDocDir}/user_background.png`; reverts to App on cancel
- [x] 4.4 Thumbnail (100×150) + Replace button shown when Mío selected and image exists
- [x] 4.5 Replace opens picker again, overwrites file, updates path, regenerates preview
- [x] 4.6 `backgroundSelected` SnackBar on success
- [x] 4.7 `backgroundPickFailed` SnackBar on error
- [x] 4.8 SegmentedButton always visible — no live wallpaper explanation
- [x] 4.9 Removed lastFallback SnackBar from triggerNow and permission dialog

### Phase 5: Localization
- [x] 5.1 app_en.arb — removed `liveWallpaperNotSupported`, `fallbackToNature`; added 4 new keys
- [x] 5.2 app_es.arb — same changes with Rioplatense Spanish translations
- [x] 5.3 app_pt.arb — same changes with Portuguese translations
- [x] 5.4 Ran `flutter gen-l10n` — verified new getters present, old ones absent

### Phase 6: MainActivity.kt
- [x] 6.1 Removed `getWallpaper` case from MethodChannel handler
- [x] 6.2 Removed unused imports (Bitmap, Canvas, BitmapDrawable, Drawable, ByteArrayOutputStream)
- [x] 6.3 Removed `drawableToBitmap` helper method

### Phase 7: Tests
- [x] 7.1 Rewrote `_getBackgroundBytes` tests — file-exists, file-missing, path-null scenarios via temp files
- [x] 7.2 Added userBackgroundPath persistence tests (set + recreate + assert, null removal)
- [x] 7.3 Rewrote widget tests — SegmentedButton always visible, toggle state, thumbnail+replace when path preset

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `pubspec.yaml` | Modified | Added `image_picker: ^1.0.0` dependency |
| `lib/services/wallpaper_generator.dart` | Modified | Rewrote `_getBackgroundBytes(true)` to read file via SharedPreferences path; removed `lastGenerationHadFallback` static field |
| `lib/providers/settings_provider.dart` | Modified | Added `_userBackgroundPath` field/getter, `setUserBackgroundPath()`, load in `init()`; removed `lastFallback` getter |
| `lib/screens/settings/settings_screen.dart` | Modified | Removed probe, added image picker flow, thumbnail + replace button; removed fallback SnackBars |
| `lib/l10n/app_en.arb` | Modified | Removed 2 keys, added 4 keys with English values |
| `lib/l10n/app_es.arb` | Modified | Same changes with Rioplatense Spanish translations |
| `lib/l10n/app_pt.arb` | Modified | Same changes with Portuguese translations |
| `lib/l10n/generated/` | Regenerated | `flutter gen-l10n` updated all generated files |
| `android/app/src/main/.../MainActivity.kt` | Modified | Removed `getWallpaper` case, unused imports, `drawableToBitmap` helper |
| `test/services/wallpaper_generator_test.dart` | Modified | Replaced MethodChannel mocks with temp-file-based `_getBackgroundBytes` tests; removed services.dart import |
| `test/providers/settings_provider_test.dart` | Modified | Added `userBackgroundPath` persistence and null-removal tests |
| `test/widgets/settings_background_source_test.dart` | Rewritten | Removed probe widget; tests for always-visible SegmentedButton, toggle state, thumbnail+replace |

## Deviations from Design

- **Task 2.2**: The design said "Remove `import 'package:flutter/services.dart'`" but `_suggestDesiredDimensions` still uses MethodChannel. We kept the import. The task was updated to note this check before removing.
- **Widget tests**: The image picker auto-open and cancel-revert scenarios cannot be tested at the widget level without mocking the image_picker platform channel. These are better suited for integration tests. Tests cover: SegmentedButton always visible, toggle state persistence, and thumbnail+replace visibility when path is preset.

## Issues Found

None.

## Remaining Tasks

None — all tasks complete.

## Workload / PR Boundary

- Mode: size:exception (single PR)
- Current work unit: Full change
- Boundary: All 7 phases in one PR
- Estimated review budget impact: ~380–420 changed lines (single PR exception)

## Git Stats Summary

```
pubspec.yaml                          |  3 +-
lib/services/wallpaper_generator.dart | 32 ++++++---------
lib/providers/settings_provider.dart  | 20 +++++++++-
lib/screens/settings/settings_screen.dart | 62 ++++++++++++++++++++++++---------
lib/l10n/app_en.arb                   |  5 +--
lib/l10n/app_es.arb                   |  5 +--
lib/l10n/app_pt.arb                   |  5 +--
android/.../MainActivity.kt           | 42 +++++----------------
test/services/wallpaper_generator_test.dart | 46 +++++++-----------------
test/providers/settings_provider_test.dart  | 35 ++++++++++++++++++
test/widgets/settings_background_source_test.dart | 99 ++++++++++++++++++++++++++++++++----------
```

## Status

21/21 tasks complete. **Ready for verify**.
