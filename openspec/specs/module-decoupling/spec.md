# module-decoupling Specification

## Purpose

Eliminate residual cross-module imports in the 8-module DDD Flutter app so any module can be commented out without breaking unrelated modules. Covers Verse model relocation (F1), backup event decoupling (F2), `modules.yaml` truthfulness (F3), and a decoupling-check harness command (F4).

## Requirements

| # | Requirement | Phase | Strength |
|---|-----------|-------|----------|
| R1 | Verse model resides in shared domain | F1 | MUST |
| R2 | Verses barrel re-exports Verse from shared | F1 | MUST |
| R3 | BackupRequested event replaces direct backup calls | F2 | MUST |
| R4 | BackupRestored emitted by backup service on restore | F2 | MUST |
| R5 | modules.yaml declares real cross-module deps only | F3 | MUST |
| R6 | check-decoupling command validates against modules.yaml | F4 | MUST |

### R1: Verse Model in Shared Domain

The Verse data model MUST reside in `lib/shared/domain/verse.dart`. The `shared` module SHALL NOT depend on any feature module.

#### Scenario: Shared module compiles without verses

- GIVEN the verses module is deleted or commented out
- WHEN the project is compiled
- THEN the shared module compiles without errors

#### Scenario: Existing consumers unaffected

- GIVEN a file importing Verse via `package:vers_reminder/verses/verses.dart`
- WHEN the Verse model is moved to shared
- THEN the import resolves via barrel re-export
- AND `fromMap`, `toMap`, `copyWith`, `textFor` behave identically

### R2: Verses Barrel Re-export

The `lib/verses/verses.dart` barrel MUST re-export Verse from `shared/domain/verse.dart`. Internal verses consumers SHALL resolve Verse through the barrel.

#### Scenario: Barrel preserves public API

- GIVEN `verse_provider` imports Verse via `verses/verses.dart`
- WHEN Verse moves to `shared/domain/verse.dart`
- THEN `verses.dart` re-exports Verse
- AND `verse_provider` compiles without import path changes

### R3: BackupRequested Event

Modules that need backup MUST emit `BackupRequested(path)` via the event bus. The backup service SHALL subscribe. No module other than backup SHALL import `WallpaperBackupService` directly.

#### Scenario: Wallpaper triggers backup via event

- GIVEN the wallpaper module needs to save a backup
- WHEN backup is requested
- THEN `BackupRequested(path)` is emitted on the event bus
- AND wallpaper has no direct import of `WallpaperBackupService`

#### Scenario: Settings triggers backup via event

- GIVEN the settings module needs to save a backup
- WHEN backup is requested
- THEN `BackupRequested(path)` is emitted on the event bus
- AND settings has no direct import of `WallpaperBackupService`

### R4: BackupRestored Event

The backup service MUST emit `BackupRestored(success: bool)` on restore completion. The home module SHALL subscribe.

#### Scenario: Restore notifies home via event bus

- GIVEN the backup service completes a restore
- WHEN restore finishes
- THEN `BackupRestored(success: true/false)` is emitted
- AND home module receives the notification
- AND home has no direct import of `WallpaperBackupService`

### R5: Honest modules.yaml

`tool/modules.yaml` MUST declare exactly the real cross-module dependencies and active events. Stale deps and phantom events SHALL be removed.

#### Scenario: Missing dependency declared

- GIVEN settings imports from scheduler
- WHEN `modules.yaml` is validated
- THEN settings→scheduler dependency is declared

#### Scenario: Stale wallpaper deps removed

- GIVEN wallpaper no longer directly imports scheduler or notifications
- WHEN `modules.yaml` is validated
- THEN wallpaper has no dependency on scheduler or notifications

#### Scenario: Phantom events removed, classes preserved

- GIVEN `PermissionGranted` and `VerseAdded` are never emitted or subscribed
- WHEN `modules.yaml` is validated
- THEN these events are absent from YAML event declarations
- AND the event classes remain in `events.dart` commented as dormant

### R6: Decoupling Check Command

`dart run tool/harness.dart check-decoupling` MUST scan all source imports against `modules.yaml` and report violations. Exit 0 on zero violations, non-zero otherwise.

#### Scenario: Undeclared cross-module import detected

- GIVEN `foo.dart` in module A imports from module B
- AND `modules.yaml` does not declare A→B
- WHEN `check-decoupling` runs
- THEN the violation is reported
- AND exit code is non-zero

#### Scenario: Barrel bypass detected

- GIVEN a cross-module import uses `settings/infrastructure/settings_screen.dart`
- AND the settings barrel exists at `settings/settings.dart`
- WHEN `check-decoupling` runs
- THEN the barrel bypass is flagged

#### Scenario: Clean run with zero violations

- GIVEN all cross-module imports match declared deps and use barrels
- AND `modules.yaml` has no phantom events
- WHEN `check-decoupling` runs
- THEN zero violations are reported
- AND exit code is 0
