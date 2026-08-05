# Tasks: Image Module Audit — LOW Findings

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10 additions, ~463 deletions (461 dead file + 2 commented import) |
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
| 1 | Apply all 5 LOW findings (F12–F16) | Single PR | `flutter test --no-pub` | N/A — doc, I/O optimization, and dead-code removal only; no runtime behavior change | `git revert <commit>`; each finding is independently revertable |

## Phase 1: Documentation

- [ ] 1.1 **F12**: Add doc comment on `_totalImages` at `lib/services/image_cache_service.dart:9` explaining the 10-image limit is intentional and sufficient at current scale
- [ ] 1.2 **F16**: Add doc comment on `_cachedPreview` at `lib/screens/settings/settings_screen.dart:57` explaining ~300KB is acceptable for preview use

## Phase 2: Code Improvements

- [ ] 2.1 **F13**: Replace `file.readAsBytes()` with `file.openRead().take(2)` in `_repairCache` at `lib/services/image_cache_service.dart:86` — only first 2 bytes needed for JPG magic-number check (0xFF 0xD8)
- [ ] 2.2 **F15**: Add issue number to TODO comment at `lib/screens/settings/settings_screen.dart:661` — annotate `TODO(#1123): Re-evaluate if calibration is needed after Canvas pipeline`

## Phase 3: Dead Code Removal

- [ ] 3.1 **F14**: Delete `lib/screens/calibration/calibration_screen.dart` (461 lines, confirmed unreferenced — only reference is a commented-out import)
- [ ] 3.2 **F14**: Remove commented-out import block at `lib/screens/settings/settings_screen.dart:23-24` — delete `// TODO: restore when calibration is re-evaluated` and `// import '../calibration/calibration_screen.dart'`

## Phase 4: Verification

- [ ] 4.1 Run `flutter test --no-pub` — all existing tests must pass unchanged
- [ ] 4.2 Run `flutter analyze` — no new warnings introduced
