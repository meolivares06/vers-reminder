# Design: Fix HIGH-Severity Image Module Race Conditions & UI Jank

## Technical Approach

Three focused fixes on `settings_provider.dart` and `home_screen.dart`, using local boolean guards and cached state — no new dependencies, no architecture changes. All guards follow the project's existing patterns: `ChangeNotifier` state flags, `unawaited` fire-and-forget, and `setState` for UI rebuilds.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|---|---|---|---|
| **F4 re-entrancy guard** | `_status == generating` early-return | Token + completer (2 fields) vs. single-line check (0 new fields) | Early-return: reuses existing `_status`; `error`/`idle`/`noCategories` allow retry naturally |
| **F5 pre-gen mutex** | `bool _isPreGenerating` + `try/finally` | `AsyncLock` package (dep) vs. local boolean (zero dep) | Local boolean: pre-gen is already fire-and-forget; no queueing needed — just skip if running |
| **F6 async file check** | `bool _wallpaperFileExists` in `_HomeTabState` | Async callback in `didChangeDependencies` vs. inline `existsSync()` | Cached async boolean: eliminates sync I/O from `build()`; updated via `setState` after generation |

## Data Flow

```
User double-tap FAB
    │
    ▼
_handleFabPressed()
    │
    ▼
settings.triggerNow()                   ◄── F4: guard at top
    │  if generating → return              (single entry)
    ├── DB query → generate → persist
    │
    ├── _preGenerateFutureWallpapers()  ◄── F5: mutex
    │      if running → return              (single entry)
    │
    ▼
Home widget rebuilds
    │
    ▼
_HomeTabState.build()                  ◄── F6: cached boolean
    │   _wallpaperFileExists ?            (no sync I/O)
    │   Image.file : placeholder
```

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/providers/settings_provider.dart` | Modify | F4: early-return at `triggerNow` L262 (after empty check, before status set). F5: add `_isPreGenerating` field + guard in `_preGenerateFutureWallpapers` L347 |
| `lib/screens/home_screen.dart` | Modify | F6: add `_wallpaperFileExists` field. Replace `File.existsSync()` L195 with cached flag. Wire update in `didChangeDependencies` or after `triggerNow` |

## Interfaces / Contracts

No new public APIs. Internal only:

```dart
// F5 field (settings_provider.dart)
bool _isPreGenerating = false;

// F6 field (home_screen.dart, _HomeTabState)
bool _wallpaperFileExists = false;
```

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | F4: double `triggerNow` produces exactly one generation | `_FakeWallpaperGenerator` with call counter; assert counter==1 after two rapid awaits |
| Unit | F4: retry allowed after error | Set status to error, call `triggerNow` — must proceed past guard |
| Unit | F5: overlapping `_preGenerate*` calls skip second | Call pre-gen twice without await; assert generator invoked once |
| Unit | F6: `existsSync` absent from `_HomeTabState.build` | Source-code grep test (project convention) that `existsSync` is not called in build |
| Widget | F6: cached flag drives card vs. placeholder | Set `_wallpaperFileExists` via test seam, verify widget renders correct branch |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. All changes are local state guards and async I/O replacement.

## Migration / Rollout

No migration required. All changes are additive guards and field additions. Rollback: `git revert` the single commit.

## Open Questions

None — all decisions resolved.
