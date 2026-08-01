## Verification Report

**Change**: auto-update-and-cleanup — PR 1 (Data Cleanup)
**Sub-change**: cleanup (cleanup-temp + cleanup-updates)
**Version**: N/A (openspec delta specs)
**Mode**: Standard (strict_tdd: false)
**Artifact store**: openspec
**Date**: 2026-07-31

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 7 |
| Tasks complete | 7 |
| Tasks incomplete | 0 |

> Note: the tasks artifact counts **7** checkboxes (1.1, 1.2, 2.1, 3.1, 3.2, 3.3, 4.1), not 6 as stated in the launch brief. All 7 are `[x]`. Total is under the 400-line budget (~295 estimated; code-only ~95). No chaining needed.

### Build & Tests Execution
**Build**: ✅ Passed (dependencies resolved via `flutter test`/`flutter analyze`; no compile errors)

**Tests**: ✅ 99 passed / 0 failed / 0 skipped
```text
flutter test   → 00:11 +99: All tests passed!
```
Baseline 86 pre-existing + 13 new (7 temp + 6 update) = 99. New-suite breakdown:
- `temp_cleanup_service_test.dart`: 7/7 passed (Sc1, Sc2, Sc3, Sc4, Sc5, non-wallpaper untouched, variant)
- `update_cleanup_service_test.dart`: 6/6 passed (updatesDir created/reused, Sc2-5, non-apk untouched)

**Coverage**: ➖ Not available (no coverage threshold configured; `flutter test` does not enforce one)

**Analyze (new/changed files)**: ✅ No issues found
```text
flutter analyze lib/services/temp_cleanup_service.dart lib/services/update_cleanup_service.dart test/services/temp_cleanup_service_test.dart test/services/update_cleanup_service_test.dart
→ No issues found! (ran in 1.2s)
```
**Analyze (main.dart)**: ⚠️ 2 pre-existing info-level `use_build_context_synchronously` warnings at `lib/main.dart:114,117` inside `_AppEntryState._initialize`. The PR diff touches only imports + the `unawaited(...)` hook before `runApp`; lines 114/117 are in an untouched region (verified via `git diff lib/main.dart` = +6 lines, none in `_initialize`). These warnings are NOT introduced by this PR.

### Spec Compliance Matrix (10 scenarios)

| Requirement | Scenario | Covering Test | Result |
|-------------|----------|---------------|--------|
| cleanup-temp / Temp wallpaper cleanup | Sc.1: Sweeps and deletes orphaned temp wallpapers (prefs not among them → all deleted, count logged) | `temp_cleanup_service_test.dart > Sc.4 last_wallpaper_path pointing to missing file still cleans` (proves deletion when keeper path not among listed files, count returned) | ✅ COMPLIANT |
| cleanup-temp | Sc.2: Preserves file referenced by `last_wallpaper_path` | `temp_cleanup_service_test.dart > Sc.1 deletes orphans but preserves last_wallpaper_path` | ✅ COMPLIANT |
| cleanup-temp | Sc.3: Missing/no prefs deletes all temp wallpapers | `temp_cleanup_service_test.dart > Sc.2 with no prefs deletes all wallpaper files` | ✅ COMPLIANT |
| cleanup-temp | Sc.4: No temp wallpapers → no-op without error | `temp_cleanup_service_test.dart > Sc.3 empty temp dir returns 0 without error` | ✅ COMPLIANT |
| cleanup-temp | Sc.5: A file vanishes mid-sweep is tolerated | `temp_cleanup_service_test.dart > Sc.5 file missing mid-sweep does not abort` (deterministic simulation — file deleted pre-sweep; defensive `catch (_)` covers the genuine race) | ✅ COMPLIANT |
| cleanup-updates / Updates dir management | Sc.1: Cleans old APKs before new download | `update_cleanup_service_test.dart > Sc.2 deletes old apk files in updates dir` | ✅ COMPLIANT |
| cleanup-updates | Sc.2: Cleans partial file on failed download | `update_cleanup_service_test.dart > non-apk files are left untouched` (proves `.apk` deletion incl. the in-place current.apk; no dedicated failed-download API tested) | ⚠️ PARTIAL |
| cleanup-updates | Sc.3: Empty updates dir is a no-op | `update_cleanup_service_test.dart > Sc.3 empty updates dir is a no-op returning 0` | ✅ COMPLIANT |
| cleanup-updates | Sc.4: File missing at delete time is tolerated | `update_cleanup_service_test.dart > Sc.5 missing apk at delete time is tolerated without error` | ✅ COMPLIANT |
| cleanup-updates | Sc.5: Updates dir absent is handled | `update_cleanup_service_test.dart > Sc.4 absent updates dir is created and no-op returns 0` | ✅ COMPLIANT |

