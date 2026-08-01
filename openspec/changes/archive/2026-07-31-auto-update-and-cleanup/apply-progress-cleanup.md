# Apply Progress — PR 1 Data Cleanup (auto-update-and-cleanup)

**Date**: 2026-07-31
**Mode**: Standard (strict_tdd: false)
**Artifact store**: openspec
**Delivery**: Single PR, ~295 lines, Low risk, no decision needed

## Completed Tasks

- [x] **1.1** `lib/services/temp_cleanup_service.dart` — Singleton `TempCleanupService.instance` + `_internal()`. `Future<int> cleanTempWallpapers({String? tempDirOverride})` resolves dir (override or `getTemporaryDirectory()`), reads `last_wallpaper_path` fresh via `prefs.getString`, lists `wallpaper_*.png` (basename startsWith `wallpaper_` && endsWith `.png`), deletes all except referenced abs path, wraps per-file delete in defensive `catch (_)`, returns count deleted, logs with `print()`.
- [x] **1.2** `lib/services/update_cleanup_service.dart` — Singleton `UpdateCleanupService.instance` + `_internal()`. `Future<String> updatesDir({String? appSupportOverride})` returns `{appSupport}/updates` and ensures it exists (create recursive). `Future<int> cleanUpdatesDir({String? appSupportOverride})` deletes any `*.apk` (case-insensitive `.apk` suffix) defensively, returns count, logs with `print()`. Not wired to startup (PR 2 owns it).
- [x] **2.1** `lib/main.dart` — after screen-dim cache, before `runApp`, fire-and-forget `unawaited(TempCleanupService.instance.cleanTempWallpapers())`. Added `import 'dart:async'` and `import 'services/temp_cleanup_service.dart'`. `UpdateCleanupService` intentionally NOT called from startup.
- [x] **3.1** `test/services/temp_cleanup_service_test.dart` — `TestWidgetsFlutterBinding`, `SharedPreferences.setMockInitialValues`, `Directory.systemTemp` subdir, pass `tempDirOverride`. 7 tests: Sc.1 preserve last_wallpaper_path (count 1), Sc.2 no prefs → delete all, Sc.3 empty dir no-op (0), Sc.4 stale last_wallpaper_path → deletes orphans, Sc.5 mid-sweep missing file → no throw, plus non-wallpaper untouched and a variant.
- [x] **3.2** `test/services/update_cleanup_service_test.dart` — `Directory.systemTemp` subdir, pass `appSupportOverride`. 6 tests: Sc.1 creates updates dir, Sc.1b reuses existing, Sc.2 deletes old apks, Sc.3 empty no-op, Sc.4 absent dir created + no-op, Sc.5 missing apk tolerated, plus non-apk untouched.
- [x] **3.3** Full `flutter test` passes — **99/99** (baseline 86 + 13 new). Task description target was 86/86 or more; suite is green.
- [x] **4.1** `flutter analyze` — no NEW issues from this PR. My 4 new/modified files (2 services + 2 tests) report **No issues found**. The only `use_build_context_synchronously` warnings in `lib/main.dart` (lines 114/117) are pre-existing in `_AppEntryState._initialize` (confirmed via stash comparison), untouched by this change.

## Signature Decision Reconciliation

The orchestrator's signature decision (which wins over the design) used **`String?` override params**:
- `cleanTempWallpapers({String? tempDirOverride})`
- `updatesDir({String? appSupportOverride})`
- `cleanUpdatesDir({String? appSupportOverride})`

This deviates from `design-cleanup.md`, which specified `({Directory? tempOverride})` and `({Directory? dirOverride})`. Followed the signature decision: `String?` params let tests pass paths directly. Tests override `path_provider`/dirs via the string param, so `path_provider` is never invoked in those tests.

## Deviations from Design

1. **Override params are `String?` not `Directory?`** — per orchestrator signature decision, supersedes design's `Directory? tempOverride`/`Directory? dirOverride`.
2. **Defensive delete uses blanket `catch (_)`** with inline `// ignore` comment instead of design's `on PathNotFoundException`. Rationale: `dir.list()` only yields files present at list time, so a file that vanished mid-sweep between `list()` and `delete()` is the only realistic race; the task's sample code specified `catch (_)`. This intentionally keeps real errors from aborting the sweep while matching the orchestrator-provided implementation.
3. **Design's `ensureUpdateDir()` / `cleanup()` / `deleteFailedDownload()` interface** was not used; the tasks artifact (which the signature decision overrides) specifies `updatesDir()` + `cleanUpdatesDir()`. Followed tasks/signature.
4. Sc.5-temp scenario implemented by deleting the file "pre-sweep" (matching the design's testing-matrix note "delete file pre-sweep or invoke PathNotFound path") — deterministic in a unit test. The genuine mid-list race is covered by the defensive `catch (_)`.

## Issues Found

- **`Directory get x =>` is illegal inside a function body**: Dart does not allow property/getter declarations inside `main()`; the analyzer misparses it as a local `get` variable. Originally wrote the update test with a getter-inside-`main` helper (`Directory get updatesFolder`) which produced confusing `Directory Function()` errors. Resolved by inlining explicit `Directory(...)` local variables per test. Worth remembering for the codebase conventions.
- **Generated plugin files** (`linux/flutter/generated_plugin_registrant.cc`, `macos/Flutter/GeneratedPluginRegistrant.swift`, etc.) are modified in the working tree by the `flutter test`/`flutter analyze` toolchain (regenerated plugin registration). These are environment artifacts, NOT part of this PR's scope; left untouched. They appear in `git status` but should not be committed with this change.
- Executing the implementation involved a `git stash`/pop that conflicted on those generated files; resolved by restoring `lib/main.dart` from the stash and dropping it (stash verified: only `main.dart` + generated plugin files, no data loss).

## File Change Manifest

| File | Action |
|------|--------|
| `lib/services/temp_cleanup_service.dart` | Created |
| `lib/services/update_cleanup_service.dart` | Created |
| `lib/main.dart` | Modified (imports + `unawaited(...)` hook) |
| `test/services/temp_cleanup_service_test.dart` | Created |
| `test/services/update_cleanup_service_test.dart` | Created |
| `openspec/changes/auto-update-and-cleanup/tasks-cleanup.md` | Updated ([x] all 6) |

## Next

Ready for `sdd-verify`.
