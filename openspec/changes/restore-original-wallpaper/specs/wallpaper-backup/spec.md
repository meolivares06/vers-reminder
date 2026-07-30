# Wallpaper Backup Specification

## Purpose

Auto-save the user's Android wallpaper before the app changes it. Restore via button in Settings.

## Requirements

### Requirement: Auto-Backup on First Wallpaper Change

The system MUST save the current Android wallpaper to `wallpaper_backup/original.png` the first time `triggerNow()` executes and no backup exists.

#### Scenario: First trigger creates backup

- GIVEN no backup exists (`hasBackup == false`)
- WHEN `triggerNow()` executes
- THEN the system reads the current wallpaper via `getWallpaper` MethodChannel
- AND saves it as `wallpaper_backup/original.png` in app documents
- AND sets `hasBackup = true` in SharedPreferences

#### Scenario: Subsequent triggers skip backup

- GIVEN a backup exists (`hasBackup == true`)
- WHEN `triggerNow()` executes
- THEN the system MUST NOT re-read or overwrite the existing backup

### Requirement: Skip Live Wallpapers

The system MUST gracefully handle live wallpapers. When `getWallpaper` returns null, the backup operation SHALL be skipped without error.

#### Scenario: Live wallpaper detected

- GIVEN the user has a live wallpaper set
- WHEN the system attempts to read the wallpaper via `getWallpaper`
- THEN the method returns null
- AND the backup is skipped
- AND `hasBackup` remains false
- AND no crash or error dialog occurs

### Requirement: Restore Saved Wallpaper

The system MUST restore the saved backup via `wallpaper_manager_flutter`'s `setWallpaper()`. Both home and lock screens SHALL be updated.

#### Scenario: Successful restore

- GIVEN a valid backup file exists at `wallpaper_backup/original.png`
- WHEN the user confirms restore
- THEN the system calls `setWallpaper()` with the backup file
- AND both home and lock screens display the original wallpaper
- AND `hasBackup` remains true (backup is not consumed)

#### Scenario: Restore with missing backup file

- GIVEN `hasBackup == true` but the backup file is absent from disk
- WHEN the user attempts restore
- THEN the system MUST report a failure
- AND set `hasBackup = false` in SharedPreferences

### Requirement: Backup State Tracking

The system MUST persist backup state via a `hasBackup` boolean in SharedPreferences. This flag SHALL be set to false when the backup file is deleted or invalid.

#### Scenario: Flag cleared on missing file

- GIVEN `hasBackup == true`
- WHEN the system validates the backup and finds no file at expected path
- THEN `hasBackup` is set to false
