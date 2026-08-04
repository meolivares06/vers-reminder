# Proposal: Fix CRITICAL Image Module Findings

## Intent

Fix 3 production bugs causing GPU memory leaks and UI thread blocking in the wallpaper generation pipeline. Each wallpaper generation leaks ~10MB of native GPU resources (PictureRecorder) and native paragraph layout objects (TextPainter) when exceptions propagate. Additionally, `SettingsProvider.init()` blocks app launch for seconds by awaiting wallpaper pre-generation synchronously.

## Scope

### In Scope
- **F1**: Guarantee `PictureRecorder` + `Canvas` disposal in `_compositeCanvas` finally block
- **F2**: Move `TextPainter`/`citationPainter` disposal to protected finally scope
- **F3**: Unblock `SettingsProvider.init()` — pre-generation runs fire-and-forget; `_isLoading = false` set immediately after config load

### Out of Scope
- HIGH findings: re-entrancy guards (F4), concurrent pre-gen (F5), sync I/O in build (F6), blocking init (F7 — F3 covers the critical subset)
- MEDIUM/LOW findings: error handling, disposal safety, dead code
- Full `WallpaperOrchestratorService` extraction — deferred to architecture refactor proposal

## Capabilities

### New Capabilities
- `resource-disposal`: deterministic cleanup of native Flutter resources (PictureRecorder, Canvas, TextPainter) in the composite pipeline, guaranteed on both success and exception paths

### Modified Capabilities
- `wallpaper-gen`: `_compositeCanvas` must dispose all native resources in `finally`; `init()` must not synchronously await pre-generation

## Approach

**F1** — Move `PictureRecorder` + `Canvas` creation inside the existing `try` block so the `finally` clause naturally scopes them alongside `bg`. Alternative: add explicit `recorder.dispose()` call in `finally` before `bg.dispose()`. Prefer the scoping approach — less error-prone.

**F2** — Wrap `textPainter`/`citationPainter` usage in a nested `try/finally` that guarantees disposal regardless of where the exception occurs within the composite try block.

**F3** — Split `init()`: load config + prefs + re-register WorkManager → set `_isLoading = false` → notify. Then launch `_preGenerateFutureWallpapers()` as an unawaited fire-and-forget with its own error boundary. The loading spinner disappears immediately; pre-generation completes in background.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart:248-416` | Modified | F1 + F2: resource disposal scoping |
| `lib/providers/settings_provider.dart:117-153` | Modified | F3: unblock init, fire-and-forget pre-gen |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Fire-and-forget pre-gen fails silently, user sees stale wallpapers | Low | Log errors; WorkManager callback regenerates on next tick |
| `finally` restructuring changes exception propagation | Low | Preserve existing catch semantics; add only disposal guards |
| Changed init order breaks `_isLoading` dependent widgets | Low | `_isLoading` transitions earlier — widgets that assumed blocking will show content sooner (desired) |

## Rollback Plan

Revert the commit. All changes are scoped to two files with no schema or persistence changes. `git revert` restores original behavior.

## Dependencies

- Existing unit tests for `WallpaperGenerator` and `SettingsProvider` must pass before and after
- No new packages, no DB migration

## Success Criteria

- [ ] `PictureRecorder` disposed on all code paths through `_compositeCanvas` (verified by leak detector / dev tools)
- [ ] `TextPainter`/`citationPainter` disposed when exception occurs between creation and composite paint
- [ ] `SettingsProvider.init()` sets `_isLoading = false` before pre-generation completes
- [ ] All existing tests pass without modification
- [ ] Manual smoke test: generate wallpaper 5× consecutively, confirm no GPU memory growth
