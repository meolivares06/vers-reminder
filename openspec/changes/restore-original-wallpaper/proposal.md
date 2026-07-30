# Proposal: Restore Original Wallpaper

## Intent

Auto-save the user's current wallpaper before the app changes it, then let them restore it. No undo today — a one-way operation with permanent loss.

## Scope

### In Scope
- Read current Android wallpaper as PNG bytes via custom MethodChannel
- Auto-save to `wallpaper_backup/original.png` on first `triggerNow()`
- Restore button in Settings → confirmation dialog → applies via `setWallpaper()`
- Track `hasBackup` in SharedPreferences; hide button when absent
- Gracefully skip live wallpapers (getDrawable returns null)
- 9 new localized strings across ES, PT, EN

### Out of Scope
- Backup preview, rolling backups, auto-restore on disable
- Cloud/external storage, live wallpaper partial backup

## Capabilities

### New Capabilities
- `wallpaper-backup`: orchestrates MethodChannel read, file persistence, SharedPreferences tracking, and restore via `wallpaper_manager_flutter`

### Modified Capabilities
- `wallpaper-set`: add `getWallpaper` to `vers_reminder/wallpaper` channel (returns PNG bytes or null for live wallpapers)
- `settings-ui`: add restore section with button, confirmation dialog, snackbar feedback
- `l10n-core`: 9 ARB keys across all locales

## Approach

**Extend existing MethodChannel.** Add `getWallpaper` to `vers_reminder/wallpaper` in `MainActivity.kt` (~25 lines: getDrawable → compress PNG → return bytes). New `WallpaperBackupService` saves to app docs, restores via existing `setWallpaper()`. Auto-backup fires in `triggerNow()` before generation when `hasBackup == false`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `android/.../MainActivity.kt` | Modified | `getWallpaper` case in MethodChannel |
| `lib/services/wallpaper_backup_service.dart` | **New** | Save/restore orchestration |
| `lib/providers/settings_provider.dart` | Modified | Auto-backup before trigger, expose `hasBackup` |
| `lib/screens/settings/settings_screen.dart` | Modified | Restore button + confirmation dialog |
| `lib/l10n/app_{en,es,pt}.arb` | Modified | 9 new keys |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Large bitmap on main thread (~18 MB) | Low | One-time, user-triggered; 5s timeout |
| PNG >8 MB | Low | Screen-res wallpapers compress well |
| Plugin API change breaks restore | Low | Stable v1.0.1; same tested setWallpaper() path |
| Reinstall wipes backup | Expected | Inherent — app docs survive updates, not uninstalls |

## Rollback Plan

Revert commit. No migration needed — `hasBackup` is a new key that goes unused. Backup file is inert.

## Dependencies

- `wallpaper_manager_flutter: ^1.0.1` (existing, used for restore)
- No new packages

## Success Criteria

- [ ] Auto-save creates valid PNG backup on first `triggerNow()`
- [ ] Live wallpaper → null returned, no crash, backup skipped
- [ ] Restore button visible only when `hasBackup == true`
- [ ] Confirmation dialog shown before restore
- [ ] Restore sets both screens via `setWallpaper()`
- [ ] All 9 ARB keys present across EN/ES/PT
- [ ] Existing `triggerNow()` unchanged when backup already exists
