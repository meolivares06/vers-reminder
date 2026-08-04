# Tasks: Fix CRITICAL Image Module Resource Leaks

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 100–150 authored |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Resource Disposal (F1+F2) — wallpaper_generator.dart

- [x] 1.1 **RED**: Write `_compositeCanvas` disposal tests in `test/services/wallpaper_generator_test.dart`
  - Test 1: exception between textPainter creation and `endRecording()` → picture null-guard hit, bg disposed, original exception propagates
  - Test 2: exception between citationPainter creation and paint → citationPainter disposed (inner finally), textPainter disposed (outer finally)
  - Acceptance: both tests FAIL because current code has no guard/nesting

- [x] 1.2 **GREEN**: Add `ui.Picture? picture` before recorder/canvas creation (L247) in `lib/services/wallpaper_generator.dart`
  - After success-path `picture.dispose()` (L393): insert `picture = null;`
  - In `finally` (L414): add `picture?.dispose();` before `bg.dispose();`
  - Acceptance: Test from 1.1 (exception→picture guard hit) PASSES

- [x] 1.3 **GREEN**: Nest `citationPainter` inside `textPainter`'s try/finally in `lib/services/wallpaper_generator.dart`
  - Lift L331-353 (`citationPainter` creation+layout+`..` calls) and L381-382 (citationPaint) inside new inner `try` block
  - Move L385 `citationPainter.dispose()` to inner `finally`
  - Move L384 `textPainter.dispose()` to outer `finally` (after inner block closes)
  - Acceptance: Both tests from 1.1 PASS; existing wallpaper tests (~40) still PASS

## Phase 2: Non-Blocking Init (F3) — settings_provider.dart

- [x] 2.1 **RED**: Write `init()` non-blocking test in `test/providers/settings_provider_test.dart`
  - Mock `_preGenerateFutureWallpapers` as async delay; verify `_isLoading` is `false` immediately after `init()` returns
  - Test: pre-gen throws → app stays loaded, error logged; `_isLoading` remains `false`
  - Acceptance: both tests FAIL because current code blocks on pre-gen

- [x] 2.2 **GREEN**: Move `_isLoading = false` before pre-gen call and wrap pre-gen as fire-and-forget in `lib/providers/settings_provider.dart`
  - Add `import 'dart:async';` at top
  - After WorkManager re-registration (L145): set `_isLoading = false; notifyListeners();`
  - Replace `await _preGenerateFutureWallpapers(...)` with `unawaited(_preGenerateFutureWallpapers(locale: 'es').catchError((e, st) => debugPrint(...)))`
  - Remove duplicate `_isLoading = false; notifyListeners();` at L151-152
  - Acceptance: Tests from 2.1 PASS

- [x] 2.3 **REFACTOR**: Verify `setEnabled()` also updated — its pre-gen call at L194 should use same pattern (`unawaited + catchError`)
  - Acceptance: `setEnabled()` test confirms `_isLoading` remains `false` regardless of pre-gen outcome

## Phase 3: Integration & Regression

- [x] 3.1 Run full suite: `flutter test --no-pub` → all 200+ tests PASS
- [x] 3.2 Verify no new analysis warnings: `flutter analyze lib/services/wallpaper_generator.dart lib/providers/settings_provider.dart`
- [x] 3.3 Memory stress: 5× consecutive `compositeFromBytes` calls → DevTools native heap stable (no growth)
  - Test: add `test/services/wallpaper_generator_test.dart` loop asserting `_compositeCanvas` returns non-null across 5 invocations
