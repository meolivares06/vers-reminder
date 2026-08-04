# Design: Fix CRITICAL Image Module Resource Leaks

## Technical Approach

Three targeted fixes to `wallpaper_generator.dart` and `settings_provider.dart` ensuring deterministic native resource disposal and non-blocking app initialization. No new files, dependencies, or schema changes.

## Architecture Decisions

| Decision | Options | Tradeoffs | Choice |
|----------|---------|-----------|--------|
| **D1: PictureRecorder cleanup** | A) Null-guarded `ui.Picture?` tracker with dispose in finally; B) Explicit `endRecording()` always in finally; C) RAII wrapper class | A is minimal and idiomatic — `picture = null` after success dispose prevents double-free; B forces wasted `endRecording()` on success path; C over-engineered for 2 resources | **A**: `ui.Picture? picture` declared before try; after success-path `picture.dispose()`, set `picture = null`; finally runs `picture?.dispose()` (no-op on success, disposes on error) |
| **D2: TextPainter disposal** | A) Nested try/finally per painter; B) List+forEach dispose in single finally; C) Move painters to finally block with nullable declarations | A is explicit, reverse-creation ordering, zero allocation; B requires list allocation and buries intent; C forces nullable declarations everywhere | **A**: `citationPainter` nested inside `textPainter`'s try/finally — both guaranteed disposed in reverse-creation order |
| **D3: Fire-and-forget pre-gen** | A) `unawaited()` + `.catchError()` log; B) `schedulePostFrameCallback()` wrapping; C) `Future.microtask()` | A simplest, no widget-tree dependency; B overkill (pre-gen doesn't need a frame); C equivalent but less explicit about fire-and-forget intent | **A**: `unawaited(_preGenerateFutureWallpapers(...).catchError((e, st) => debugPrint(...)))` — non-blocking, errors logged |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Modify | F1: Add `ui.Picture? picture` before try (L247). After success-path `picture.dispose()` at L393, insert `picture = null`. Add `picture?.dispose()` in finally (L414) before `bg.dispose()`. F2: Nest `citationPainter` inside `textPainter`'s try/finally; move both `dispose()` calls from L384-385 to respective finally blocks. |
| `lib/providers/settings_provider.dart` | Modify | F3: Move `_isLoading = false` + `notifyListeners()` before pre-gen call (after WorkManager re-registration). Wrap pre-gen in `unawaited(...catchError(log))`. Add `import 'dart:async';` if `unawaited` unresolved. Lines 117-153. |

## Data Flow (F1+F2: `_compositeCanvas` disposal scoping)

```
recorder, canvas created (before try)
  │
  └─→ try {
        bg draw, overlay, text layout
        textPainter created
          └─→ try {
                citationPainter created
                  └─→ try { paint both }
                  finally { citationPainter.dispose() }
              }
          finally { textPainter.dispose() }
        picture = recorder.endRecording()
        picture.dispose(); picture = null  ← success path
        encode & return
      }
      finally {
        picture?.dispose()  ← error path only (null-guarded via =null above)
        bg.dispose()
      }
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `_compositeCanvas`: exception between textPainter creation and `endRecording()` | Inject a forced exception after paint; assert `picture?.dispose()` and `bg.dispose()` called in finally |
| Unit | `_compositeCanvas`: exception between citationPainter creation and paint | Verify citationPainter disposed via inner finally, textPainter via outer finally |
| Unit | `SettingsProvider.init()` returns before pre-gen completes | Call `init()`; assert `_isLoading == false` immediately after; mock `_preGenerateFutureWallpapers` with delayed future; verify `notifyListeners` called before future resolves |
| Integration | 5× consecutive `_compositeCanvas` calls — no GPU memory growth | Run generation loop; inspect DevTools memory profiler for native heap stability |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. Changes are internal method structure within two files. `git revert` restores original behavior.

## Open Questions

None.