**Compliance summary**: 9/10 scenarios fully compliant, 1/10 PARTIAL (behavior present and apk-deletion mechanism tested, but the dedicated failed-download partial-cleanup path the spec describes is not a distinct-tested behavior and the design's `deleteFailedDownload(path)` API was not implemented).

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|-------------|--------|-------|
| `TempCleanupService.cleanTempWallpapers()` | ✅ Implemented | Resolves dir (`tempDirOverride` or `getTemporaryDirectory()`), fresh `prefs.getString('last_wallpaper_path')`, lists `wallpaper_*.png` (basename startsWith `wallpaper_` && endsWith `.png`), skips referenced abs path, defensive per-file delete, returns count, logs with `print()`. Handles absent dir via `if (!await dir.exists()) return 0`. |
| MUST NOT delete other temp files / `.apk` / `user_background.png` / `wallpaper_backup/` / DB | ✅ Implemented | Filename predicate `wallpaper_`+`.png` only; `entry is! File` guard; non-wallpaper untouched test passes. |
| `UpdateCleanupService.updatesDir()` | ✅ Implemented | Returns `p.join(appSupport, 'updates')`, creates recursive if absent, returns path string. |
| `UpdateCleanupService.cleanUpdatesDir()` | ✅ Implemented | Deletes only case-insensitive `*.apk` files (regular Files), defensive per-file, returns count, logs; not wired to startup. |
| Defensive delete (PathNotFoundException tolerated) | ✅ Implemented | Blanket `catch (_)` around per-file delete; sweep continues (see coherence deviation #2). |
| `main.dart` fire-and-forget hook | ✅ Implemented | `unawaited(TempCleanupService.instance.cleanTempWallpapers())` at `main.dart:50`, after `SharedPreferences` init + `ImageCacheService.init()`/`WallpaperScheduler.init()`, before `runApp`. NOT `await`ed (non-blocking). |
| UpdateCleanupService NOT wired to startup | ✅ Implemented | `main.dart` imports only `temp_cleanup_service.dart`; `UpdateCleanupService` referenced only in its own file and its test. |
| Override params are `String?` | ✅ Implemented | `tempDirOverride`, `appSupportOverride` are `String?` (per signature decision, overriding design's `Directory?`). |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Singleton services (`.instance` + `_internal()`) | ✅ Yes | Both services match convention. |
| Hook point: `main()` after screen-dim cache, before `runApp` | ✅ Yes | `main.dart:50`, correct placement. |
| Read `last_wallpaper_path` fresh inside service | ✅ Yes | `cleanTempWallpapers` calls `prefs.getString` per invocation; no provider cache. |
| File matching: basename startsWith `wallpaper_` && endsWith `.png` | ✅ Yes | `temp_cleanup_service.dart:37-38`. |
| Stale prefs path skip-if-referenced | ✅ Yes | Absolute-path equality `entry.path == keep`. |
| Updates dir `{appSupport}/updates` created lazily, full impl in PR 1, not wired | ✅ Yes | `updatesDir` create-recursive; not called from startup. |
| Defensive delete via `on PathNotFoundException` | ⚠️ Deviation | Design specified `on PathNotFoundException`; implementation uses blanket `catch (_)`. Documented in apply-progress: with `dir.list()` only yielding files present at list time, the missing-at-delete race is the single realistic case; `catch (_)` keeps real errors from aborting the sweep. Rationale accepted, but broader than the design allowed. |
| Injectable dir override as `Directory?` | ⚠️ Deviation | Design: `({Directory? tempOverride})`/`({Directory? dirOverride})`. Implementation per signature decision: `({String? tempDirOverride})`/`({String? appSupportOverride})`. Accepted, documented. |
| Interface `ensureUpdateDir()`/`cleanup()`/`deleteFailedDownload(path)` | ⚠️ Deviation | Design's interface replaced by tasks/signature `updatesDir()` + `cleanUpdatesDir()`. `deleteFailedDownload(path)` was dropped — see Sc.2-updates PARTIAL. Accepted per tasks artifact. |

### Issues Found

**CRITICAL**: None.
- 0 incomplete tasks, 99/99 tests pass, all source/spec requirements present.

**WARNING**:
1. **Sc.2-updates partially covered / `deleteFailedDownload` absent** — Spec scenario "Cleans partial file on failed download" has no dedicated covering test, and the design's `deleteFailedDownload(path)` API was removed (per tasks/signature decision). Functionally, `cleanUpdatesDir()` deletes all `.apk` files including a partial in-flight download, which is proven by the apk-deletion test. Consider either (a) a test explicitly simulating a failed-download partial cleaned, or (b) confirming PR 2 owns this path and will call `cleanUpdatesDir()` on failure. Non-blocking for PR 1.
2. **Deviation from design: blanket `catch (_)`** instead of `on PathNotFoundException` — wider than designed; mitigates the uncaught-race and per-file abort concern but silently swallows genuine IO errors (e.g. permission). Accepted in apply-progress; noted for awareness in PR 2.
3. **`main.dart` pre-existing analyzer warnings** (`use_build_context_synchronously` @114,117) — not introduced by this PR; out of scope but flagged so they are not attributed to the change if `flutter analyze` runs full-project in CI.

**SUGGESTION**:
1. Spec tests for the "orphan sweep" scenario (Sc.1-temp) rely on the stale-path test (`Sc.4`) to prove "delete when keeper not among listed files"; a dedicated 3-file orphan test would match the spec narrative literally. Behavior is proven; purely cosmetic.
2. `UpdateCleanupService` is intentionally unused in PR 1; confirm no analyzer "unused" warnings arise once wired (analyze is clean now because the public API is referenced by tests).

### Verdict
**PASS WITH WARNINGS**
All 7 tasks complete; 99/99 tests pass; 9/10 spec scenarios fully compliant (1 PARTIAL, behavior present); all key behaviors (temp sweep + preserve + defensive, updates dir + apk cleanup, main.dart hook, UpdateCleanupService not wired) verified against source and runtime evidence. Warnings are documented, accepted deviations and one indirect test-coverage gap — none block PR 1 or break a spec.
