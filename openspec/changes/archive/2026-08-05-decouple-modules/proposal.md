# Proposal: Decouple Cross-Module Imports

## Intent

The 8-module DDD refactor left 16 residual cross-module imports across 7 files. The user's goal: "comment out any module and nothing breaks." Current violations:

| # | Violation | Impact |
|---|-----------|--------|
| 1 | **shared→verses** — `database_service.dart` + `verse_tile.dart` import `verses/domain/verse.dart`. Foundation layer depends on a feature. Compile cycle (verses also imports shared's `DatabaseService`). | Commenting out verses breaks shared → breaks everything. |
| 2 | **settings→scheduler undeclared** — `settings_screen.dart` imports `scheduler_config` but `modules.yaml` doesn't list it. | modules.yaml is misleading. |
| 3 | **wallpaper→backup direct** — `wallpaper_state.dart` calls `WallpaperBackupService` directly (2 sites). `BackupRestored` event declared but unimplemented. | Breaks decoupling goal. |
| 4 | **3 phantom events** — `PermissionGranted`, `BackupRestored`, `VerseAdded` in `modules.yaml` but never emitted/subscribed. Only 5/8 events are real. | modules.yaml inflates the event surface. |
| 5 | **Zero barrel imports** — all 16 cross-module imports use direct internal paths (e.g., `settings/infrastructure/settings_screen.dart`), not barrels. Barrels exist but are decorative. | No contract enforcement. |

## Scope

### In Scope

- **F1**: Move `Verse` (pure data model: `fromMap`, `toMap`, `copyWith`, `textFor`) from `lib/verses/domain/verse.dart` into `lib/shared/domain/verse.dart`. Update `database_service.dart`, `verse_tile.dart`, `wallpaper_generator.dart`, `verse_provider`, `seed_loader`, `verses.dart` barrel re-export, `modules.yaml`. Kills the shared→verses reverse edge + compile cycle.
- **F2**: Complete backup decoupling via events. Add `BackupRequested` event (emit wallpaper_state/settings → receive backup). Refactor `BackupRestored` to be emitted by backup service on restore completion (receive home). Replace 2 direct `WallpaperBackupService` imports. Same pattern as `NotificationRequested`.
- **F3**: Make `modules.yaml` honest. Add `settings→scheduler` dep. Remove stale wallpaper deps (`scheduler`, `notifications` — already event-bus). Remove `PermissionGranted` and `VerseAdded` from YAML event declarations. Keep event classes in `events.dart` as dormant for future use. `BackupRestored` becomes real (F2).
- **F4**: Add `check-decoupling` command to `tool/harness`. Verifies: (a) no cross-module import missing from deps, (b) cross-module imports use barrels (with exceptions list for internal DDD layers), (c) phantom events flagged.

### Out of Scope

- **PermissionGranted implementation** — home reads `wallpaperPermissionGranted` from `WallpaperState` synchronously (normal DDD presentación→aplicación pattern). No event needed.
- **VerseAdded implementation** — `verse_provider` is imported directly by 6 consumers for verse list reading. Replacing with event bus would be over-engineering.
- Changing any module's behavior or public API.
- Enforcing barrel imports for intra-module imports (same-module files).

## Success Criteria

- [ ] `check-decoupling` reports ZERO violations against `modules.yaml`
- [ ] Commenting out `backup/`, `notifications/`, or `verses/` does not break build of other modules
- [ ] `flutter test --no-pub` passes unchanged (zero behavioral changes)
- [ ] `modules.yaml` declares exactly the real cross-module dependencies (no stale, no missing)
