# Proposal: UI/UX Review — Dark Mode, Visual Identity, Home & Settings Coherence

## Intent

vers-reminder is a scripture-memory app (Material 3, Flutter) used primarily at
night and on a phone home screen. Current UI ships with hardcoded
`Brightness.light`, a single purple seed color that clashes with the new gold
adaptive icon, and scattered hardcoded Spanish strings/raw `Colors.red` errors.
Users on Home and Settings face duplicated controls, an overloaded 1048-line
Settings scroll, a static wallpaper card, and locale-inconsistent verse text.

This change is a focused UI/UX refinement (NOT a rewrite) that: makes the app
usable at night, aligns the visual identity with the gold icon, reduces
cognitive load on Home/Settings, and cleans every hardcoded/duplicated/localized
sinverigüenza so the UI is coherent, localized, and testable.

**All user-facing copy MUST be internationalized** in `lib/l10n/app_{en,es,pt}.arb`
via `AppLocalizations` — never hardcoded.

## Scope

### In Scope
- Dark mode (ThemeMode.system + dark colorScheme + fix hardcoded colors).
- Visual identity decision toward gold/brand coherence (seed-color or secondary scheme).
- Home wallpaper card: last-updated context + action affordance.
- Settings restructure: split overloaded sections, clarify the two-preview confusion.
- Active-categories Home tile: localize + make tappable or status-only.
- Horizontal offset slider: single dynamic label, no duplicate/static labels.
- L10n for remaining hardcoded Home strings; fix raw `Colors.red` → `colorScheme.error`.
- VerseTile locale-aware verse text (`textEs` vs `textPt`).

### Out of Scope
- Backend/data changes; no new pages beyond listed (calibration screen stays commented out).
- No seed data, provider rewrite, or wallpaper-generation logic changes.
- Palette full brand overhaul/recolor of every asset (decided separately, see risk 2).
- Chained-PR split — deferred to orchestrator (see Notes).

## Capabilities

> Contract with sdd-spec. Baselines read from `openspec/specs/` (existing: settings-ui, l10n-core, wallpaper-set, wallpaper-scheduler, wallpaper-gen, verse-storage, backoffice, home-navigation (delta), shared-ui (delta)).

### New Capabilities
- `theme-core`: system theme mode (light/dark), gold-coherent seed color, colorScheme.error usage contract for all surfaces.
- `home-ux`: Home tab refinements — wallpaper card context/actions, CTA centralization, active-categories tile behavior, locale-aware verse text.

### Modified Capabilities
- `settings-ui`: section restructure (About split from wallpaper), preview-purpose captions, single offset label, scheduling section consolidation.
- `wallpaper-set`: expose last-update timestamp on the Home card (requires new field read from existing provider or a timestamp stored alongside `last_wallpaper_path`).
- `l10n-core`: add new ARB keys for offset label, active-categories count, copy-to-clipboard, share, preview captions, last-updated, error styling contract update.

## Findings (Source of Truth)

Baseline verified from `git`-clean code. Acceptance = `flutter test` (root), `flutter analyze`, manual on-device check of Home + Settings.

### F1 — Dark mode (HIGH)
- **Business intent**: Scripture memory happens at night; a bright screen is a usability and sleep-hygiene problem. Outcome: app automatically adapts, no tracking "last changed" cognitive load.
- **Current**: `main.dart:71-77` hardcodes `ColorScheme.fromSeed(brightness: Brightness.light)`; `main.dart` has no `themeMode`/`darkTheme`. Hardcoded colors: `verse_tile.dart:26` `background: Colors.red`; `settings_screen.dart:935` `style: const TextStyle(color: Colors.red)`; `home_screen.dart:176` `color: Colors.white` + shadow on wallpaper preview; `home_screen.dart:73-82,176` white text over image.
- **Desired**: App follows system via `themeMode: ThemeMode.system`. A `darkTheme` exists (`ColorScheme.fromSeed(seed: <brand>, brightness: Brightness.dark)`). No raw color literals for error/text contrast remain in screens/widgets; all use `colorScheme.error`, `onSurface`, or image-legible overlay pattern.
- **Approach**: In `main.dart` add `themeMode: ThemeMode.system` and `darkTheme`. Replace `Colors.red` in `verse_tile.dart` background with `colorScheme.errorContainer`/`onErrorContainer` (pass via `Theme.of`). In `settings_screen.dart` line 935 use `colorScheme.error`. For `home_screen.dart` white-on-image text, add a scrim `Container` (black54) behind text so it reads on both themes.
- **Acceptance**: `flutter analyze` clean. Widget test: with `Brightness.dark` platform brightness, `Theme.of(context).brightness == Brightness.dark` and no `Colors.red` literal appears in built tree. Manual: toggle device dark mode → Home + Settings + Backoffice render dark, error snackbar uses theme error, wallpaper text stays legible.

