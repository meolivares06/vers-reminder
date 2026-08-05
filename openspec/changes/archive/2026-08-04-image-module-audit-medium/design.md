# Design: Fix MEDIUM-Severity Image Module Error Silencing & Async Gaps

## Technical Approach

Four isolated `debugPrint` + `try/catch` additions at specific error-silencing sites. No behavior changes — every catch block that currently swallows the exception with `catch (_)` gets a `debugPrint` log before the existing fallback. One comment-only addition to `settings_provider.dart` documenting Flutter 3.7+ ChangeNotifier dispose safety.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| F8: `renderOnly` log | `catch (e) { debugPrint(...); return null; }` | Stack trace logging, structured logging | Proposal added `$st`; user chose minimal `$e` only. Single-line change, no deps. |
| F9: triggerNow boundaries | Inline `try/catch` + `debugPrint` at both call sites | `runZonedGuarded`, promise-chain `.catchError` | VoidCallback pattern precludes `async/await`. Inline `try/catch` is simplest, zero-deps. |
| F10: `compute` fallback | `catch (e) { debugPrint(...); return syncFallback(); }` | Re-throw, structured error envelope | Fallback is preserved — logging is additive, riskless. |
| F11: notifyListeners guard | Comment documenting Flutter 3.7+ safety; no runtime guard | `_disposed` flag (proposal), `if (mounted)` in ChangeNotifier (impossible) | ChangeNotifier tracks disposed state internally since Flutter 3.7. Runtime guards are dead code on current minimum. Comment is documentation, not logic. |

## Data Flow

No data flow changes. Each fix sits at an existing error boundary:

```
renderOnly() ──catch──▶ debugPrint ──▶ return null  (F8)
compute()    ──catch──▶ debugPrint ──▶ sync fallback (F10)
triggerNow  ──try/catch──▶ debugPrint ──▶ swallow   (F9)
notifyListeners() ──▶ [Flutter 3.7+ internal guard] (F11 — comment only)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Modify | F8 (L176): log renderOnly error. F10 (L421): log isolate encode error. |
| `lib/screens/home_screen.dart` | Modify | F9a (L84): try/catch dialog triggerNow. F9b (L342): try/catch _triggerNow body. F11 optional (L84,L344): `if (mounted)` guard. |
| `lib/providers/settings_provider.dart` | Modify | F11 (L289, L344): comment documenting Flutter 3.7+ ChangeNotifier dispose safety. |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | F8: renderOnly error path logs to console | Inject a failing `_render` mock; assert `debugPrint` called and returns null |
| Unit | F10: compute failure logs before fallback | Force `compute` to throw; assert log + sync fallback result |
| Unit | F9b: _triggerNow exception is caught | Mock `triggerNow` to throw; assert VoidCallback doesn't propagate exception |
| Integration | Existing suite | `flutter test --no-pub` — all must pass (no behavior change) |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary changes. The `compute` isolate path logs the error but does not alter the execution model.

## Migration / Rollout

No migration required. All changes are additive logging or documentation.

## Open Questions

None.
