# Proposal: Modular Monolith Refactor

## Intent

Refactor the 36-file Flutter monolith into 7 domain modules (wallpaper, scheduler, verses, home, settings, backup, notifications) communicating via an async event bus, plus a Dart-based project harness for impact-aware testing. Eliminate the `SettingsProvider` GOD object (8 concerns) and 26 cross-module direct imports to reduce regression risk and enable isolated testing.

## Scope

### In Scope
- Folder reorganization into `lib/src/<module>/` with barrel exports
- Lightweight `EventBus` (~50 LOC, Stream-based, zero dependencies)
- Replace 8 HIGH-severity cross-module imports with typed events
- Split `SettingsProvider` into `WallpaperState`, `SchedulerConfig`, `AppearanceSettings`
- Harness: `tool/harness.dart` + `modules.yaml` + `--impact` calculator
- 27 test files migrated to new import paths

### Out of Scope
- No behavior changes, no new features, no UI changes
- No new dependency packages
- No CI pipeline changes beyond harness invocation

## Capabilities

### New Capabilities
- `event-bus`: Lightweight typed event infrastructure (publish/subscribe via Streams) for inter-module communication
- `module-harness`: Dart CLI tool that reads `modules.yaml`, calculates impacted test subsets via dependency graph, and runs targeted test suites

### Modified Capabilities
None — pure refactor, no spec-level requirement changes.

## Approach

**Phased delivery (corte limpio — no incremental dual-provider state):**

1. **Phase 1 — Folder Reorganization**: Move 36 files into `lib/src/{wallpaper,scheduler,verses,home,settings,backup,notifications,shared}/`. Create barrel exports. Update all import paths. Zero risk, mechanical change.

2. **Phase 2 — Event Bus Core**: Implement `EventBus` class (Stream-based, ~50 LOC). Replace 8 HIGH-severity cross-module imports with typed events: `WallpaperStatusUpdated`, `SchedulerStateChanged`, `VersesReloaded`, `BackupOriginalWallpaperRequested`, `LocaleChanged`, `ScheduledWallpaperTick`. Keep boot-time composition in `main.dart`.

3. **Phase 3 — SettingsProvider Split**: Decompose GOD object into `WallpaperState` (wallpaper module), `SchedulerConfig` (scheduler module), `AppearanceSettings` (settings module). WorkManager isolate coupling to `WallpaperGenerator.instance.setNextPreGenerated()` accepted as unavoidable — extract into shared function.

4. **Phase 4 — Harness**: `tool/harness.dart` reads `modules.yaml` dependency graph, calculates `--impact` test subset from changed files. Integrated into CI via `dart run tool/harness.dart --impact`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/` (36 files) | Moved | Reorganized into `lib/src/<module>/` |
| `lib/src/shared/event_bus.dart` | New | Event bus infrastructure |
| `lib/providers/settings_provider.dart` | Split | → 3 classes in 3 modules |
| `tool/harness.dart` | New | Impact calculator harness |
| `modules.yaml` | New | Module dependency graph config |
| `test/` (27 files) | Modified | Import path updates |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| WorkManager isolate can't share event bus | Certain | Accepted — extract `setNextPreGenerated` to shared function |
| Provider split breaks `context.watch<SettingsProvider>()` | High | Corte limpio — all consumers migrate atomically in Phase 3 |
| 27 test files need mass import updates | High | Phase 1 handles mechanically; Phase 2-4 incremental |
| 18 spec domains need structure realignment | Low | Pure refactor — no requirement changes |

## Rollback Plan

Each phase is independently revertible via `git revert`. Phase 1 is purely mechanical (0 risk). Phase 2 keeps dual imports until events stabilize. No irreversible DB migrations or data format changes.

## Dependencies

- Dart SDK ≥3.0 (existing project requirement)
- `flutter_test` for harness test execution
- No new packages

## Success Criteria

- [ ] `dart run tool/harness.dart --impact` returns correct test subset for any changed file
- [ ] 0 new cross-module direct imports (boot-time composition in `main.dart` is acceptable)
- [ ] Event bus covers all 8 HIGH-severity couplings from exploration matrix
- [ ] All 27 existing test files pass after migration
- [ ] `SettingsProvider` no longer exists — replaced by 3 domain-specific classes