### F2 — Visual identity / seed coherence (HIGH)
- **Business intent**: gold app icon vs purple UI is incoherent; a distinctive, memorable brand is the intent, but recoloring the whole UI risks regression.
- **Current**: `main.dart:72` seed = `Colors.deepPurple`. Icon is gold.
- **Desired**: A documented decision: **Recommend** keeping `deepPurple` seed but validate gold as complementary; evaluate a gold-tinted secondary palette used for accent surfaces (CTA, active states) rather than wholesale recolor. Explicit tradeoff recorded here.
- **Approach**: Define single source of truth constant (e.g. `lib/theme/app_theme.dart`) exporting `seedColor`, light/dark `ThemeData` builders (used by F1). Introduce gold accent only where low-risk (FAB active state, selected chips, `changeNow` CTA tint) via `colorScheme.secondary`. Do NOT change every widget color in this change.
- **Acceptance**: App builds; `flutter analyze` clean. Visual check: Home CTA + Settings selected controls show gold accent; seed constant referenced, not literal `deepPurple` scattered.
- **Risk**: Recolor scope creep. Mitigation: gold accent is additive (secondary), not replacement.

### F3 — Home wallpaper card static/cold (HIGH)
- **Business intent**: The card should communicate freshness and invite action, not show a static image. Users cannot tell when their wallpaper last changed or act on it.
- **Current**: `home_screen.dart:160-186` shows `Image.file` + full-bleed status text; no updated timestamp, no action on an existing wallpaper. `changeNow` appears in Home (`home_screen.dart:225-252`) AND Settings Actions (`settings_screen.dart:897-948`) — duplicated CTA.
- **Desired**: When `lastWallpaperPath` exists: show relative/absolute "Updated {time}" (localized) and an explicit "Change now" affordance (default: tapping the image or a small overlay action triggers change). Primary CTA stays in Home; Settings keeps its contextual "Change now" in Actions but is clearly secondary. Empty state unchanged (tap to generate first).
- **Approach**: Add a `lastWallpaperTimestamp` to `SettingsProvider` (persist alongside `last_wallpaper_path` when set; keep current key — new write only). Reuse existing `wallpaperUpdated`/relative-time via `intl` (already transitively available) or a new `relativeTime` ARB helper. Change `home_screen.dart` Image branch to wrap in `InkWell(onTap: triggerNow)` + timestamp caption + scrim.
- **Acceptance**: Widget test: card shows localized updated label when file exists and is tappable; empty state unchanged. Manual: generate wallpaper → Home card shows "Updated X ago"; tapping regenerates.

### F4 — Settings overloaded (MEDIUM)
- **Business intent**: 1048-line single scroll with 6 sections raises cognitive load; mixing About with wallpaper reduces trust and task focus.
- **Current**: `settings_screen.dart` single `ListView` (Appearance/preview, Scheduling, Categories, Actions, About).
- **Desired**: Minimal, deliberate structure — keep one scroll, but: (a) About moves to its own screen (`AboutScreen`) reached from a Setting tile (or app-bar info icon), removing ~120 lines from Settings; (b) Scheduling keeps its toggle+frequency AND the Home "Scheduling" section remains a status mirror that navigates to Settings (see F5) — no duplicated control logic; (c) section order: Appearance, Scheduling, Categories, Actions, then About link.
- **Approach**: Extract `AboutScreen` (`lib/screens/settings/about_screen.dart`) reusing existing About tiles/share/email/update logic from `settings_screen.dart` + `home_screen.dart`. Replace Home About section with a tile that opens `AboutScreen` (or link to Settings→About). Keep the rest of Settings layout unchanged. Decisions: prefer non-tabbed, non-collapsible to stay minimally invasive.
- **Acceptance**: `flutter analyze` clean. Widget/`flutter test`: `AboutScreen` renders update/version/share/contact; Settings no longer contains update tiles. Manual: 6 sections → 4 + one About link; scroll noticeably shorter.

