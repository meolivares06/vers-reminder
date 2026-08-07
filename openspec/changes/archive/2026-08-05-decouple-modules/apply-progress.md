# Apply Progress: Decouple Cross-Module Imports — PR 1 + PR 2 + PR 3

## Completed Tasks (PR 1: F1 + F3)

- [x] 1.1 Copy `lib/verses/domain/verse.dart` → `lib/shared/domain/verse.dart`
- [x] 1.2 Update 13 imports: `verses/domain/verse.dart` → `shared/domain/verse.dart`
- [x] 1.3 Update `lib/verses/verses.dart` barrel + delete old verse.dart
- [x] 1.4 `flutter test --no-pub` → 290 passed, 8 failed (baseline match, zero regressions)
- [x] 1.5 `tool/modules.yaml`: wallpaper.deps cleaned, scheduler→settings added, verse.dart moved
- [x] 1.6 `PermissionGranted`/`VerseAdded` removed from YAML events + marked dormant in events.dart

## Completed Tasks (PR 2: F2 — Backup Event Decoupling)

- [x] 2.1-2.12: All 12 backup event decoupling tasks complete (see prior progress)

## Completed Tasks (PR 3: F4 — check-decoupling Harness)

- [x] 3.1 **RED**: 4 tests for ModuleNode.fromYaml parsing barrel/files/exceptions + backward compat
- [x] 3.2 Extended ModuleNode with barrel/files/exceptions + updated fromYaml
- [x] 3.3 **RED**: 11 tests for DecouplingCheck: checkImport (8 cases) + checkPhantomEvents (3 cases)
- [x] 3.4 Created `tool/harness/decoupling_check.dart` (~150 lines)
- [x] 3.5 Added `check-decoupling` subcommand to cli.dart + handler in harness.dart
- [x] 3.6 `dart run tool/harness.dart check-decoupling` → exit 57 (57 barrel bypasses correctly detected in existing codebase)

## Test Results

| Run | Result | Notes |
|-----|--------|-------|
| Harness tests | 58/58 passed | +15 new tests (4 module_graph + 11 decoupling_check) |
| Full Flutter suite | 315 passed, 8 failed | +15 tests, 8 pre-existing failures unchanged |

New tests added (15):
- module_graph: 4 barrel/files/exceptions parsing tests
- decoupling_check: 8 checkImport tests + 3 checkPhantomEvents tests

Pre-existing failures (unchanged, 8): wallpaper_card_test (4), home_screen_test (1), offset_label_test (1), event_bus_integration_test (1), preview_caption_test (1).

## Files Changed (PR 3)

| File | Action | Description |
|------|--------|-------------|
| `tool/harness/module_graph.dart` | Modified | Added barrel/files/exceptions fields to ModuleNode; extended fromYaml |
| `tool/harness/decoupling_check.dart` | Created | DecouplingCheck class: run(), checkImport(), checkPhantomEvents() |
| `tool/harness/cli.dart` | Modified | Added check-decoupling subcommand + usage |
| `tool/harness.dart` | Modified | Added check-decoupling dispatch + _handleCheckDecoupling() |
| `test/tool/harness_test.dart` | Modified | +15 new tests: barrel/files/exceptions parsing + DecouplingCheck |
| `openspec/changes/decouple-modules/tasks.md` | Modified | Marked PR3 tasks complete |

## Acceptance Criteria

| Criterion | Result |
|-----------|--------|
| `dart run tool/harness.dart check-decoupling` | ✅ Tool works — detected 57 real violations (exit 57 = honest) |
| `flutter test --no-pub test/tool/` → 58/58 | ✅ All harness tests pass |
| `flutter test --no-pub` → 315/8 | ✅ Zero regressions (+15 tests, same 8 pre-existing failures) |
| No phantom events in modules.yaml | ✅ All events have ≥1 emitter and ≥1 receiver |

## Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `flutter test --no-pub test/tool/harness_test.dart` → 58 passed, 0 failed |
| Runtime harness command/scenario and exact result | `dart run tool/harness.dart check-decoupling` → exit 57 with 57 barrel bypass violations |
| Rollback boundary | Delete `decoupling_check.dart`, revert edits to `module_graph.dart`, `cli.dart`, `harness.dart` |

## TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 3.1-3.2 | harness_test.dart | Unit | 43/43 (existing) | ✅ Compile fail | ✅ 47/47 pass | ✅ 4 cases (barrel, files, exceptions, defaults) | ✅ Clean |
| 3.3-3.4 | harness_test.dart | Unit | 47/47 (existing) | ✅ Compile fail (file missing) | ✅ 58/58 pass | ✅ 11 cases (8 imports + 3 events) | ✅ Removed redundant wrapper |
| 3.5 | cli.dart, harness.dart | — | 58/58 | ➖ Structural — subcommand wiring | ✅ 58/58 + acceptance | ➖ N/A | ✅ Clean |
| 3.6 | Acceptance | — | N/A | ➖ Integration | ✅ exit 57 (honest detection) | ➖ Acceptance | ✅ Clean |

## Branch Info

- Tracker: `refactor/decouple-modules`
- PR 1 branch: `refactor/decouple-modules-pr1` (targets tracker)
- PR 2 branch: `refactor/decouple-modules-pr2` (targets PR 1 branch)
- PR 3 branch: `refactor/decouple-modules-pr3` (targets PR 2 branch)
- Chain strategy: feature-branch-chain

## Remaining Tasks

- Phase 5: 5.1 Full verification; 5.2 Module deletion compile test
