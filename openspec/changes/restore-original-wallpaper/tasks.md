# Tasks: Restore Original Wallpaper

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 340-380 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

## Phase 1: Platform Channel — Get Wallpaper

- [x] 1.1 Add `"getWallpaper"` case to `MainActivity.kt` — get `WallpaperManager` drawable, compress to PNG bytes, return via `result.success(bytes)`; return `result.success(null)` for live wallpapers
- [ ] 1.2 **Test**: Instrumentation test — verify `getWallpaper` returns non-null bytes for static wallpaper and null for live wallpaper

## Phase 2: Backup Service

- [x] 2.1 Create `lib/services/wallpaper_backup_service.dart` — singleton with `backupCurrent()` (calls `getWallpaper` MethodChannel, saves PNG), `restoreOriginal()` (reads file, calls `WallpaperManagerFlutter.setWallpaper()`), and `hasBackup` getter (checks SharedPreferences flag + file existence)
- [ ] 2.2 **Test**: Unit test `WallpaperBackupService` — mock MethodChannel and `SharedPreferences`; verify `backupCurrent()` saves file on success, skips on null; verify `hasBackup` syncs flag with file existence

## Phase 3: Settings Provider Integration

- [x] 3.1 Add `WallpaperBackupService` reference to `SettingsProvider` — call `backupCurrent()` at top of `triggerNow()` guarded by `!hasBackup`, expose `bool get hasBackup`

## Phase 4: Settings Screen UI

- [x] 4.1 Add restore section below appearance section — `TextButton.icon` with `restoreOriginalWallpaper` label, only visible when `hasBackup == true`, with confirmation `AlertDialog` on tap
- [x] 4.2 Add success/failure snackbar — show localized `restoreSuccess` or `restoreError` after `restoreOriginal()` completes
- [ ] 4.3 **Test**: Widget test — pump settings screen with mocked `SettingsProvider`; verify button hidden when `hasBackup == false`, visible when `true`; tap shows dialog; confirm shows snackbar

## Phase 5: Localization

- [x] 5.1 Add 9 restore keys to `lib/l10n/app_en.arb`: `restoreOriginalWallpaper`, `restoreOriginalWallpaperSubtitle`, `restoreConfirmTitle`, `restoreConfirmMessage`, `restoreConfirmOk`, `restoreConfirmCancel`, `restoreSuccess`, `restoreError`, `noBackupAvailable`
- [x] 5.2 Add 9 translated keys to `lib/l10n/app_es.arb`
- [x] 5.3 Add 9 translated keys to `lib/l10n/app_pt.arb`
- [x] 5.4 Run `flutter gen-l10n` and verify zero warnings
