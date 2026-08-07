# Design: Decouple Cross-Module Imports

## Technical Approach

Four-phase dependency cleanup on the 8-module DDD Flutter app. F1 kills the shared↔verses compile cycle by relocating the `Verse` data model. F2 completes backup decoupling following the existing `NotificationRequested` event pattern. F3 makes `modules.yaml` truthful. F4 adds an automated `check-decoupling` harness command to prevent regression.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Move Verse to shared vs keep in verses+re-export only | Verses owns the concept but shared is the foundation that shouldn't depend upward | **Move to shared** — Verse is a pure data record with zero verses-specific logic. Killing the compile cycle outweighs ownership purity |
| WallpaperState keeps reading backup flag from SharedPreferences vs subscribes to BackupRestored | Direct read is simpler but keeps SharedPreferences coupling; subscription adds wiring | **Both** — read from prefs in init() (with local constant, no backup import), subscribe to BackupRestored for runtime updates |
| BackupRequested with operation string vs separate Backup/Restore event classes | Separate classes are type-safe but inflate the event surface | **Single class with `operation` field** — mirrors how SettingsScreen and WallpaperState both need to request backup operations from the same service |
| Harness check-decoupling as separate command vs integrated into `validate` | Separate keeps validate fast and focused; integrated means one command | **Separate subcommand** — `validate` checks graph structure, `check-decoupling` checks import compliance. Different concerns, different exit criteria |

## Data Flow

```
SettingsScreen                        WallpaperState
     │                                      │
     │ _showRestoreDialog()                 │ triggerNow()
     │ emit(BackupRequested(                │ emit(BackupRequested(
     │   operation:'restore'))              │   operation:'backup'))
     │                                      │
     └──────────────┬───────────────────────┘
                    ▼
          ┌───────────────────────┐
          │ WallpaperBackupService │  init() subscribes to BackupRequested
          │  'backup' → backupCurrent()
          │  'restore' → restoreOriginal()
          │  → emit(BackupRestored(success, operation))
          └─────────┬─────────────┘
                    │
     ┌──────────────┼──────────────────────┐
     ▼              ▼                      ▼
SettingsScreen  WallpaperState        HomeContainer
subscribe to    subscribe to          subscribe to
BackupRestored  BackupRestored        BackupRestored
if op=='restore': if op=='backup'     setState → rebuild
  show snackbar    && success:
                    _hasBackup=true
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/shared/domain/verse.dart` | **Create** | Moved from `lib/verses/domain/verse.dart` — identical content, new location |
| `lib/verses/domain/verse.dart` | **Delete** | Relocated to shared |
| `lib/verses/verses.dart` | Modify | `export` line 1: change target to `package:vers_reminder/shared/domain/verse.dart` |
| `lib/shared/domain/database_service.dart` | Modify | L3: `import '...verses/domain/verse.dart'` → `import '...shared/domain/verse.dart'` |
| `lib/shared/widgets/verse_tile.dart` | Modify | L3: same import path update |
| `lib/wallpaper/infrastructure/wallpaper_generator.dart` | Modify | L13: same import path update |
| `lib/verses/application/verse_provider.dart` | Modify | L2: import path to shared |
| `lib/verses/application/seed_loader.dart` | Modify | L3: import path to shared |
| `lib/verses/widgets/verse_list_screen.dart` | Modify | L4: import path to shared |
| `lib/verses/widgets/verse_form_screen.dart` | Modify | L4: import path to shared |
| `lib/shared/event_bus/events.dart` | Modify | Add `BackupRequested{operation}`, modify `BackupRestored{success, operation}`, mark `PermissionGranted`/`VerseAdded` dormant |
| `lib/backup/infrastructure/wallpaper_backup_service.dart` | Modify | Add `init()` with `EventBus.instance.on<BackupRequested>` subscription; emit `BackupRestored` on completion |
| `lib/wallpaper/application/wallpaper_state.dart` | Modify | Remove `wallpaper_backup_service.dart` import; add local `_backupFlagKey` constant; replace L199-205 with `emit(BackupRequested(operation:'backup'))`; subscribe to `BackupRestored` in constructor |
| `lib/settings/infrastructure/settings_screen.dart` | Modify | Remove `wallpaper_backup_service.dart` import; add `events.dart` import; replace L308 with `emit(BackupRequested(operation:'restore'))`; subscribe to `BackupRestored` in initState for snackbar |
| `lib/home/application/home_container.dart` | Modify | Add `BackupRestored` subscription in initState → setState |
| `lib/main.dart` | Modify | Add `WallpaperBackupService.init()` after `NotificationService.init()` (L53) |
| `tool/modules.yaml` | Modify | F1: move verse.dart to shared files; F2: update BackupRestored emitters/receivers; F3: add settings→scheduler dep, remove phantom wallpaper deps & events |
| `tool/harness/cli.dart` | Modify | Add `check-decoupling` subcommand + usage text |
| `tool/harness/module_graph.dart` | Modify | `ModuleNode`: add `barrel`, `files`, `exceptions` fields; `fromYaml`: parse new fields; `moduleForFile`: unchanged (already works) |
| `tool/harness/decoupling_check.dart` | **Create** | ~150 lines: import scanner, cross-ref with graph, barrel & phantom-event checks |
| `test/models/verse_test.dart` | Modify | L2: import path to shared |
| `test/database/database_test.dart` | Modify | L5: import path to shared |
| `test/providers/verse_provider_test.dart` | Modify | L5: import path to shared |
| `test/services/wallpaper_generator_test.dart` | Modify | L10: import path to shared |
| `test/widgets/verse_list_test.dart` | Modify | L6: import path to shared |
| `test/wallpaper/wallpaper_state_test.dart` | Modify | L14: import path to shared |

