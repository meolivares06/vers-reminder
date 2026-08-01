# Tasks: PR 1 — Data Cleanup (auto-update-and-cleanup)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| File: `lib/services/temp_cleanup_service.dart` | ~45 lines |
| File: `lib/services/update_cleanup_service.dart` | ~45 lines |
| File: `lib/main.dart` | ~+5 lines |
| File: `test/.../temp_cleanup_service_test.dart` | ~110 lines |
| File: `test/.../update_cleanup_service_test.dart` | ~90 lines |
| Estimated total changed lines | ~295 (target <200) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

> Note: total edges to ~295 with tests but under the 400 budget; code-only is ~95. Small, standalone, no chaining.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Data cleanup services + hook + tests | PR 1 | Standalone, merges to main. |

## Phase 1: Services (Foundation)

- [x] 1.1 `lib/services/temp_cleanup_service.dart` — Singleton (`TempCleanupService.instance` + `_internal()`); `Future<int> cleanTempWallpapers({String? tempDirOverride})` resolves dir (override or `getTemporaryDirectory()`), reads `last_wallpaper_path` fresh via `prefs.getString`, lists `wallpaper_*.png` (basename startsWith `wallpaper_` && endsWith `.png`), deletes all except referenced abs path, catches `PathNotFoundException` per-file, returns count deleted, logs with `print()`.
- [x] 1.2 `lib/services/update_cleanup_service.dart` — Singleton (`UpdateCleanupService.instance` + `_internal()`); `updatesDir({String? appSupportOverride})` returns `{appSupport}/updates` and ensures it exists (create recursive); `cleanUpdatesDir({String? appSupportOverride})` deletes any `*.apk` in updates dir defensively (`on PathNotFoundException`), returns count; logs with `print()`.

## Phase 2: Integration (Wiring)

- [x] 2.1 `lib/main.dart` — after `WidgetsFlutterBinding.ensureInitialized()` (after screen-dim cache, before `runApp`), fire-and-forget `TempCleanupService.instance.cleanTempWallpapers()` (non-blocking). Do NOT call `UpdateCleanupService` from startup (PR 2 owns it). *(PR 2 note: `UpdateCleanupService` is now wired in PR 2's `UpdateService.download()` — it calls `cleanUpdatesDir()` before each download and `updatesDir()` for the destination — see `update_service.dart`.)*

## Phase 3: Tests

- [x] 3.1 `test/services/temp_cleanup_service_test.dart` — `TestWidgetsFlutterBinding`, `SharedPreferences.setMockInitialValues`, `Directory.systemTemp` subdir, pass `tempDirOverride`. Sc.1: orphan sweep (3 files, prefs elsewhere → all deleted). Sc.2: preserves `last_wallpaper_path` (keeper intact, others gone, count=1). Sc.3: no prefs → delete all. Sc.4: empty dir → no-op, count 0. Sc.5: mid-sweep missing file → caught, no throw.
- [x] 3.2 `test/services/update_cleanup_service_test.dart` — `TestWidgetsFlutterBinding`, `Directory.systemTemp` subdir, pass `appSupportOverride`. Sc.1: creates updates dir. Sc.2: deletes old `*.apk`. Sc.3: empty updates dir → no-op. Sc.4: absent updates dir → creates it, no-op. Sc.5: missing-at-delete tolerated (defensive, no throw).
- [x] 3.3 Run `flutter test test/services` — all suite passes.

## Phase 4: Cleanup / Docs

- [x] 4.1 Verify `flutter analyze` clean; confirm no other code touches the new services (UpdateCleanupService unused until PR 2 wires it).
