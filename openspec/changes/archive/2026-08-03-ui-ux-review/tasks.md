# Tasks: UI/UX Review — Dark Mode, Visual Identity, Home & Settings Coherence

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1100–1410 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR-A → PR-B → PR-C → PR-D |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

Decision: user must pick a chain strategy (stacked-to-main vs feature-branch-chain) before sdd-apply starts PR-A.

### Suggested Work Units & Line Estimates

| Unit | PR | Goal | Base | Estimated lines |
|------|----|------|------|-----------------|
| 1 | A | Theme: dark mode, gold accent, error colors (F1/F2/F9) | main | ~200–260 |
| 2 | B | Home: timestamp, categories tile, strings, verse text (F3/F5/F8/F10) | main | ~250–320 |
| 3 | C | Settings: AboutScreen, offset label, preview captions (F4/F6/F7) | main | ~300–380 |
| 4 | D | l10n parity + tests (new theme/home/settings suites) | main | ~350–450 |

**l10n**: add ARB keys inside each consuming PR (B: shareApp/emailCopied/activeCategoriesCount/currentWallpaperLabel/updatedAtLabel/timeMinutes/timeHours; C: previewLabel/offsetLabel). PR-D enforces final en/es/pt parity.

## Critical Path

app_theme.dart+main.dart (A) → provider timestamp field (B) → Home card (B) → AboutScreen extraction (C) → Settings retarget of settings_about_update_test (C). About extraction is a pure move; B's F8 dedupes share/email against AboutScreen later, so B must not finalize ARB consumers before C lands. Each slider/caption edit depends on its ARB key.

## PR-A — Theme core (F1, F2, F9) — UX-THEME-001/002/003/004/005

- [x] A1 Create `lib/theme/app_theme.dart`: export `appSeedColor` (deepPurple), `goldAccent` (0xFFEFB14D), `appLightTheme()`/`appDarkTheme()` via `ColorScheme.fromSeed` with `.copyWith(secondary: goldAccent)`, M3. (UX-THEME-002, 003)
- [x] A2 Edit `lib/main.dart:71-77`: use `theme: appLightTheme()`, add `darkTheme: appDarkTheme()`, `themeMode: ThemeMode.system`. (UX-THEME-001)
- [x] A3 Edit `lib/widgets/verse_tile.dart:26`: `Colors.red` → `colorScheme.errorContainer` + icon `onErrorContainer`. (UX-THEME-004)
- [x] A4 Edit `lib/screens/settings/settings_screen.dart:935`: `TextStyle(color: Colors.red)` → `Theme.of(context).colorScheme.error`. (UX-THEME-004)
- [x] A5 Edit `lib/screens/home_screen.dart:169-184`: replace hard shadow with `Container` scrim (`Colors.black54`) behind caption text. (UX-THEME-005)
- [x] A6 Home CTA (`home_screen.dart:227`) + Settings selected chip: tint `colorScheme.secondary` via `styleFrom(backgroundColor:)`. (UX-THEME-003)
- [x] T-A `flutter analyze` clean; grep no `Colors.red` in `lib/`; `test/theme/app_theme_test.dart` (seed constant, both brightnesses, secondary==gold, no deepPurple literal) + `test/theme/dark_mode_test.dart` (dark platform → dark Theme, error snackbar uses colorScheme.error). (UX-THEME-001/004)

## PR-B — Home UX (F3, F5, F8, F10) — UX-HOME-001..005

