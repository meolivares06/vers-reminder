# Proposal: Fix HIGH-Severity Image Module Race Conditions & UI Jank

## Intent

Fix three HIGH-severity concurrency defects from the image module audit: (1) `triggerNow` races on SharedPreferences/DB when double-tapped, (2) `_preGenerateFutureWallpapers` file-system contention from overlapping invocations, (3) `File.existsSync()` blocking the UI raster thread on every Home screen rebuild.

## Scope

### In Scope
- **F4**: Re-entrancy guard on `triggerNow` — skip when status is `generating`; retry allowed after error
- **F5**: Mutual-exclusion guard for `_preGenerateFutureWallpapers` — prevent overlapping pre-gen batches
- **F6**: Replace `File.existsSync()` in `home_screen.dart:195` with state-cached async existence check

### Out of Scope
- F1, F2 (CRITICAL: PictureRecorder/TextPainter leaks) — already shipped in fb1454a
- F3, F7 (architecture refactor + init blocking) — resolved by CRITICAL tier
- F8-F16 (MEDIUM/LOW) — deferred to cleanup tier

## Capabilities

### New Capabilities
- **`operation-guard`**: Wallpaper trigger and pre-generation operations prevent concurrent execution via status check + mutex token, eliminating race conditions on SharedPreferences, database reads, and pre-generated file I/O.

### Modified Capabilities
- **`home-ux`**: Wallpaper card existence check (UX-HOME-001) MUST use a cached async boolean instead of synchronous `File.existsSync()` during widget build.

## Approach

**F4 — `triggerNow` guard**: Add early-return after the `_activeCategoryIds.isEmpty` check and before setting `_status = generating`: `if (_status == WallpaperStatus.generating) return;`. On error, status resets to `error` — retry is not blocked.

**F5 — Pre-gen mutex**: Add `bool _isPreGenerating = false`. Entry check-and-set to `true`; `finally` block resets to `false`. Fire-and-forget callers (`init`, `setEnabled`) already use `unawaited` — the mutex adds the missing interlock between them and `triggerNow`'s awaited call.

**F6 — Async existence check**: Add `bool _wallpaperFileExists` to `_HomeTabState`. Set it via `addPostFrameCallback` after wallpaper generation completes. Replace the inline `File.existsSync()` with this cached flag.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/providers/settings_provider.dart` | Modified | F4 guard (after L256), F5 mutex (L347-372) |
| `lib/screens/home_screen.dart` | Modified | F6: remove `existsSync()`, add cached flag (L195) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Retry-after-error deadlock | Low | Guard only blocks `generating` — `error`/`noCategories` pass through |
| Pre-gen mutex blocks legitimate restart | Low | Mutex resets in `finally`; pre-gen is fire-and-forget |
| Stale `_wallpaperFileExists` flag | Low | Updated in `setState` after every `triggerNow` result |

## Rollback Plan

`git revert` the single commit. All changes are additive guards or field additions — no structural refactoring.

## Dependencies

- CRITICAL tier already committed (fb1454a) — F3 resolved F7

## Success Criteria

- [ ] Double-tapping FAB triggers exactly one `triggerNow` call (no duplicate SharedPreferences writes)
- [ ] Rapid scheduler toggle does not start concurrent pre-generation batches
- [ ] Home screen build method completes without sync file I/O (`existsSync` absent)
- [ ] All existing tests pass (`flutter test --no-pub`)
