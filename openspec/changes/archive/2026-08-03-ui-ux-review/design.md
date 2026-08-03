# Design: UI/UX Review — Dark Mode, Visual Identity, Home & Settings Coherence

## Technical Approach

A focused refinement (NOT a rewrite) across three seams: (1) a new theme module becomes the single source of truth for light/dark system themes and the seed/gold scheme; (2) Home/Settings widgets get localized captions, a live wallpaper card, and a dedicated AboutScreen; (3) ARB gains parity keys. No backend/schema changes; SharedPreferences is only extended additively. Maps to specs: theme-core (F1,F2,F9), home-ux (F3,F5,F8,F10), settings-ui delta (F4,F6,F7).

## Architecture / Structure

```
lib/theme/app_theme.dart            NEW  seed/ThemeData builders, gold secondary
lib/screens/settings/about_screen.dart NEW F4 extraction
lib/main.dart                       MOD  themeMode + darkTheme
lib/providers/settings_provider.dart MOD lastWallpaperTimestamp (F3)
lib/screens/home_screen.dart        MOD  F3 card, F5 tile nav, F8 strings, scrim
lib/screens/settings/settings_screen.dart MOD F4 sections, F6 label, F7 caption, F9
lib/widgets/verse_tile.dart         MOD  F10 textFor, F1 errorContainer
lib/models/verse.dart               MOD  textFor(locale) getter
lib/l10n/app_{en,es,pt}.arb         MOD  new keys (parity)
test/theme/*, test/home_ux/*, test/settings_ui/* NEW
test/models/verse_test.dart         MOD  textFor tests
```

Composition: `app_theme.dart` imported by `main.dart` only for themes; `AboutScreen` shares `_SectionHeader` logic (extract to a tiny shared `lib/widgets/section_header.dart` used by Home and both settings screens to avoid trio duplication).

## Theme design (F1, F2, F9)

**API** (`lib/theme/app_theme.dart`):
```dart
const Color appSeedColor = Colors.deepPurple;      // F2: seed stays
final Color goldAccent = const Color(0xFFEFB14D);  // F2: additive secondary
ThemeData appLightTheme() => _base(Brightness.light);
ThemeData appDarkTheme()  => _base(Brightness.dark);
ThemeData _base(b) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: appSeedColor, brightness: b)
      .copyWith(secondary: goldAccent),           // F2
  useMaterial3: true);
```

`main.dart`: `theme: appLightTheme()`, `darkTheme: appDarkTheme()`, `themeMode: ThemeMode.system` (UX-THEME-001).

**F9 raw colors → scheme**:
- `verse_tile.dart:26` `Colors.red` → `colorScheme.errorContainer` + icon `onErrorContainer` (UX-THEME-004).
- `settings_screen.dart:935` `TextStyle(color: Colors.red)` → `Theme.of(context).colorScheme.error`.
- `home_screen.dart:176` `Colors.white` caption → replace hard shadow with a `Container` scrim `Colors.black54` behind the text; text `Colors.white` stays (scrim guarantees legibility both themes) (UX-THEME-005).

