# Tasks: Decouple Cross-Module Imports

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
800-line budget risk: Medium

| Field | Value |
|-------|-------|
| Estimated changed lines | ~446 (PR1: ~84, PR2: ~117, PR3: ~245) |
| Suggested work units | PR 1 (F1+F3) → PR 2 (F2) → PR 3 (F4) |
| Tracker branch | `refactor/decouple-modules` |

Chain rules: PR 1 targets tracker; PR 2 targets PR 1 branch; PR 3 targets PR 2 branch. Only tracker merges to `main`.

| Unit | Focused test | Rollback |
|------|-------------|----------|
| PR 1 | `flutter test --no-pub` | `git revert` restores file+YAML |
| PR 2 | `flutter test --no-pub test/wallpaper/wallpaper_state_test.dart` | `git revert` restores direct calls |
| PR 3 | `dart run tool/harness.dart check-decoupling` | Delete `decoupling_check.dart`, revert cli+graph |

---

## PR 1: Verse Relocation (F1) + YAML Honesty (F3)

- [x] 1.1 Copy `lib/verses/domain/verse.dart` → `lib/shared/domain/verse.dart`
- [x] 1.2 Update 13 imports: `verses/domain/verse.dart` → `shared/domain/verse.dart`
- [x] 1.3 Update `lib/verses/verses.dart` barrel: export from `shared/domain/verse.dart`; delete `lib/verses/domain/verse.dart`
- [x] 1.4 Run `flutter test --no-pub` → all pass
- [x] 1.5 `tool/modules.yaml`: remove `scheduler`+`notifications` from wallpaper.deps; add `scheduler` to settings.deps; move `verse.dart` from verses.files to shared.files
- [x] 1.6 Remove `PermissionGranted`+`VerseAdded` from YAML events; mark classes dormant in `events.dart`

## PR 2: Backup Event Decoupling (F2)

- [x] 2.1 **RED**: Write unit test for `BackupRequested(operation)` + `BackupRestored(success, operation)`
- [x] 2.2 Add `BackupRequested{operation}` + update `BackupRestored{success, operation}` in `events.dart`
- [x] 2.3 **RED**: Write test for `WallpaperBackupService.init()` subscribes `BackupRequested` → emits `BackupRestored`
- [x] 2.4 Add `init()` to `WallpaperBackupService`: subscribe, dispatch backup/restore, emit result
- [x] 2.5 Call `WallpaperBackupService.init()` in `lib/main.dart` after `NotificationService.init()`
- [x] 2.6 **RED**: Write test for `WallpaperState.triggerNow()` emits `BackupRequested` via event bus
- [x] 2.7 Replace L105 backupFlagKey with `static const _backupFlagKey`; replace L199-205 with `emit(BackupRequested(operation:'backup'))` in `wallpaper_state.dart`
- [x] 2.8 Subscribe `BackupRestored` in `WallpaperState` constructor → set `_hasBackup`
- [x] 2.9 Replace L308 with `emit(BackupRequested(operation:'restore'))` in `settings_screen.dart`
- [x] 2.10 Subscribe `BackupRestored` in `SettingsScreen.initState` (snackbar) + `HomeContainer.initState` (setState)
- [x] 2.11 Remove dead `wallpaper_backup_service.dart` imports from `wallpaper_state.dart` + `settings_screen.dart`
- [x] 2.12 Run `flutter test --no-pub` → pass; update `modules.yaml` events: add `BackupRequested`, receivers for `BackupRestored`

## PR 3: check-decoupling Harness (F4)

- [x] 3.1 **RED**: Test `ModuleNode.fromYaml` parses `barrel`/`files`/`exceptions`
- [x] 3.2 Extend `ModuleNode` + `fromYaml` in `tool/harness/module_graph.dart`
- [x] 3.3 **RED**: Test missing-dep, barrel-bypass, phantom-event detection
- [x] 3.4 Create `tool/harness/decoupling_check.dart`: import scanner (regex `import 'package:vers_reminder/(.+)\\.dart'`), cross-ref deps, barrel check, phantom check
- [x] 3.5 Add `check-decoupling` subcommand to `tool/harness/cli.dart`
- [x] 3.6 Run `dart run tool/harness.dart check-decoupling` → exit 57 (57 barrel bypasses detected — tool works correctly, codebase has existing violations to address)

## Phase 5: Full Verification (DEFERRED — future barrel adoption work)

- [ ] 5.1 `flutter test --no-pub` → zero regression; `dart run tool/harness.dart check-decoupling` → exit 0
- [ ] 5.2 Delete `backup/`+`notifications/` → other modules compile
