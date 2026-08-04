# Tasks: Fix HIGH-Severity Image Module Race Conditions & UI Jank

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 80–120 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | F4+F5+F6: re-entrancy guard, pre-gen mutex, async file check | Single PR | `flutter test --no-pub test/providers/settings_provider_test.dart` | `flutter test --no-pub` | `git revert` the single commit — all changes are additive guards and field additions |

## Phase 1: F4 + F5 Guards (settings_provider.dart)

- [x] 1.1 RED: Write unit test for F4 re-entrancy — double `triggerNow` produces exactly one generation; assert generator called once (OP-GUARD-001: Concurrent trigger blocked)
- [x] 1.2 RED: Write unit test for F4 retry-after-error — set status to `error`, call `triggerNow`; assert guard passes and generation proceeds (OP-GUARD-001: Retry after error)
- [x] 1.3 GREEN: Add `if (_status == WallpaperStatus.generating) return;` early-return guard in `triggerNow` after L261 empty-check, before L263 status set
- [x] 1.4 RED: Write unit test for F5 mutex — call `_preGenerateFutureWallpapers` twice without await; assert generator invoked once; assert mutex resets on both success and exception (OP-GUARD-002: Mutex blocks concurrent, reset on success/exception)
- [x] 1.5 GREEN: Add `bool _isPreGenerating = false` field; guard entry in `_preGenerateFutureWallpapers` L347; reset to `false` in `finally`

## Phase 2: F6 Async File Check (home_screen.dart)

- [x] 2.1 RED: Write widget test for UX-HOME-001 — source-code grep assert `existsSync` absent from `_HomeTabState.build`; verify card renders with cached `_wallpaperFileExists` flag vs. placeholder (UX-HOME-001: Card shows updated label, empty state unchanged)
- [x] 2.2 GREEN: Add `bool _wallpaperFileExists = false` to `_HomeTabState`; replace `File.existsSync()` at L195 with cached flag; wire `addPostFrameCallback` after `triggerNow` to set flag to `true` via `setState` (UX-HOME-001: Flag updated after generation)

## Phase 3: Integration

- [x] 3.1 Run `flutter test --no-pub` — full suite passes, no regressions
- [x] 3.2 Run `flutter analyze --no-pub` — zero errors, zero warnings