**Gold accent (F2)**: additive via `colorScheme.secondary.copyWith`. Applied at the Home primary CTA `FilledButton` (uses `colorScheme.primary` today — to honor "active CTA tint", set the CTA's `styleFrom(backgroundColor: colorScheme.secondary)` or rely on secondary for ChoiceChip `selectedColor` in Settings). Keep `deepPurple` as base; do NOT recolor other widgets (scope guard).

## SettingsProvider change (F3)

New `DateTime? _lastWallpaperTimestamp` + getter `lastWallpaperTimestamp`. Persistence key `last_wallpaper_timestamp` (STRING, `DateTime.toIso8601String()`), **write-only new key** — `last_wallpaper_path` untouched. Loaded in `init()` (line ~93) alongside path. Set inside `triggerNow` success branch (line ~247) alongside `_lastWallpaperPath`, persisted via the existing `prefs.setString` chain. **Backwards-compat**: old installs lack the key → `null` → Home shows no timestamp until next generation; `last_wallpaper_path` still governs the empty/exists state, so no regression.

## Home UX (F3, F5, F8, F10)

**Wallpaper card (F3)**: existing-path branch (home_screen.dart:162-186) wraps `Stack` in `InkWell` whose `onTap` calls the same permission-check + `triggerNow` as the Change-now button. Inside, add a `Positioned` bottom overlay: a `Container` scrim carrying a localized `currentWallpaperLabel` caption + the `updatedAtLabel(relativeTime)` from `lastWallpaperTimestamp`. Empty state unchanged.

**CTA ownership (UX-HOME-002)**: Home keeps primary (card tap + Change now). Settings keeps contextual Change now but visually secondary (keep `filled`; no new prominence). No logic duplication — both call `triggerNow`.

**Categories tile (F5)**: `home_screen.dart:278` subtitle → `l10n.activeCategoriesCount(settings.activeCategoryIds.length)`; add `onTap` → `Navigator.push(SettingsScreen)` (matches existing app-bar pattern).

**Verse.textFor (F10)**:
```dart
String textFor(String localeCode) =>
  (localeCode == 'pt' && textPt != null && textPt!.isNotEmpty)
      ? textPt! : textEs;   // es/pt only; mirror wallpaper_generator.dart:593
```
`VerseTile` reads locale via `Localizations.localeOf(context).languageCode` and uses `verse.textFor(...)`.

## Settings restructure (F4, F6, F7)

**AboutScreen (F4)** — pure move preserving the update state machine. Move exact widgets from settings_screen.dart:968-1008 and methods `_checkForUpdate`, `_showUpdateConfirmDialog`, `_downloadAndInstall`, `_closeProgressDialog`, `_showInstallAction`, `_startInstall`, `_releasePageUrl`, `_displayVersion`, `_formatSize`, plus `_UpdateCheckState`, fields, `_updateService` injectable seam. Reuses shared `_SectionHeader`. Settings replaces the About section with one `tile` (`sectionAbout` + `aboutDescription`) → `Navigator.push(AboutScreen(updateService: ...))`. New Setting section order: Appearance, Scheduling, Categories, Actions, then About link. Non-tabbed/non-collapsible (UX-SET-001). Home About section → same About tile navigation (dedupe share/email with AboutScreen).

**Single offset label (F6)**: remove the `Row` (743-760); keep Slider with `label: offsetLabel`; render ONE caption from sign via a new helper, resolved by ARB keys `offsetLabel` with direction+value placeholders (UX-SET-002).

**Preview captions (F7)**: overlay a small label chip/badge — Home uses `currentWallpaperLabel` (+time), Settings Appearance preview uses `previewLabel` (UX-SET-003).

## l10n plan

New ARB keys (template en; es/pt parity):
- `activeCategoriesCount(count)` → en "Active: {count}" / es "Activas: {count}" / pt "Ativas: {count}" (listable plural where FLUTTER supports; else simple placeholder).
- `shareApp(url)` → reuse in Home + Settings/About ("Descargá Vers Reminder: {url}" es).
- `emailCopied` — es "Email copiado al portapapeles".
- `currentWallpaperLabel` — en "Current wallpaper".
- `previewLabel` — en "Preview".
- `updatedAtLabel(time)` — en "Updated {time}".
- `offsetLabel(direction, value)` — sign-selected `leftOffset`/`rightOffset` reuse.
- `timeMinutes(n)` / `timeHours(n)` for `_formatMinutes` (delete raw `min`/`hora` literals in both home_screen and settings `_frequencyLabel` fallback).

`intl ^0.20.2` present for relative time (`Timeago`-style or DateFormat).

## Testing strategy

Map every spec scenario. New `test/theme/app_theme_test.dart`: seed constant referenced, light/dark `ThemeData` brightness, secondary==gold, no `deepPurple` literal elsewhere, `Colors.red` grep-clean in lib/. `test/theme/dark_mode_test.dart`: build `MaterialApp` with `themeMode.system` + dark platform → `Theme.of.brightness == dark`; error snackbar uses `colorScheme.error`. `test/home_ux/*`: card shows `currentWallpaperLabel`+time when path+timestamp set (UX-HOME-001), tap triggers (UX-HOME-002), empty state no caption; categories tile localizes + navigates + live count (UX-HOME-003); share/email/time localized (UX-HOME-004). `test/models/verse_test.dart` add `textFor` pt-present / pt-null fallback (UX-HOME-005). `test/settings_ui/about_screen_test.dart`: AboutScreen renders update/version/share/contact; Settings shows no update tiles + restructured section order (UX-SET-001); single offset node per state neg/pos (UX-SET-002); both captions present (UX-SET-003). Extend `test/l10n/locale_test.dart` with new keys across en/es/pt. Add `test/l10n/ar_parity_test.dart`: assert key-set(files) equal using a JSON load across en/es/pt.

## Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Dark contrast on image text | Scrim `black54` container (UX-THEME-005) + manual device check |
| `textPt` gaps | Null-safe fallback to textEs (tested) |
| F4 breaking update flow | Pure move; keep `updateService` seam; existing `settings_about_update_test.dart` retarget to AboutScreen + add Settings assertion |
| l10n parity breaks | Parity test asserts identical key set |
| F2 recolor creep | Gold via secondary only; seed constant; explicit non-goal |

## Migration / Rollout

No schema/migration. New `last_wallpaper_timestamp` key is nullable/write-only; adds drop harmlessly if reverted. Feature-flag-free; theme follows system immediately.

## Delivery slices (forecast; chained split is ORCHESTRATOR-owned at tasks)

- **PR-A theme (F1,F2,F9)**: `app_theme.dart`, `main.dart`, `verse_tile.dart` color, `settings_screen.dart:935`, scrim, gold on CTA. ~200–260 lines.
- **PR-B home (F3,F5,F8,F10)**: provider timestamp, `home_screen.dart`, `verse.dart.textFor`, `verse_tile.dart` text, `_formatMinutes`. ~250–320 lines.
- **PR-C settings (F4,F6,F7)**: `about_screen.dart`, section reorder, offset label, preview captions, shared `section_header.dart`. ~300–380 lines.
- **PR-D l10n+tests**: ARB edits, parity test, new theme/home/settings test files. ~350–450 lines.

Line forecast totals > 400 → **Chained PRs recommended: Yes; 400-line budget risk: High** (already flagged in proposal).

## Open Questions

- None blocking. Optional: confirm `activeCategoriesCount` pluralization (`intl` list/simple placeholder) — default to simple placeholder to avoid ICU gender variance.
