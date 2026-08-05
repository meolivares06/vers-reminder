# module-harness Specification

## Purpose

Dart CLI tool (`tool/harness.dart`) that reads `modules.yaml`, calculates impacted test subsets from git diff via dependency graph, and runs only the affected tests. Supports CI integration via exit codes.

## Requirements

| # | Requirement | Strength |
|---|-----------|----------|
| R1 | Impact calculation: `--impact` selects the correct test subset | MUST |
| R2 | No false negatives: changed file MUST trigger all dependent module tests | MUST |
| R3 | CI exit code contract: exit 0 on pass, non-zero on failure | MUST |

### R1: Impact Calculation

Given `modules.yaml` defining module dependencies and a git diff of changed files, `--impact` MUST select the minimal set of test files covering all affected modules and their transitive dependents.

#### Scenario: Single module change triggers its tests and dependents' tests

- GIVEN `modules.yaml` declares `scheduler` depends-on `[wallpaper]`
- WHEN `lib/src/scheduler/foo.dart` is changed
- THEN `--impact` selects all test files in `scheduler/` and all test files in `wallpaper/`

#### Scenario: No changes — no tests selected

- GIVEN the git diff is empty (nothing staged or modified)
- WHEN `dart run tool/harness.dart --impact` executes
- THEN it reports zero tests selected
- AND exits 0

#### Scenario: Shared module change triggers all tests

- GIVEN `modules.yaml` declares all modules depend on `shared`
- WHEN any file under `lib/src/shared/` is changed
- THEN `--impact` selects all test files across all modules

### R2: No False Negatives

The impact calculator MUST NOT omit any test that exercises code that could be affected by the change. A changed file SHALL trigger tests for its own module and every module that depends on it (transitively).

#### Scenario: Transitive dependency triggers full chain

- GIVEN `home` depends-on `[settings, wallpaper, verses]` and `settings` depends-on `[wallpaper, verses]`
- WHEN a file in `wallpaper/` is changed
- THEN tests are selected for `wallpaper`, `settings`, and `home`

### R3: CI Exit Code Contract

The harness MUST return exit code 0 when all selected tests pass and exit code non-zero when any test fails. This SHALL be compatible with CI pipeline pass/fail decisions.

#### Scenario: All selected tests pass

- GIVEN `--impact` selects 5 test files
- WHEN all 5 pass via `flutter test --no-pub`
- THEN harness exits 0

#### Scenario: Any selected test fails

- GIVEN `--impact` selects 5 test files
- WHEN 1 test file has a failing assertion
- THEN harness exits non-zero
- AND stderr contains the failure summary
