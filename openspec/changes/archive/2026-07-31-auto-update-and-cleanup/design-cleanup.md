# Design: PR 1 — Data Cleanup

## Technical Approach

Fix the unbounded `wallpaper_{millis}.png` leak in `getTemporaryDirectory()` and prepare download-dir infrastructure for PR 2. Two singleton services (`TempCleanupService`, `UpdateCleanupService`) following the existing `ImageCacheService` / `WallpaperBackupService` singleton + `get*Directory()` conventions. Hooks into `main()`, runs on every app start, idempotent.

Implements `cleanup-temp` and `cleanup-updates` specs.

## Architecture Decisions

| # | Decision | Options / Tradeoff | Chosen |
|---|----------|--------------------|--------|
| 1 | Temp article | Singleton `TempCleanupService.instance.cleanTempWallpapers()` vs static helper. Singleton matches codebase (`instance` + private ctor). | Singleton service |
| 2 | Hook point | (a) `main()` after prefs, (b) `SettingsProvider.init()`, (c) new UpdateService init. `main()` is already async, is app bootstrap, needs no prefs cache; (b) couples a ChangeNotifier to I/O side-effect; (c) doesn't exist in PR 1. File ops on startup are tiny (handful of files). | `main()` after screen-dim cache, before `runApp` |
| 3 | Read `last_wallpaper_path` | Cache in provider vs re-read prefs at sweep. Must read prefs **fresh** inside the service — provider caches at init and a trigger could update it mid-session; sweep must see current value. | `prefs.getString('last_wallpaper_path')` inside `cleanTempWallpapers()` |
| 4 | File matching | `dir.list()`, filter `is File` + basename starts with `wallpaper_` and ends `.png`. Prefix+extension (no `.path` on temp). | `p.basename` startsWith/endsWith |
| 5 | Stale prefs path | If `last_wallpaper_path` points to a missing file, skip-if-referenced anyway. Cheap and safest: the path never matches a listed file, so nothing is wrongly preserved; skipping also can't resurrect a deleted file. | Skip-if-referenced; note edge |
| 6 | Updates dir owner | Create `{appSupport}/updates/` lazily on first cleanup. Implement `UpdateCleanupService.cleanup()` fully in PR 1 (spec Scenario 1-5) since PR 2 consumes it; calling it from app start is deferred to PR 2's download flow. | Full impl in PR 1, not wired to startup |
| 7 | Defensive delete | Wrap `File.delete()` per-file in `try/on PathNotFoundException` (fits spec Sc.4/Sc.5). Prefer `on PathNotFoundException` over blanket catch to keep real errors surfacing but never abort the sweep. | `try ... on PathNotFoundException` |
| 8 | Testability | Services take optional injectable dir + use real SharedPreferences mock. Tests override `path_provider` MethodChannel and use `Directory.systemTemp` (matches `wallpaper_backup_service_test.dart`). Optional `Directory? tempOverride` param defaulting to `getTemporaryDirectory()`. | Injectable dir param + mock channel |

*Note: orchestrator premise that `wallpaper_generator.dart` lacks `path_provider` is incorrect — it imports it (line 9) and calls `getTemporaryDirectory()` (line 528). No change needed there.*

## Data Flow

```
main()
  └─ TempCleanupService.instance.cleanTempWallpapers()
       ├─ prefs = SharedPreferences.getInstance()
       ├─ keep  = prefs.getString('last_wallpaper_path')      // fresh read
       ├─ for each File in getTemporaryDirectory()            // (or tempOverride)
       │    ├─ basename matches wallpaper_*.png?
       │    │    └─ path == keep ? skip : try file.delete()
       │    │         └─ on PathNotFoundException: log, continue
       └─ log deleted count

UpdateCleanupService.cleanup()
  ├─ dir = {getApplicationSupportDirectory()}/updates
  ├─ dir.exists() ? (reuse : create recursive)                // Sc.5 no-op/ensure
  ├─ for each *.apk in dir → defensive delete                // Sc.1 before download
  └─ (PR 2) deleteFailedDownload(path) → defensive delete     // Sc.2 partial
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/temp_cleanup_service.dart` | Create | Singleton; `cleanTempWallpapers({Directory? tempOverride})` sweep + defensive deletes |
| `lib/services/update_cleanup_service.dart` | Create | Singleton; `ensureDir()`, `cleanup()` (delete old `.apk`), `deleteFailedDownload(path)` |
| `lib/main.dart` | Modify | Call `TempCleanupService.instance.cleanTempWallpapers()` after screen-dim cache, before `runApp` |
| `test/services/temp_cleanup_service_test.dart` | Create | Unit tests per `cleanup-temp` scenarios |
| `test/services/update_cleanup_service_test.dart` | Create | Unit tests per `cleanup-updates` scenarios |

`settings_provider.dart` is NOT modified — cleanup reads prefs fresh itself.

## Interfaces / Contracts

```dart
class TempCleanupService {
  static final TempCleanupService instance = TempCleanupService._internal();
  // Returns number of files deleted.
  Future<int> cleanTempWallpapers({Directory? tempOverride});
}

class UpdateCleanupService {
  static final UpdateCleanupService instance = UpdateCleanupService._internal();
  Future<Directory> ensureUpdateDir();          // creates {appSupport}/updates lazily
  Future<void> cleanup({Directory? dirOverride}); // delete existing *.apk before download
  Future<void> deleteFailedDownload(String apkPath); // delete partial on failure
}
```

Filename match predicate: `p.basename(file.path).startsWith('wallpaper_') && .endsWith('.png')`. Absolute path comparison for `keep` (spec Sc.2).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Sweep deletes orphans (Sc.1) | temp dir with 3 files, prefs pointing elsewhere → all gone, count logged |
| Unit | Preserves referenced file (Sc.2) | prefs = abs path of one file → other deleted, keeper intact, count=1 |
| Unit | No prefs → delete all (Sc.3) | `setMockInitialValues({})` → both deleted |
| Unit | Empty dir no-op (Sc.4) | empty dir → no error, count 0 |
| Unit | Vanishing file tolerated (Sc.5) | delete file pre-sweep or invoke PathNotFound path → caught, sweep continues |
| Unit | `cleanup()` creates dir + clears old APKs (Sc.1,5) | ensure dir, place dummy `.apk`, run → gone |
| Unit | `deleteFailedDownload` partial (Sc.2) | dummy partial → removed |
| Unit | Missing-at-delete tolerant (Sc.4) | delete then re-run → no throw |

Setup: `TestWidgetsFlutterBinding.ensureInitialized()`, `SharedPreferences.setMockInitialValues({})`, mock `path_provider` channel → `Directory.systemTemp` subdir (matches `wallpaper_backup_service_test.dart`).

## Migration / Rollout

None. Runs idempotently each app start; safe to ship alone. `UpdateCleanupService` is additive and unused until PR 2 wires it.

## Open Questions

None.