### F5 — Home active-categories tile (MEDIUM)
- **Business intent**: hardcoded Spanish `activas` breaks localization; a status-only tile that looks tappable violates expectations.
- **Current**: `home_screen.dart:278` `subtitle: Text('${settings.activeCategoryIds.length} activas')`, non-tappable.
- **Desired**: Localized count (`activeCategoriesCount` ARB with count placeholder). Tile either navigates to Settings→Categories (prefer) or is explicitly status-only.
- **Approach**: Add ARB key `activeCategoriesCount` (en/es/pt). Wire `onTap` → `Navigator.push(SettingsScreen)` (matching the Scheduling-tile pattern). If navigation is rejected, add a `StatusListTile` style so it reads as non-interactive.
- **Acceptance**: Grep-free: no `activas` literal in Dart. `flutter test` asserts localized subtitle. Manual: toggle a category in Settings → Home count updates live.

### F6 — Duplicate offset labels (MEDIUM)
- **Business intent**: identical "Left/Right" shown twice (Row + body) is redundant and confusing.
- **Current**: `settings_screen.dart:743-760` Row shows `l10n.leftOffset`/`l10n.rightOffset`; `settings_screen.dart:764-770` second text `'${l10n.leftOffset} {offset} (' + {left|right} + ')'` (non-l10n-composable, shows "Left -5 (Left)").
- **Desired**: One dynamic offset label. Show value with direction in the Slider's `label`/tooltip AND a single caption: e.g. "Left −5" / "Right 0" (from value sign), no duplicate static Row labels.
- **Approach**: Remove static left/right Row texts; keep Slider; render one caption from value via a new helper picking `offsetLeft`/`offsetRight` by sign. Add ARB keys `offsetLabel` with direction+value placeholders (or reuse existing left/right).
- **Acceptance**: `flutter analyze` clean. Widget test: only ONE offset-related text node rendered per state; value negative → "Left", positive → "Right". Manual: slide → single live caption updates.

### F7 — Two previews confused (MEDIUM)
- **Business intent**: Home real wallpaper vs Settings composition preview look identical; users can't tell which is the actual live image.
- **Current**: Home `Image.file(lastWallpaperPath)` (real, `home_screen.dart:165`); Settings `_cachedPreview` (`settings_screen.dart:635`, live render) both uncaptioned full-bleed images.
- **Desired**: Each preview has a distinct caption: Home = "Current wallpaper" (real) with updated time (F3); Settings = "Preview" (composition) labeled as such, differentiated from the real card.
- **Approach**: Add ARB keys `currentWallpaperLabel`, `previewLabel`. Render a small label chip/badge over each. Home keeps real `Image.file`; Settings keeps memory-preview but with `previewLabel` caption.
- **Acceptance**: Widget test asserts captions present on both. Manual: two screens now visibly distinct via label.

### F8 — Hardcoded Spanish in Home (LOW)
- **Business intent**: untranslated strings leak Rioplatense Spanish to en/pt users.
- **Current**: `home_screen.dart:317` share `'Descargá Vers Reminder: ...'`; `:332` `'Email copiado al portapapeles'`; also duplicated in `settings_screen.dart:988,1003`. `:347` `_formatMinutes` returns raw `'min'`/`'hora'`/`'horas'`.
- **Desired**: All in ARB. Add keys `shareApp` (with repo URL placeholder or constant), `emailCopied`. Localize `_formatMinutes` via ARB units (`timeMinutes`, `timeHours` or use `intl`).
- **Approach**: New ARB keys; replace literals; reuse in both Home and Settings (single source).
- **Acceptance**: `flutter test` l10n key-parity check (existing l10n-core) passes with new keys across en/es/pt; no Spanish literal in Dart. Manual: switch to en → share+email messages in English.

### F9 — Raw Colors.red error (LOW)
- **Business intent**: dark-mode-broken error color (covered in F1 but tracked independently).
- **Current**: `settings_screen.dart:935` `TextStyle(color: Colors.red)`.
- **Desired**: `colorScheme.error`.
- **Acceptance**: grep `Colors.red` in `lib/` → only `theme`-derived usages remain (none hardcoded).

