# Exploration: Home Wallpaper Focus Redesign

## Current State

The Home tab (`_HomeTab` in `lib/screens/home_screen.dart`) is a `ListView(padding: EdgeInsets.all(16))` stacking:
1. A fixed-height wallpaper preview `Card` wrapped in `SizedBox(height: 320)` (line 131). When a wallpaper exists it shows `Image.file` + a black54 caption with `currentWallpaperLabel` + `updatedAtLabel('\... ago')`; the empty state shows an icon + `noWallpaper`. Both are tappable via `_triggerNow` (permission-gated).
2. A full-width `AsyncActionButton` "Change now" (lines 218-247), gold via `colorScheme.secondary`, that runs the permission dialog or `triggerNow`.
3. A rotation `ListTile` with `Switch` (lines 252-266) bound to `settings.isEnabled` + `_formatMinutes`.
4. A categories `ListTile` (lines 269-280) bound to `settings.activeCategoryIds.length` that navigates to `SettingsScreen`.

The Scaffold `floatingActionButton` currently renders ONLY on tab index 1 (verse list "add"); the home tab has no FAB.

The `WallpaperGenerator` (`lib/services/wallpaper_generator.dart`) uses 4 `TextStyle`s all with `fontFamily: 'EB Garamond'` and NO `fontStyle`:
- Verse paint (lines 293-300): white, w700, `fontSize` resolved, height 1.4.
- Citation paint (lines 310-317): white70, w500, size = `resolved * 0.75`.
- Verse measure inside `_resolveFontSize` (line 429): bare family/size/height.
- Citation measure (line 437): bare family/size/height.

`pubspec.yaml` fonts block (lines 47-50) registers one face under family `EB Garamond`: `assets/fonts/EBGaramond-Variable.ttf`. The italic face `EBGaramond-Italic.ttf` already exists at the downloaded temp path and must be copied into `assets/fonts/` during apply.

`SettingsScreen` already exposes BOTH the rotation toggle (`SwitchListTile` `l10n.autoChange`, lines 519-526) and full category management (`CheckboxListTile` list, lines 560-599), plus a `changeNow` `AsyncActionButton` in Actions (line 608). So removing the two Home tiles loses NO functionality.

## Affected Areas

- `lib/screens/home_screen.dart` — wallpaperCard height (line 131), remove Change-now button (218-247), remove rotation (252-266), remove categories (269-280), rework Scaffold FAB to show a gold FAB on home tab; `_formatMinutes` becomes dead after rotation removal; `AsyncActionButton` import becomes unused.
- `lib/services/wallpaper_generator.dart` — verse styles (293-300, 426-432) need `fontStyle: FontStyle.italic`; citation (303-320, 434-440) needs sans-serif, uppercase, letter-spacing, and a small gold rule drawn before it on the canvas.
- `pubspec.yaml` — add `- asset: assets/fonts/EBGaramond-Italic.ttf` with `style: italic` under the existing `EB Garamond` family.
- `assets/fonts/EBGaramond-Italic.ttf` — new file copied from temp.
- `openspec/specs/home-ux/spec.md` — UX-HOME-002/003 need MODIFIED/REMOVED deltas.
- `openspec/specs/wallpaper-gen/spec.md` — add typography requirement (verse italic, citation contrast). (Dependent on spec phase.)

## Tests That Will Break / Need Rework

- `test/home_ux/categories_tile_test.dart` — ALL THREE tests assert the categories tile (`find.text('Categories')`, `'Active: 3'`, navigation to `SettingsScreen`). File must be deleted or rewritten to assert removal (UX-HOME-003 is removed).
- `test/home_ux/wallpaper_card_test.dart` — asserts card caption (`Your wallpaper`, `... ago`, empty-state prompt). Survives IF the redesigned card keeps the caption + tap-to-trigger semantics; re-verify after layout change.
- `test/screens/home_screen_test.dart` — only asserts About/Share/Language absence; unaffected. Add an assertion that rotation + categories tiles are gone.
- `test/screens/settings_about_update_test.dart` (lines 599-631) — asserts `Change now` on the SETTINGS screen; Settings keeps its Action, so unaffected.
- `test/widgets/async_action_button_test.dart` (line 172) — generic widget test using a `Change now` label; unaffected (widget still used by Settings).
- `test/l10n/locale_test.dart` (lines 21, 115) — asserts the localized `changeNow` string directly; unaffected.
- `test/services/wallpaper_generator_test.dart` — asserts only PNG dimensions/decode, never font style or citation; survives, but ADD new tests for italic verse + uppercase sans-serif citation.

