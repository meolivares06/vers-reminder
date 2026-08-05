# Design: Modular Monolith Refactor

## Technical Approach

Four sequential phases with atomic commits, each independently revertible. No dual-provider migration — corta limpio at each phase boundary. Folder reorg (P1) is mechanical; event bus (P2) replaces 8 HIGH imports; provider split (P3) replaces `SettingsProvider` with 3 domain classes; harness (P4) adds dev tooling. All 27 tests must pass at every phase boundary.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|---|---|---|---|
| Event bus | `Stream`-based singleton, `on<T>(handler)` / `emit<T>(event)`, registered in `main.dart` | InheritedWidget, get_it | Zero deps, ~50 LOC. Matches Flutter Streams in SDK. Typed via generic `<T>`. |
| Module layout | `lib/src/<module>/` private, `lib/<module>/<module>.dart` barrel | Single-level `lib/<name>/` dirs | Flutter convention: src/ for impl, barrel for public API. Prevents accidental deep imports. |
| Provider split | 3 classes: `WallpaperState`, `SchedulerConfig`, `AppearanceSettings` | Mixins, 8 micro-classes | Cuts cleanly along operational boundaries. 3 is the minimum defensible split mapping to spec domains. |
| WorkManager exception | Extract `setNextPreGenerated` to `shared/wallpaper_pregen.dart` | Event bus (not possible in isolates) | Isolates don't share memory. Accepted coupling documented in `modules.yaml`. |
| Harness runtime | Pure Dart CLI (`dart run tool/harness.dart`) | bash, Makefile | Cross-platform. Reads `modules.yaml`. No Flutter dependency. |

## Data Flow

```
main.dart (composition root)
  │
  ├── EventBus.instance ◄── (singleton, registered in providers)
  │     │
  │     ├── WallpaperStatusUpdated ──► HomeScreen (listen)
  │     ├── SchedulerStateChanged ──► WallpaperScheduler (listen)
  │     ├── VersesReloaded ──► HomeScreen, SettingsScreen (listen)
  │     ├── ScheduledWallpaperTick ──► WallpaperState (listen)
  │     └── BackupOriginalWallpaperRequested ──► WallpaperBackupService (listen)
  │
  ├── WallpaperState ──► WallpaperGenerator (direct call)
  │     └── emits: WallpaperStatusUpdated, WallpaperPreGenCompleted
  │
  ├── SchedulerConfig ──► WallpaperScheduler (direct call)
  │     └── emits: SchedulerStateChanged
  │
  └── AppearanceSettings (no emissions, pure settings CRUD)

Exception: wallpaper_scheduler.dart (WorkManager isolate) calls
shared/wallpaper_pregen.dart directly — no event bus in isolates.
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/src/shared/event_bus/event_bus.dart` | Create | Typed async event bus (~50 LOC) |
| `lib/src/shared/wallpaper_pregen.dart` | Create | Extracted `setNextPreGenerated` for isolate access |
| `lib/src/<module>/*.dart` (35 files) | Move | Reorganized from old flat dirs into 7 modules + shared |
| `lib/<module>/<module>.dart` (7 files) | Create | Barrel exports exposing public API per module |
| `lib/providers/settings_provider.dart` | Delete | Replaced by `WallpaperState` + `SchedulerConfig` + `AppearanceSettings` |
| `lib/main.dart` | Modify | Wire event bus singleton, register 5 providers instead of 3 |
| `test/**/*.dart` (27 files) | Modify | Update `package:vers_reminder/...` imports to new paths |
| `tool/harness.dart` | Create | ~200 LOC Dart CLI for `--impact` test selection |
| `modules.yaml` | Create | Module dependency graph (7 modules + metadata) |

## Interfaces / Contracts

**Event Bus API**:
```dart
class EventBus {
  static final EventBus instance = EventBus._();
  void on<T>(void Function(T) handler);
  void emit<T>(T event);
}
```

**modules.yaml schema**:
```yaml
modules:
  wallpaper:
    path: lib/src/wallpaper
    deps: [shared, backup, scheduler, notifications]
    exceptions:
      - "scheduler → shared/wallpaper_pregen.dart (isolate)"
  scheduler: {path: lib/src/scheduler, deps: [shared, wallpaper]}
  verses: {path: lib/src/verses, deps: [shared]}
  home: {path: lib/src/home, deps: [shared, wallpaper, settings, verses]}
  settings: {path: lib/src/settings, deps: [shared, wallpaper, backup, verses]}
  backup: {path: lib/src/backup, deps: [shared]}
  notifications: {path: lib/src/notifications, deps: [shared]}
```

**Provider split contract** — replacing `context.watch<SettingsProvider>()`:
| Old | New |
|---|---|
| `context.watch<SettingsProvider>()` (wallpaper state) | `context.watch<WallpaperState>()` |
| `context.watch<SettingsProvider>()` (layout prefs) | `context.watch<AppearanceSettings>()` |
| `context.watch<SettingsProvider>()` (scheduler) | `context.watch<SchedulerConfig>()` |

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Event bus emit/subscribe pairs | `flutter_test`; Stream subscription + typed verification |
| Unit | Provider split state transitions | Existing `settings_provider_test.dart` split into 3 test files |
| Integration | Wiring: main.dart providers → event emissions received | `pumpWidget` with full MultiProvider tree |
| Harness | module dependency resolution + test subset | `dart test tool/harness_test.dart` with mock git output |
| Regression | 27 existing tests pass unchanged | `flutter test` after each phase |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Git repository selection (`git diff`) | Applicable — harness subprocess | Harness resolves `git rev-parse --show-toplevel`; fails on non-git dir | Test non-git dir → graceful exit; test nested worktree → correct root |
| Documentation-like paths | N/A — no executable classification | — | — |
| Commit/push/PR state | N/A — read-only git diff | — | — |

## Migration / Rollout

Each phase is independently revertible via `git revert`. No DB migrations. Phase 1 is mechanical zero-risk. Phase 2 keeps original imports as fallback until events stabilize (same commit). Phase 3 is atomic — all `context.watch<SettingsProvider>()` replaced in single commit. Test at every phase boundary with `flutter test`.

## Open Questions

- [ ] Should `modules.yaml` live in `tool/` or root? (proposal: tool/ — it's a harness config)
- [ ] Confirm no `context.watch<SettingsProvider>()` exists outside of `lib/` (checked: zero — 18 call sites all in lib)
