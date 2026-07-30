# Tasks: User Wallpaper Background

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~170 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | N/A |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: not-applicable
400-line budget risk: Low

## Phase 1: WallpaperGenerator Helper

- [x] 1.1 Add `_getBackgroundBytes({required bool useMyWallpaper})` private helper to `WallpaperGenerator` — routes to `ImageCacheService.getNextRandomImage()` when `false`, `getWallpaper` MethodChannel when `true`; catches `PlatformException` and logs fallback
  - **Verify**: Unit test returns nature bytes with `useMyWallpaper: false`, MethodChannel bytes with `true`, falls back on null/exception
- [x] 1.2 Wire `generateAndSetWallpaper()`, `_render()`, `renderOnly()`, `renderPreview()`, `preGenerateWallpapers()` through `_getBackgroundBytes()`; add `useMyWallpaper` bool parameter (default `false`)
  - **Verify**: Each call site invokes `_getBackgroundBytes` with the correct bool; `_compositeCanvas` receives identical bytes regardless of source
- [x] 1.3 In `preGenerateWallpapers()`, call `_getBackgroundBytes` once per batch and reuse the returned bytes for all 5 wallpapers
  - **Verify**: Single MethodChannel call per batch when `useMyWallpaper: true`; fallback bytes reused across all 5 PNGs

## Phase 2: SettingsProvider

- [x] 2.1 Add `_useMyWallpaper` bool field with getter and setter; persist via SharedPreferences key `use_my_wallpaper` following `_schedulerEnabled` pattern
  - **Verify**: Write `true`, restart provider, getter returns `true`; absent key defaults to `false`
- [x] 2.2 Pass `useMyWallpaper` to `triggerNow()` and `_preGenerateFutureWallpapers()` calls
  - **Verify**: Scheduler generates wallpapers with correct source flag; nature images used when `false`

## Phase 3: SettingsScreen UI

- [x] 3.1 Add `SegmentedButton<bool>` with segments "App" (`false`) and "Mío" (`true`) in the Appearance section, bound to `SettingsProvider.useMyWallpaper`
  - **Verify**: Toggle switches selection; provider getter reflects current value
- [x] 3.2 Probe `getWallpaper` MethodChannel in `initState`; if null, hide `SegmentedButton` and show `liveWallpaperNotSupported` explanation text
  - **Verify**: Live wallpaper → toggle absent + explanation visible; static wallpaper → toggle rendered normally
- [x] 3.3 Invalidate `_previewImagePath` (set to `null`) when toggle changes
  - **Verify**: Toggle source → preview path cleared → preview regenerates with new source
- [x] 3.4 Show `SnackBar` with `fallbackToNature` when `generateAndSetWallpaper` falls back to nature images at runtime (after Settings probe passed)
  - **Verify**: Trigger fallback → SnackBar appears with localized message → auto-dismisses

## Phase 4: Localization

- [x] 4.1 Add 5 keys to `app_en.arb`: `backgroundSourceLabel`, `backgroundSourceApp`, `backgroundSourceMine`, `liveWallpaperNotSupported`, `fallbackToNature`
- [x] 4.2 Add translated values for all 5 keys to `app_es.arb`
- [x] 4.3 Add translated values for all 5 keys to `app_pt.arb`
- [x] 4.4 Run `flutter gen-l10n` and verify generated code compiles
  - **Verify**: All 5 keys accessible via `AppLocalizations.of(context)!` in all 3 locales

## Phase 5: Tests

- [x] 5.1 Unit test `_getBackgroundBytes` with mocked MethodChannel: valid bytes, null return, `PlatformException` — assert correct source routing and fallback
  - **Verify**: `useMyWallpaper: true` + valid bytes → bytes returned; null → nature fallback; exception → nature fallback + logged
- [x] 5.2 Unit test `SettingsProvider`: set `useMyWallpaper = true`, recreate provider, assert getter returns `true`; default is `false`
  - **Verify**: Full persistence roundtrip passes
- [x] 5.3 Widget test `SettingsScreen`: mock MethodChannel returning null → assert SegmentedButton absent, explanation text present; mock valid bytes → assert SegmentedButton visible
  - **Verify**: Both live-wallpaper and static-wallpaper paths render correctly