## Import Update Strategy (F1)

All 13 files that currently import `verses/domain/verse.dart` must update to the new canonical path `package:vers_reminder/shared/domain/verse.dart`. The `verses/verses.dart` barrel re-exports from shared so that existing consumers using `import 'package:vers_reminder/verses.dart'` continue working — but direct-path imports break because the file is deleted, not re-exported from the old path.

| File | Current Import (L#) | New Import |
|------|---------------------|------------|
| `lib/shared/domain/database_service.dart` (L3) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `lib/shared/widgets/verse_tile.dart` (L3) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `lib/wallpaper/infrastructure/wallpaper_generator.dart` (L13) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `lib/verses/application/verse_provider.dart` (L2) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `lib/verses/application/seed_loader.dart` (L3) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `lib/verses/widgets/verse_list_screen.dart` (L4) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `lib/verses/widgets/verse_form_screen.dart` (L4) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `test/models/verse_test.dart` (L2) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `test/database/database_test.dart` (L5) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `test/providers/verse_provider_test.dart` (L5) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `test/services/wallpaper_generator_test.dart` (L10) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `test/widgets/verse_list_test.dart` (L6) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |
| `test/wallpaper/wallpaper_state_test.dart` (L14) | `verses/domain/verse.dart` | `shared/domain/verse.dart` |

## Event Definitions

```dart
/// Requests backup or restore of the original system wallpaper.
///
/// Emitted by WallpaperState (backup) and SettingsScreen (restore).
/// Consumed by WallpaperBackupService via [EventBus].
class BackupRequested {
  final String operation; // 'backup' | 'restore'
  const BackupRequested({required this.operation});
}

/// Signals completion of a backup or restore operation.
///
/// Emitted by WallpaperBackupService after handling BackupRequested.
/// Consumed by WallpaperState, SettingsScreen, and HomeContainer.
class BackupRestored {
  final bool success;
  final String operation; // 'backup' | 'restore'
  const BackupRestored({required this.success, required this.operation});
}
```

Dormant classes (kept in `events.dart`, marked with `// Dormant — reserved for future use`):
- `PermissionGranted` — home reads `wallpaperPermissionGranted` synchronously, no event needed
- `VerseAdded` — verse_provider is imported directly by 6 consumers, event bus over-engineering

## Backup Service Refactoring

**Before**: direct singleton calls
```dart
// wallpaper_state.dart L200
final saved = await WallpaperBackupService.instance.backupCurrent();

// settings_screen.dart L308
final success = await WallpaperBackupService.instance.restoreOriginal();
```

**After**: event bus dispatch + subscription
```dart
// wallpaper_state.dart — emit (no await)
EventBus.instance.emit(const BackupRequested(operation: 'backup'));

// settings_screen.dart — emit (no await)
EventBus.instance.emit(const BackupRequested(operation: 'restore'));

// wallpaper_backup_service.dart — init() registers handler
void init() {
  EventBus.instance.on<BackupRequested>((event) async {
    final ok = event.operation == 'backup'
        ? await backupCurrent()
        : await restoreOriginal();
    EventBus.instance.emit(BackupRestored(
      success: ok, operation: event.operation,
    ));
  });
}
```

**WallpaperState import removal**: L105 currently uses `WallpaperBackupService.backupFlagKey` to read the boolean from SharedPreferences. Replace with a private constant `static const _backupFlagKey = 'has_wallpaper_backup'` and keep the prefs read. The `_hasBackup` flag is updated at runtime by subscribing to `BackupRestored` (operation=='backup', success→true).

## Harness Implementation: check-decoupling

### New class: `DecouplingCheck` (`tool/harness/decoupling_check.dart`)

```dart
class DecouplingCheck {
  final ModuleGraph graph;
  final YamlMap eventsSection;

  /// Runs all checks, returns list of violation strings.
  List<String> run();
}
```

### Import scanning (regex)

```
Pattern: ^\s*import\s+'package:vers_reminder/(.+\.dart)';
```
Extract group 1 → path relative to `lib/`. Determine source module (which module owns the file) via `graph.moduleForFile()`. Determine target module (first path segment before `/`). If source ≠ target and source != null → cross-module import.

### Checks

1. **Missing dep**: source module's deps list must contain target module. Exception list from `modules.yaml` `exceptions` field bypasses this check.
2. **Barrel bypass**: if the import crosses modules, the imported path must match the target module's `barrel` field (e.g., `wallpaper/wallpaper.dart`). Within same module, any path is allowed.
3. **Phantom events**: every event in `modules.yaml` events section must have `emitters` with ≥1 entry and `receivers` with ≥1 entry.

### CLI integration

`cli.dart` subcommand list: `['test', 'validate', 'check-decoupling']`. Usage: `dart run tool/harness.dart check-decoupling`. Exit code: number of violations (0 = clean).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit — Verse | `fromMap/toMap/copyWith/textFor` | `verse_test.dart` — update import path, zero behavioral change. Tests pass as-is after path update |
| Unit — BackupService | `backupCurrent`, `restoreOriginal`, `hasBackup` | `wallpaper_backup_service_test.dart` — no changes needed (service API unchanged, init() is new but tested via integration) |
| Unit — WallpaperState | hasBackup tracking, triggerNow backup emit | `wallpaper_state_test.dart` — update import path. Existing `setHasBackup` seam unchanged. Add event bus fake for BackupRequested emit verification |
| Integration — Restore flow | SettingsScreen → BackupRequested → BackupRestored → HomeContainer refresh | `settings_restore_test.dart` — update to emit event instead of direct call, verify BackupRestored triggers snackbar + UI refresh |
| Harness — check-decoupling | Missing deps, barrel bypasses, phantom events detected | New unit tests in `tool/test/` with YAML fixtures — test CLI parsing, regex extraction, cross-reference logic |
| Regression | Full suite | `flutter test --no-pub` must pass with zero behavioral differences |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Barrel Enforcement Strategy

The `check-decoupling` harness enforces barrel imports for cross-module dependencies:

1. Parse `modules.yaml` to extract each module's `barrel` path (e.g., `lib/wallpaper/wallpaper.dart`)
2. For every cross-module `import 'package:vers_reminder/X/Y.dart'`, check if `X/Y.dart` equals the target module's barrel. If not → violation
3. **Exception list**: `modules.yaml` `exceptions` entries (e.g., `"scheduler → wallpaper/wallpaper_generator.dart (isolate)"`) bypass both dep-declaration and barrel checks
4. Intra-module imports (same module) are never checked for barrel compliance — only cross-module
5. Test files (`test/`) are excluded from barrel enforcement (but cross-module dep checking still applies)

## Migration / Rollout

No data migration required. Each F is an independent commit. Rollback: `git revert` each commit. F1 is a file move — revert moves it back. F2 rewires events — revert restores direct calls. F3/F4 are YAML + harness only.

## Open Questions

- None
