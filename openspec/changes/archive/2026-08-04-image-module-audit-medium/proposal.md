# Proposal: Fix MEDIUM-Severity Image Module Error Silencing & Async Gaps

## Intent

Fix four MEDIUM-severity observability defects from the image module audit: (1) `renderOnly` swallows all errors silently, (2) unawaited `triggerNow` in dialog callbacks can become unhandled exceptions, (3) `compute` PNG encode fallback hides isolate failure reason, (4) `notifyListeners()` after async gaps lacks a dispose guard.

## Scope

### In Scope
- **F8**: Log the actual error in `renderOnly` (`wallpaper_generator.dart:176`) via `debugPrint` before returning null
- **F9**: Wrap unawaited `triggerNow` calls in `home_screen.dart:84` and `_triggerNow` (L342-348) with try/catch + `debugPrint`
- **F10**: Log the isolate error in `compute` PNG encode fallback (`wallpaper_generator.dart:421`) before falling back to sync encoding
- **F11**: Add `_disposed` flag guard before each `notifyListeners()` call after async gaps in `settings_provider.dart`

### Out of Scope
- F1-F7 (CRITICAL/HIGH) — already resolved or shipped in previous tiers
- F12-F16 (LOW) — deferred
- Structural refactoring beyond the specific error sites

## Capabilities

> This is a pure observability/defensive hardening change — no spec-level behavior modifications.

### New Capabilities
None.

### Modified Capabilities
None.

## Approach

**F8 — `renderOnly` error log**: Change `catch (_) { return null; }` to `catch (e, st) { debugPrint('renderOnly failed: $e\n$st'); return null; }`.

**F9 — TriggerNow error boundaries**: Wrap the dialog callback (L84) `settings.triggerNow(...)` in `try { await ... } catch (e, st) { debugPrint('...'); }`. Wrap the `_triggerNow` VoidCallback body (L344) similarly with `try/catch` — the VoidCallback cannot be made `async`, so use `runZonedGuarded` or inline catch.

**F10 — Compute fallback log**: Change `catch (_)` to `catch (e, st) { debugPrint('PNG encode isolate failed: $e\n$st'); return _encodePngWorker(...); }`.

**F11 — Dispose guard**: Add `bool _disposed = false;` field. In `dispose()`, set `_disposed = true; super.dispose()`. Guard the two `notifyListeners()` calls after the `await` gaps (L289 and L344) with `if (!_disposed) notifyListeners()`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Modified | F8 (L176), F10 (L421) — error logging |
| `lib/screens/home_screen.dart` | Modified | F9 (L84, L344) — error boundaries |
| `lib/providers/settings_provider.dart` | Modified | F11 — dispose guard on notifyListeners |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `runZonedGuarded` complexity for F9 VoidCallback | Low | Prefer inline try/catch with `scheduleMicrotask` for the unawaited void path |
| Dispose-after-async produces stale notifyListeners in edge case | Low | Guard is additive — no behavior change except silencing post-dispose errors |

## Rollback Plan

`git revert` the single commit. All changes are additive — one `debugPrint`, one `try/catch`, one `if` guard per site.

## Dependencies

- CRITICAL and HIGH tiers already resolved (F1-F7 shipped)

## Success Criteria

- [ ] `renderOnly` logs the actual error type/message to console on failure (not silent null)
- [ ] Dialog-triggered `triggerNow` exception reaches `debugPrint` instead of becoming unhandled
- [ ] Isolate PNG encode failure logs the isolate error before sync fallback
- [ ] `notifyListeners()` after async gap in disposed provider is silently skipped (no framework assertion)
- [ ] All existing tests pass (`flutter test --no-pub`)

## Proposal Question Round

All four findings are low-risk observability hardening — no product decisions, no UX changes, no spec modifications. The approach is mechanically clear from the source sites. Any concerns before I proceed to specs?
