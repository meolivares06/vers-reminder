# Proposal: Image Module Audit — LOW Findings

## Intent

Apply five LOW-severity audit findings (F12–F16) from the image module review: document by-design cache limits, optimize file I/O in cache repair, remove dead calibration screen code, annotate TODOs, and document preview byte size.

## Scope

### In Scope
- **F12**: Add doc comment to `ImageCacheService._totalImages` explaining the 10-image limit is intentional and sufficient at current scale
- **F13**: Replace `readAsBytes()` with `openRead().take(2)` in `_repairCache` for magic-number validation
- **F14**: Delete dead `calibration_screen.dart` (461 lines) and its commented-out import in `settings_screen.dart`
- **F15**: Annotate TODO comments across the image module with issue numbers or dates
- **F16**: Add doc comment to `_cachedPreview` in `settings_screen.dart` explaining ~300KB is acceptable for preview use

### Out of Scope
- Cache eviction implementation (not needed at current scale)
- Full file-size optimization pass beyond F13
- Calibration screen replacement or refactor (code is dead, no replacement needed)
- TODO resolution (annotation only)

## Capabilities

> This section is the CONTRACT between proposal and specs phases.

### New Capabilities
None

### Modified Capabilities
None

## Approach

Five independent, single-file changes:

| Finding | File | Change |
|---------|------|--------|
| F12 | `lib/services/image_cache_service.dart` | Add doc comment on `_totalImages` |
| F13 | `lib/services/image_cache_service.dart` | `openRead().take(2)` replaces `readAsBytes()` |
| F14 | `lib/screens/calibration/calibration_screen.dart` | Delete file |
| F14 | `lib/screens/settings/settings_screen.dart` | Remove commented import |
| F15 | `lib/**/*.dart` (image module) | Add issue # or date to TODOs |
| F16 | `lib/screens/settings/settings_screen.dart` | Add doc comment on `_cachedPreview` |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/services/image_cache_service.dart` | Modified | Docs + optimized I/O |
| `lib/screens/calibration/calibration_screen.dart` | Removed | Dead code deletion |
| `lib/screens/settings/settings_screen.dart` | Modified | Remove dead import, add doc |
| `lib/**/*.dart` | Modified | TODO annotations |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| F13 changes cache repair I/O path | Low | Behavior unchanged — only reads first 2 bytes instead of full file |
| F14 deletes code still referenced elsewhere | Low | Confirmed: only reference is a commented-out import |
| F14 calibration screen was deferred functionality | Low | If needed, recover from git history |

## Rollback Plan

Revert the commit. All changes are independent — any single finding can be reverted without affecting others.

## Dependencies

None.

## Success Criteria

- [ ] `_totalImages` has a doc comment explaining the 10-image design decision
- [ ] `_repairCache` uses `openRead().take(2)` instead of `readAsBytes()`
- [ ] `calibration_screen.dart` is deleted and its commented import removed
- [ ] All image-module TODOs carry an issue number or date
- [ ] `_cachedPreview` has a doc comment noting 300KB is acceptable
- [ ] All existing tests pass unchanged