## l10n Key Impact

- `changeNow` — still used in `_showPermissionDialog` (home line 345) + Settings (line 608). KEEP.
- `autoChange` — Settings line 520 keeps it. KEEP.
- `categoriesLabel` — Settings line 563 keeps it. KEEP.
- `activeCategoriesCount` — ONLY used by the removed Home categories tile. Remove from ARBs (or leave; gen-l10n only warns on unused). Recommend removing + regenerating.
- `currentWallpaperLabel`, `updatedAtLabel`, `noWallpaper` — card still uses them. KEEP.

## Approaches

1. **Inline gold FAB + static-keyword height** — Give home a circular `FloatingActionButton` (backgroundColor `colorScheme.secondary`, foreground `onGoldAccent`), sized via `MediaQuery.of(context).size.height * 0.85...` for the card.
   - Pros: Matches prototype directly; minimal new widgets.
   - Cons: FAB `onPressed` must duplicate trigger/permission logic; card height second must be placed in a Stack/Expanded to be a % of the screen.
   - Effort: Medium

2. **FAB-as-primary-action helper + StackLayout** — Extract the trigger into a small reusable callback (`_trigger`) used by both FAB and card; use a `LayoutBuilder`/`SizedBox` fraction for the card.
   - Pros: no duplicated trigger logic; cleaner composition; easier to test.
   - Cons: slightly more code.
   - Effort: Medium

3. **Typographic rework in generator** — add `fontStyle: italic` to the 2 verse styles and the 2 measurement styles; citation uses a sans-serif family, `toUpperCase()`, `letterSpacing`, and a drawn gold rule (small `Rect`, `Color(0xFFEFB14D)`) above the citation.
   - Pros: single code path; measurement matches paint (uppercase changes width so `_resolveFontSize` MUST be synced).
   - Cons: must copy the italic ttf + pubspec change; test env defaults to a fallback font if the face for tests is absent.
   - Effort: Medium

## Recommendation

Go with **Approaches 1+3** combined: gold circular FAB as the home primary action (permission-gated via the existing `_showPermissionDialog` path), card height = `MediaQuery.height * 0.85-0.88` driven by a screen-size fraction, and a single typographic pass in `WallpaperGenerator`. Reuse `colorScheme.secondary` (goldAccent `#EFB14D`, already the theme second surface) with `onGoldAccent` foreground. Delete `test/home_ux/categories_tile_test.dart`, add a home_screen assertion that rotation + categories tiles and the full-width Change-now button are gone, and add generator tests for the new verse/citation styling.

## Risks

- **Measurement vs paint drift in `_resolveFontSize`**: italic + uppercase + letterSpacing in paint but not in measure → wrong fit / overflow. Must mirror both style passes.
- **Font availability in tests**: if the italic ttf isn't in the bundle when widget-testing, `TextPainter` falls back to a system font; generator dimension tests still pass (they don't assert style), but new italic tests must be flushed with a real font binding.
- **`_formatMinutes` dead code** — after removing the rotation tile it becomes unused (lint).
- **`AsyncActionButton` import** in `home_screen.dart` becomes unused after the full-width button is removed.
- **Two FABs across tabs** — home tab gold FAB + verse tab Add FAB must be mutually exclusive (`_currentIndex == 0` vs `== 1`).
- **l10n `activeCategoriesCount`** unused after removal → gen-l10n warning (non-fatal).

## Ready for Proposal
Yes — full scope understood, options compared, tests + l10n + spec deltas mapped. Recommended next: sdd-propose for change `home-wallpaper-focus`.