- [x] B1 `lib/providers/settings_provider.dart`: add `DateTime? _lastWallpaperTimestamp` + getter; persist key `last_wallpaper_timestamp` (ISO string) in `triggerNow` success branch (line ~247) alongside path; load in `init()` (~line 93). (UX-HOME-001)
- [x] B2 Edit `lib/models/verse.dart`: add `textFor(String localeCode)` getter (pt non-empty → textPt; else textEs). (UX-HOME-005)
- [x] B3 Edit `lib/widgets/verse_tile.dart:39`: use `verse.textFor(Localizations.localeOf(context).languageCode)`. (UX-HOME-005)
- [x] B4 Edit `home_screen.dart:160-186`: wrap existing-path Stack in `InkWell(onTap: triggerNow)`; add scrim overlay with `currentWallpaperLabel` + `updatedAtLabel` from timestamp. (UX-HOME-001, UX-SET-003)
- [x] B5 Edit `home_screen.dart:275-279`: subtitle → `l10n.activeCategoriesCount(count)`; add `onTap` → `Navigator.push(SettingsScreen)`. (UX-HOME-003)
- [x] B6 L10n Home strings (`home_screen.dart:317,332,345-347`): `shareApp(url)`, `emailCopied`, `_formatMinutes` via `timeMinutes`/`timeHours`. (UX-HOME-004)
- [x] T-B tests: `test/home_ux/wallpaper_card_test.dart` (label+time when path+timestamp set; tap triggers; empty state no caption); `test/home_ux/categories_tile_test.dart` (localized count, navigation); `test/models/verse_test.dart` add `textFor` pt-null fallback. (UX-HOME-001/002/003/005)

## PR-C — Settings restructure (F4, F6, F7) — UX-SET-001/002/003

- [x] C1 Create `lib/widgets/section_header.dart` from `_SectionHeader` (shared by Home + settings screens). (UX-SET-001)
- [x] C2 Create `lib/screens/settings/about_screen.dart`: move About tiles (settings_screen.dart:968-1008), update state machine + methods (`_checkForUpdate`, `_downloadAndInstall`, `_startInstall`, `_releasePageUrl`, etc.), `updateService` injectable seam. (UX-SET-001)
- [x] C3 Edit `settings_screen.dart`: remove About section; add About tile → `Navigator.push(AboutScreen)`; final section order Appearance, Scheduling, Categories, Actions, About link. (UX-SET-001)
- [x] C4 Edit `home_screen.dart` About section (308-337): replace with About tile → `AboutScreen`; dedupe share/email against AboutScreen. (UX-SET-001)
- [x] C5 Offset (settings_screen.dart:743-770): remove static Left/Right Row; keep Slider `label`; render ONE caption resolved from sign via `offsetLabel`. (UX-SET-002)
- [x] C6 Add `previewLabel` caption over Settings Appearance preview (settings_screen.dart:630-656). (UX-SET-003)
- [x] T-C retarget `test/screens/settings_about_update_test.dart` to AboutScreen; add Settings assertion (no update tiles, section order); add `test/settings_ui/about_screen_test.dart`, `test/settings_ui/offset_label_test.dart` (single node neg/pos), `test/settings_ui/preview_caption_test.dart`. (UX-SET-001/002/003)

## PR-D — l10n parity + test suite (all)

- [x] D1 Add new ARB keys to `lib/l10n/app_{en,es,pt}.arb` for any not yet present: `activeCategoriesCount`, `shareApp`, `emailCopied`, `currentWallpaperLabel`, `previewLabel`, `updatedAtLabel`, `offsetLabel`, `timeMinutes`, `timeHours`. (UX-HOME-003/004, UX-SET-002/003) — parity sweep: all 9 keys already present in en/es/pt with identical key names; verified by `ar_parity_test`.
- [x] D2 Extend `test/l10n/locale_test.dart`: assert new keys render es/pt/en. (all) — all 9 keys rendered + asserted in ES/PT/EN (extended in batches B/C; verified green in D4).
- [x] D3 Add `test/l10n/ar_parity_test.dart`: key-set(arb files) identical across en/es/pt. (all) — parity test exists; batch-keys test extended to cover all 9 keys in every locale.
- [x] D4 `flutter analyze` + full `flutter test` green (all new suites + unchanged). — analyze 0 errors (23 baseline info/warnings); full test 180/180 passed.

## Verification Commands

- All batches: `flutter analyze`
- PR-A: `flutter test test/theme/`
- PR-B: `flutter test test/models/verse_test.dart test/home_ux/`
- PR-C: `flutter test test/screens/settings_about_update_test.dart test/settings_ui/ test/screens/home_screen_test.dart`
- PR-D: full `flutter test` + `flutter analyze`
