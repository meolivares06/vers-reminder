# Design: Restore Original Wallpaper

## Technical Approach

Extend the existing `vers_reminder/wallpaper` MethodChannel with `getWallpaper` to read the current Android wallpaper as PNG bytes. Wrap backup/restore logic in a new `WallpaperBackupService` singleton (matching `ImageCacheService` pattern). Auto-backup fires in `SettingsProvider.triggerNow()` before generation on first run. Restore button in Settings screen uses the already-tested `WallpaperManagerFlutter().setWallpaper()` path.

## Architecture Decisions

| Decision | Choice | Tradeoff | Rationale |
|----------|--------|----------|-----------|
| Threading | Main thread for bitmap read/compress | ~5s blocking on first trigger, but one-time | Simpler code, no Kotlin coroutine dependency; acceptable for user-initiated operation |
| Backup format | Single `original.png` in `wallpaper_backup/` | No versioning, overwrites on re-backup | v1 scope; file naming avoids complexity without user-facing benefit |
| Restore path | Reuses `WallpaperManagerFlutter().setWallpaper(file, bothScreens)` | Same tested code path as `_setWallpaper()` | No new plugin, no `suggestDesiredDimensions` — backup is native resolution |
| State tracking | `hasBackup` in SharedPreferences + file existence check on read | Flag-file inconsistency if external deletion | Verified on every `hasBackup` read; clears flag if file missing |

## Data Flow

```
triggerNow()
    │
    ├─ hasBackup? ──no──► getWallpaper (MethodChannel)
    │                         │
    │                         ▼
    │               MainActivity.kt: getDrawable → Bitmap → PNG bytes
    │                         │
    │                         ▼
    │               writeAsBytes("wallpaper_backup/original.png")
    │               SharedPreferences.setBool("hasBackup", true)
    │
    └─► (proceed with normal generation)

Settings UI: tap Restore → confirm dialog → restoreOriginal()
    │
    └─► File("wallpaper_backup/original.png").readAsBytes()
         → WallpaperManagerFlutter().setWallpaper(file, bothScreens)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/wallpaper_backup_service.dart` | **Create** | Singleton: `backupCurrent()`, `restoreOriginal()`, `hasBackup` |
| `android/.../MainActivity.kt` | Modify | Add `"getWallpaper"` case to `when` block (~25 lines) |
| `lib/providers/settings_provider.dart` | Modify | Call `backupCurrent()` at top of `triggerNow()` when `!hasBackup` |
| `lib/screens/settings/settings_screen.dart` | Modify | New restore section with `ListTile`, confirmation `AlertDialog`, snackbar |
| `lib/l10n/app_en.arb` | Modify | 9 new keys |
| `lib/l10n/app_es.arb` | Modify | 9 translated keys |
| `lib/l10n/app_pt.arb` | Modify | 9 translated keys |

## Interfaces / Contracts

**MethodChannel**: `vers_reminder/wallpaper` → `getWallpaper` (no args) → `Uint8List?` (PNG bytes or null for live wallpapers)

```dart
// WallpaperBackupService singleton
static final WallpaperBackupService instance = WallpaperBackupService._internal();
Future<bool> backupCurrent();   // true if saved
Future<bool> restoreOriginal(); // true if restored
Future<bool> get hasBackup;     // flag AND file verified
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `hasBackup` flag-file sync | Mock SharedPreferences + File; verify flag cleared on missing file |
| Integration | MethodChannel `getWallpaper` | Instrumentation test on device with static/live wallpaper |
| Widget | Restore button visibility + dialog flow | `pumpWidget` with mocked `SettingsProvider`; verify button hidden when `hasBackup == false` |
| E2E | Full backup-restore cycle | Manual: set static wallpaper, trigger, verify restore |

## Migration / Rollout

No migration required. `hasBackup` is a new SharedPreferences key. Backup file is inert if unused. Rollback is a revert.

## Open Questions

None — all decisions resolved.
