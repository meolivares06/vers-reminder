# Temp Cleanup

## Description

Prevents unbounded disk growth from foreground wallpaper generation by sweeping temporary wallpaper files (`wallpaper_*.png`) on app start, preserving only the currently referenced wallpaper.

## Requirements

### Requirement: Temp wallpaper cleanup

The system MUST maintain a `TempCleanupService` that, on app start, sweeps `getTemporaryDirectory()` for files matching `wallpaper_*.png` and deletes every one EXCEPT the file whose absolute path equals `last_wallpaper_path` in SharedPreferences.

The system MUST treat the sweep defensively — a `PathNotFoundException` raised while listing or deleting MUST NOT propagate; the service SHOULD continue and log the failure. After the sweep the service MUST log the count of files deleted.

The system MUST NOT delete any other temp files, and MUST NOT touch `.apk` files, `user_background.png`, `wallpaper_backup/`, or the DB.

#### Scenario 1: Sweeps and deletes orphaned temp wallpapers

- GIVEN an app start where `getTemporaryDirectory()` contains `wallpaper_100.png`, `wallpaper_200.png`, and `wallpaper_300.png`, and `last_wallpaper_path` equals a path NOT among them
- WHEN `TempCleanupService` runs the sweep
- THEN the three `wallpaper_*.png` files are deleted
- AND the count of deleted files is logged

#### Scenario 2: Preserves the file referenced by `last_wallpaper_path`

- GIVEN an app start where `getTemporaryDirectory()` contains `wallpaper_100.png` and `wallpaper_200.png`, and `last_wallpaper_path` equals the absolute path of `wallpaper_100.png`
- WHEN `TempCleanupService` runs the sweep
- THEN `wallpaper_200.png` is deleted
- AND `wallpaper_100.png` is NOT deleted
- AND the log reports `1` file deleted

#### Scenario 3: Missing or no prefs deletes all temp wallpapers

- GIVEN an app start where `last_wallpaper_path` is absent from SharedPreferences
- AND `getTemporaryDirectory()` contains `wallpaper_100.png` and `wallpaper_200.png`
- WHEN `TempCleanupService` runs the sweep
- THEN both `wallpaper_200.png` and `wallpaper_100.png` are deleted
- AND the count of deleted files is logged

#### Scenario 4: No temp wallpapers means no-op without error

- GIVEN an app start where `getTemporaryDirectory()` contains no `wallpaper_*.png` files
- WHEN `TempCleanupService` runs the sweep
- THEN no files are listed as deleted
- AND no exception is thrown

#### Scenario 5: A file vanishes mid-sweep is tolerated

- GIVEN a sweep where a matching file is deleted by another process between list and delete
- WHEN `TempCleanupService` attempts deletion
- THEN the `PathNotFoundException` is caught and logged
- AND the sweep continues without aborting
