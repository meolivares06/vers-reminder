# Apply Progress: User Wallpaper Background

**Change**: user-wallpaper-background
**Mode**: Standard (Strict TDD: false)
**Date**: 2026-07-30

## Summary

Implemented the user wallpaper background feature across all 5 phases. All 15 tasks completed. 83/83 tests pass.

## Tasks Completed

### Phase 1: WallpaperGenerator Helper
- [x] 1.1 Added `_getBackgroundBytes({required bool useMyWallpaper})` private helper
- [x] 1.2 Wired all 5 call sites (`generateAndSetWallpaper`, `_render`, `renderOnly`, `renderPreview`, `preGenerateWallpapers`)
- [x] 1.3 Single MethodChannel call per batch in `preGenerateWallpapers`

### Phase 2: SettingsProvider
- [x] 2.1 Added `_useMyWallpaper` field with getter/setter + SharedPreferences persistence (key `use_my_wallpaper`)
- [x] 2.2 Passed `useMyWallpaper` to `triggerNow()` and `_preGenerateFutureWallpapers()`

### Phase 3: SettingsScreen UI
- [x] 3.1 Added `SegmentedButton<bool>` with "App" / "Mío" segments
- [x] 3.2 Live wallpaper probe in `initState` — hides button on null, shows explanation
- [x] 3.3 Invalidates `_previewImagePath` on toggle
- [x] 3.4 Shows `SnackBar` with `fallbackToNature` on runtime fallback

### Phase 4: Localization
- [x] 4.1 Added 5 EN ARB keys
- [x] 4.2 Added 5 ES ARB keys
- [x] 4.3 Added 5 PT ARB keys
- [x] 4.4 `flutter gen-l10n` compiles successfully

### Phase 5: Tests
- [x] 5.1 Unit tests for `_getBackgroundBytes` with mocked MethodChannel (4 tests)
- [x] 5.2 SettingsProvider persistence roundtrip (2 tests)
- [x] 5.3 Widget test for SegmentedButton visibility (2 tests)

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Modified | Added `_getBackgroundBytes` helper, `lastGenerationHadFallback` static, `useMyWallpaper` param to 5 methods + batch caching in `preGenerateWallpapers` |
| `lib/providers/settings_provider.dart` | Modified | Added `_useMyWallpaper` field/getter/setter, loaded from SharedPreferences in `init()`, passed to `triggerNow` and `_preGenerateFutureWallpapers`, exposed `lastFallback` getter |
| `lib/screens/settings/settings_screen.dart` | Modified | Added probe + SegmentedButton + invalidate preview + SnackBar fallback |
| `lib/l10n/app_en.arb` | Modified | Added 5 keys |
| `lib/l10n/app_es.arb` | Modified | Added 5 translations |
| `lib/l10n/app_pt.arb` | Modified | Added 5 translations |
| `lib/l10n/generated/` | Generated | `flutter gen-l10n` output (updated) |
| `test/services/wallpaper_generator_test.dart` | Modified | Added `_getBackgroundBytes` tests with mocked MethodChannel (4 tests) |
| `test/providers/settings_provider_test.dart` | Modified | Added `useMyWallpaper` persistence roundtrip tests (2 tests) |
| `test/widgets/settings_background_source_test.dart` | Created | Widget tests for SegmentedButton visibility (2 tests) |

## Deviations from Design

**Minor**: The design originally suggested making `_render` handle the fallback internally when `useMyWallpaper` is true. I kept this logic but also restored the top-level `getNextRandomImage` check in `generateAndSetWallpaper` for the `!useMyWallpaper` path to preserve the `backgroundMissing` error code for existing tests. The `_render` method still handles fallback when `useMyWallpaper: true`.

**Minor**: The probe gracefully resets `useMyWallpaper` to false when wallpaper is unavailable, which wasn't explicitly called out in the design but follows from the spec requirement that "useMyWallpaper MUST remain false" when live wallpaper is detected.

## Issues Found

None. All tests pass.

## Remaining Tasks

None. All 15 tasks complete.

## Status

15/15 tasks complete. Ready for verify.
