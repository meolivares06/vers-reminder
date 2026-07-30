# Tasks: User Background via Image Picker

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 370–420 |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (infra) → PR 2 (state) → PR 3 (UX) → PR 4 (tests) |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Generator + native channel cleanup | PR 1 | Phases 1, 2, 6. Base = main. Tests still pass (no new provider field needed) |
| 2 | Provider + ARB keys | PR 2 | Phases 3, 5. Base = main. Depends on PR 1 for generator behavior at runtime |
| 3 | Settings screen UX | PR 3 | Phase 4. Base = main. Depends on PR 2 for `userBackgroundPath` |
| 4 | Test updates | PR 4 | Phase 7. Base = main. Depends on all prior PRs |

## Phase 1: Dependencies

- [x] 1.1 Add `image_picker: ^1.0.0` to `pubspec.yaml` dependencies and run `flutter pub get`

## Phase 2: WallpaperGenerator

- [x] 2.1 Rewrite `_getBackgroundBytes(useMyWallpaper: true)` — read `user_background_path` from SharedPreferences, then `File(path).readAsBytes()`. Return null if path absent or file missing. Keep fallback to ImageCacheService in callers
- [x] 2.2 Remove `import 'package:flutter/services.dart'` from `wallpaper_generator.dart` if `_suggestDesiredDimensions()` still needs it (it uses MethodChannel too — check before removing)
- [x] 2.3 Remove static `lastGenerationHadFallback` field and all assignments (`generateAndSetWallpaper`, `_render`). Fallback to nature images still happens silently

## Phase 3: SettingsProvider

- [x] 3.1 Add `_userBackgroundPath` String? field with getter; add `setUserBackgroundPath(String? path)` that persists to SharedPreferences key `user_background_path` and calls `notifyListeners()`
- [x] 3.2 Load `_userBackgroundPath` in `init()` after existing SharedPreferences reads: `_userBackgroundPath = prefs.getString('user_background_path')`
- [x] 3.3 Remove `lastFallback` getter (`WallpaperGenerator.lastGenerationHadFallback` no longer exists)

## Phase 4: SettingsScreen (core UX)

- [x] 4.1 Remove `_probeWallpaper()` method, `_wallpaperProbeOk` field, `initState` probe call, and the probe-gated `if`/`else` branches around the SegmentedButton
- [x] 4.2 Add `import 'package:image_picker/image_picker.dart'` at top of file
- [x] 4.3 In SegmentedButton `onSelectionChanged` for `true` (Mío): if `settings.userBackgroundPath == null` → open `ImagePicker.pickImage(source: ImageSource.gallery)`; if user picks photo → save bytes to `{appDocDir}/user_background.png` → call `settings.setUserBackgroundPath(path)`; if cancelled → call `settings.setUseMyWallpaper(false)` to revert to App
- [x] 4.4 When Mío is selected AND `settings.userBackgroundPath` is non-null: show a thumbnail (100×150) of the stored image + a "Replace" text button labeled `l10n.replaceBackgroundImage` below the SegmentedButton
- [x] 4.5 On Replace tap → open picker again → overwrite file + update path → regenerate preview
- [x] 4.6 After successful pick: show `SnackBar` with `l10n.backgroundSelected`
- [x] 4.7 On picker error: show `SnackBar` with `l10n.backgroundPickFailed`
- [x] 4.8 Remove the `else` branch (live wallpaper explanation text + icon) — SegmentedButton is always visible now
- [x] 4.9 Remove `lastFallback` SnackBar code in `triggerNow` flow and `_showWallpaperPermissionDialog` — no more fallback notification

## Phase 5: Localization

- [x] 5.1 In `app_en.arb` (`lib/l10n/app_en.arb`): remove `liveWallpaperNotSupported`, `fallbackToNature`; add `pickBackgroundImage`, `replaceBackgroundImage`, `backgroundSelected`, `backgroundPickFailed` with English values
- [x] 5.2 In `app_es.arb`: same key changes with Spanish translations
- [x] 5.3 In `app_pt.arb`: same key changes with Portuguese translations
- [x] 5.4 Run `flutter gen-l10n` and verify no compilation errors; verify generated `app_localizations.dart` has the new 4 getters and missing the 2 removed ones

## Phase 6: MainActivity.kt

- [x] 6.1 Remove `getWallpaper` case block from MethodChannel `when` handler (lines 40–74), keeping `suggestDesiredDimensions` and `else → notImplemented`
- [x] 6.2 Remove unused imports: `Bitmap`, `Canvas`, `BitmapDrawable`, `Drawable`, `ByteArrayOutputStream`
- [x] 6.3 Remove `drawableToBitmap` helper method (lines 84–92) — no longer called

## Phase 7: Tests

- [x] 7.1 Rewrite `_getBackgroundBytes` tests in `test/services/wallpaper_generator_test.dart`: replace MethodChannel mocks with temp-file-based tests — file exists returns bytes, file missing returns null, file read throws returns null. Remove `_createTestImageBytes` if any, consolidate with existing helper
- [x] 7.2 Add `userBackgroundPath` persistence test in `test/providers/settings_provider_test.dart`: set path → recreate provider via `init()` → assert getter returns same path
- [x] 7.3 Rewrite `test/widgets/settings_background_source_test.dart`: remove `_BackgroundSourceSection` probe widget entirely; replace with picker flow tests — auto-open picker on "Mío" toggle when no file stored, cancel reverts to "App", thumbnail + replace visible when path is preset