### F10 — VerseTile locale text (LOW)
- **Business intent**: list renders `textEs` regardless of locale → pt users see wrong language.
- **Current**: `verse_tile.dart:39` always `verse.textEs`.
- **Desired**: Select `textPt` when locale is pt (fallback to `textEs` when null/empty).
- **Approach**: Pass resolved text in or read locale; prefer a getter on `Verse` (e.g. `textFor(locale)`) used by `VerseTile`, keeping locale-aware selection unit-testable.
- **Acceptance**: Unit test: locale `pt` + textPt present → shows textPt; textPt null → falls back to textEs. Widget test on VerseList.
- **Risk (F10)**: PT verses may be missing (nullable). Fallback to textEs covers this; note english locale currently has no textEn field — out of scope (F10 only es/pt).

## Approach

F1/F2 share a new `lib/theme/app_theme.dart` (seed/theme builders). F3/F5/F8 touch `home_screen.dart` + `SettingsProvider`. F4 extracts `AboutScreen` (reused by F8). F6/F7 touch `settings_screen.dart`. F10 adds `Verse.textFor`. All l10n flows through ARB. Tests: new `test/theme/*`, `test/home_ux/*`, `test/settings_ui/*`, updated l10n parity.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/main.dart` | Modified | themeMode + darkTheme |
| `lib/theme/app_theme.dart` | New | seed/theme builders, gold accent |
| `lib/screens/home_screen.dart` | Modified | F3 card, F5 tile, F8 strings, F9-ish scrim |
| `lib/screens/settings/settings_screen.dart` | Modified | F4 sections, F6/F7, F9, F8 dedupe |
| `lib/screens/settings/about_screen.dart` | New | F4 About extraction |
| `lib/widgets/verse_tile.dart` | Modified | F10 + F1 error color |
| `lib/models/verse.dart` | Modified | `textFor(locale)` F10 |
| `lib/providers/settings_provider.dart` | Modified | `lastWallpaperTimestamp` F3 |
| `lib/l10n/app_{en,es,pt}.arb` | Modified | new keys (F3,F5,F6,F7,F8) |
| `openspec/specs/*` | Modified | deltas: theme-core+, settings-ui+ |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| F2 recolor scope creep | Med | Gold idle additive; seed kept; explicit non-goal |
| Dark-mode contrast bugs on wallpaper text | Med | Scrim + theme-derived colors; manual device check F1 |
| `textPt` gaps (F10) | Med | Null-safe fallback to textEs; unit-tested |
| Settings restructure displaces discovered paths/update flow | Med | F4 extraction is pure move; existing update/tests preserved |
| Diff forecast >400 lines (`chained-PR` decision) | High | Orchestrator owns split; this file only flags it |

## Notes / Delivery

- **Change-size forecast**: high confidence this exceeds 400 changed lines (theme +
  About extraction + settings + l10n). **Chained PRs recommended: Yes. 400-line budget risk: High.**
  Slice proposal: PR-A theme-core+dark mode (F1, F2, F9); PR-B Home UX (F3, F5, F8, F10);
  PR-C Settings restructure (F4, F6, F7); PR-D l10n parity + tests. This split is deferred to
  the orchestrator/tasks — NOT decided here.
- Calibration stays commented out. No new pages beyond `AboutScreen`.

## Rollback Plan

Revert order by layered, independent folder scopes: (1) `app_theme.dart` + `main.dart` theme block (F1/F2) — revert alone restores light-only;
(2) `about_screen.dart` + Settings tile move (F4) — revert restores old sections;
(3) Home/Settings widget edits (F3,F5,F6,F7,F8) — revert reverts literals to current state;
(4) ARB additions — reverting ARB is additive-safe (keys unused downstream just drop).
Each slice reverts standalone via git; no schema/migration changes exist.

## Dependencies

- Flutter SDK with `ThemeMode`/M3; `intl` for relative time (verify availability from existing transitive deps).
- Existing `SettingsProvider` persistence (SharedPreferences) — extend, do not break key `last_wallpaper_path`.

## Success Criteria

- [ ] `flutter test` green (new theme/home/settings + l10n parity suites)
- [ ] `flutter analyze` zero errors
- [ ] Dark mode toggles live via system; no hardcoded `Colors.red`/`Colors.white` remain in `lib/`
- [ ] Home card: updated time + tappable; categories count localized + navigates; share/email localized
- [ ] Settings: About moved; single offset label; both previews captioned; scheduling not duplicated
- [ ] VerseTile/mobile-pt shows `textPt`; en/es/pt ARB key parity holds
- [ ] Manual device pass on light + dark confirms legibility and gold accent
