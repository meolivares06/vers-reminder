# Tasks: Home Wallpaper Focus Redesign

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~500 authored |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-forecast (session budget 800) |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

> Estimate ~500 authored lines exceeds the default 400 guard but sits under this change's 800-line session budget; single PR acceptable. Excluded from authored count: `EBGaramond-Italic.ttf` (754 KB binary) + regenerated `lib/l10n/generated/`.

### Suggested Work Units (commit-level)

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Font asset + italic face | Single | `flutter test --no-pub test/services/wallpaper_generator_test.dart` | N/A — static asset registration; proven via analyzer | Revert pubspec fonts block + delete `assets/fonts/EBGaramond-Italic.ttf` |
| 2 | Home fraction-card + gold FAB + tile removal | Single | `flutter test --no-pub test/home_ux/wallpaper_card_test.dart test/screens/home_screen_test.dart` | `flutter run` — Home tab 0 shows tall card + gold FAB, tab 1 add FAB | Revert `home_screen.dart` `_HomeTab` rebuild + FAB condition |
| 3 | Generator typography + measurement parity | Single | `flutter test --no-pub test/services/wallpaper_generator_test.dart` | `flutter run` — generate wallpaper, verify italic verse + gold rule | Revert style helpers + `_resolveFontSize` in `wallpaper_generator.dart` |
| 4 | l10n key removal + test cascade | Single | `flutter test --no-pub test/l10n` | N/A — localized strings only | Restore `activeCategoriesCount` ARBs + regen; undo test edits |

## Phase 1: Assets & i18n (Foundation)

- [x] 1.1 Copy `EBGaramond-Italic.ttf` from `C:\Users\MARIO~1.FER\AppData\Local\Temp\opencode\prototypes\vers-reminder\` → `assets/fonts/EBGaramond-Italic.ttf`; add italic face under `EB Garamond` in `pubspec.yaml` (after L50). Verify: `flutter pub get` clean; asset listed. (Non-TDD)
- [x] 1.2 Remove `activeCategoriesCount` + `@activeCategoriesCount` from `lib/l10n/app_en.arb` (L177-186), `app_es.arb` (L181), `app_pt.arb`; run `flutter gen-l10n`. (Non-TDD, atomic — no consumer remains after 2.3)
- [x] 1.3 Test-first: update `test/l10n/locale_test.dart` (drop L33 call + `Active/Activas/Ativas: 3` asserts L70/L99/L127) and `test/l10n/ar_parity_test.dart` (remove `'activeCategoriesCount'` L49). These FAIL to compile/pass until 1.2 lands (RED→GREEN with 1.2).

## Phase 2: Home Screen Layout

- [x] 2.1 RED: `test/home_ux/wallpaper_card_test.dart` — add height assert: `tester.getSize(find.byType(Card)).height` in [85%,88%] of home-body height; fails on current fixed `SizedBox(height: 320)`.
- [x] 2.2 GREEN: rewrite `_HomeTab` in `lib/screens/home_screen.dart` (L121-284): `LayoutBuilder` + `Column`/`Expanded` card, height `constraints.maxHeight * 0.85` (clip ≤0.88), drop `SizedBox(height: 320)` (L130-131); keep card-tap + empty-state + caption overlay (L133-212) + `_relativeTime`.
- [x] 2.3 GREEN: remove AsyncActionButton block (L218-247), rotation ListTile (L252-266), categories ListTile (L269-280), `_formatMinutes` (L314-318), `async_action_button.dart` import (L11).
- [x] 2.4 GREEN: gold circular FAB (Scaffold L79-84) on `_currentIndex==0` using `colorScheme.secondary`, shared trigger/permission path; keep add-verse FAB on index 1; never both.

## Phase 3: WallpaperGenerator Typography

- [x] 3.1 RED: `test/services/wallpaper_generator_test.dart` — add tests asserting verse style EB Garamond + italic, citation sans-serif uppercase + letterSpacing, gold `0xFFEFB14D` rule pixels above citation, `_resolveFontSize` parity ≤1px; fail on current styles.
- [x] 3.2 GREEN: `lib/services/wallpaper_generator.dart` — extract shared `_verseMeasure(size)`/`_citationMeasure(size)` (design L54-58) used by paint (L293-300 verse, L310-317 citation) AND measure (L429, L437); verse `fontStyle: FontStyle.italic`; citation `TextStyle.fallback`, `letterSpacing: 1.5`, `.toUpperCase()`; draw gold `Rect(0xFFEFB14D)` above citation; expose `@visibleForTesting` seam for `_resolveFontSize`/style checks.

## Phase 4: Test Cleanup & Verify

- [x] 4.1 Delete `test/home_ux/categories_tile_test.dart` (all 3 tests assert removed tile, UX-HOME-003).
- [x] 4.2 Test-first: `test/screens/home_screen_test.dart` — add: rotation+categories absent (`find.byType(Switch)`/`find.text('Categories')` empty); gold FAB present idx 0 → absent idx 1, add FAB on idx 1; tap FAB triggers generation (status → noCategories) when permission granted; FAB shows permission dialog when not.
- [x] 4.3 Run `flutter analyze --no-pub` (0 errors) and `flutter test --no-pub` (all pass).