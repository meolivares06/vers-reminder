# Tasks: Modular Monolith Refactor

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,230 (P1:175, P2:325, P3:395, P4:335) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (P1) → PR 2 (P2) → PR 3 (P3) → PR 4 (P4) |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Folder reorg — move 36 files + barrel exports | PR 1 | `flutter test --no-pub` | N/A — mechanical restructure, zero behavior change | `git revert` P1; all files restored to old paths |
| 2 | Event bus — 6 typed events replace 8 HIGH imports | PR 2 | `flutter test test/event_bus/` | `flutter run` → verify wallpaper rotation + locale switch via events | Revert event_bus.dart + main.dart wiring; old imports remain |
| 3 | Provider split — SettingsProvider → 3 domain classes | PR 3 | `flutter test --no-pub` | `flutter run` → wallpaper, scheduler, settings screens load correctly | Revert 3 providers; restore old settings_provider.dart |
| 4 | Harness — impact calculator + CI integration | PR 4 | `dart test tool/harness_test.dart` | `dart run tool/harness.dart --impact` (mock diff) | Revert `tool/` + CI workflow; app unaffected |

## Phase 1: Folder Reorganization (mechanical, ~175 LOC)

- [x] 1.1 Create `lib/src/{wallpaper,scheduler,verses,home,settings,backup,notifications,shared}/` directories
- [x] 1.2 Move 36 source files per exploration §File→Module table to `lib/src/<module>/`
- [x] 1.3 Update `package:vers_reminder/...` imports in all moved files to new `src/<module>/` paths
- [x] 1.4 Create 7 barrel exports `lib/<module>/<module>.dart` exporting public API
- [x] 1.5 Update 27 test file imports per exploration §Test→Module mapping
- [x] 1.6 Run `flutter test --no-pub` — 200+ tests pass, 0 new failures
- [x] 1.7 Create `tool/modules.yaml` with initial definitions (path + deps per design schema)

## Phase 2: Event Bus (TDD, ~325 LOC)

- [ ] 2.1 (RED) `test/event_bus/event_bus_test.dart`: typed lifecycle R1, error isolation R2, registration order R3
- [ ] 2.2 (GREEN) `lib/src/shared/event_bus/event_bus.dart`: `EventBus` class — `on<T>`, `emit<T>`, error isolation (~50 LOC)
- [ ] 2.3 Wire `EventBus.instance` in `main.dart` as `Provider.value` singleton
- [ ] 2.4 Define 6 event classes in `lib/src/shared/event_bus/events/`: `WallpaperStatusUpdated`, `SchedulerStateChanged`, `VersesReloaded`, `BackupOriginalWallpaperRequested`, `LocaleChanged`, `ScheduledWallpaperTick`
- [ ] 2.5 Replace 8 HIGH cross-module imports (exploration §Event Candidates #1-8) with `emit<T>()`/`on<T>()`; keep old imports commented
- [ ] 2.6 (RED) `test/integration/event_bus_integration_test.dart`: modules communicate via events, 0 direct cross-module imports
- [ ] 2.7 (GREEN) `flutter test --no-pub` — all pass; verify 0 cross-module imports via grep excluding shared + main.dart composition

## Phase 3: Provider Split (TDD, ~395 LOC)

- [ ] 3.1 (RED) `wallpaper_state_test.dart`, `scheduler_config_test.dart`, `appearance_settings_test.dart` — cover state transitions from old provider test
- [ ] 3.2 (GREEN) `lib/src/wallpaper/wallpaper_state.dart`: `WallpaperState extends ChangeNotifier` — status, trigger, preGen, generator orchestration
- [ ] 3.3 (GREEN) `lib/src/scheduler/scheduler_config.dart`: `SchedulerConfig extends ChangeNotifier` — enabled, frequency, notification state
- [ ] 3.4 (GREEN) `lib/src/settings/appearance_settings.dart`: `AppearanceSettings extends ChangeNotifier` — font, offset, theme, alignment
- [ ] 3.5 Update `main.dart`: replace `ChangeNotifierProvider<SettingsProvider>` with 3 providers; extract `setNextPreGenerated` → `lib/src/shared/wallpaper_pregen.dart`
- [ ] 3.6 Replace all `context.watch<SettingsProvider>()` (18 call sites) with `WallpaperState`, `SchedulerConfig`, `AppearanceSettings`
- [ ] 3.7 `flutter test --no-pub` — all pass; delete `lib/providers/settings_provider.dart`

## Phase 4: Harness (TDD, ~335 LOC)

- [ ] 4.1 (RED) `tool/harness_test.dart`: impact calc R1, no false negatives R2, CI exit codes R3, git boundary (non-git dir → graceful exit; nested worktree → correct root per threat matrix)
- [ ] 4.2 (GREEN) `tool/harness.dart`: read `tool/modules.yaml`, parse dep graph, `git rev-parse --show-toplevel`
- [ ] 4.3 (GREEN) `--impact`: `git diff` changed files → module lookup → transitive dependents → test file set
- [ ] 4.4 (GREEN) `--all`: run `flutter test --no-pub` full suite; `--subset`: run files from `--impact`
- [ ] 4.5 Add `--integration` flag: runs `flutter test --no-pub integration/` separately
- [ ] 4.6 Update `.github/workflows/test.yml`: CI runs `dart run tool/harness.dart --impact` on PR, `--all` on main
- [ ] 4.7 Validate: `dart run tool/harness.dart --impact` returns correct subset; `--all` runs 200+ suite
