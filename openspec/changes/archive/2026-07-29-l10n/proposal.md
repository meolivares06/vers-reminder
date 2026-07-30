# Proposal: L10n — Full UI Translation & Provider Decoupling

## Intent

Enable ES/PT locale switching for all ~50 user-facing strings. Simultaneously decouple `SettingsProvider` and `WallpaperGenerator` from holding hardcoded UI strings — replacing them with domain result types that the UI layer translates.

## Proposal Question Round

1. **Provider status protocol**: Should providers use a sealed `WallpaperStatus` (e.g., `WallpaperStatus.generating`, `.updated(fileName)`, `.error(reason)`) that the UI maps to ARB keys, or a simpler enum without payloads (delegating all formatting to the UI)?

2. **WallpaperGenerator errors**: These English strings (`'No nature images available'`) surface in the UI — should they be user-visible localized messages, or should we show a generic ARB key like `'wallpaper_generation_failed'` and log the specifics?

3. **Scope boundary**: Localize ALL ~50 strings (backoffice + settings + calibration + dialogs), or just the main UX flow (backoffice CRUD + settings) and defer calibration/edge-case strings?

4. **Frequency labels** (`'30 min'`, `'1 hora'`): use `Intl.plural` with ICU messages, or flat ARB entries like `frequency_30min` / `frequency_1h`?

5. **Status message surface**: Should a UI-side `StatusConsumer` widget listen to `ValueNotifier<WallpaperStatus>`, or keep the string field but pipe through a localize extension method in the widget layer?

## Scope

### In Scope
- Create `l10n.yaml`, expand ES/PT ARB files to cover all ~50 strings
- Generate `AppLocalizations`, wire delegates into `MaterialApp`
- Replace hardcoded strings with `AppLocalizations` across 9 files
- Refactor `SettingsProvider._statusMessage` → domain result type; UI translates
- Abstract `WallpaperGenerator` error strings into result types

### Out of Scope
- Adding locales beyond ES/PT
- RTL layouts, date/number formatting (already handled globally)
- UI layout or behavior changes — translation and decoupling only

## Capabilities

### New
- `l10n-core`: Flutter l10n infra — `l10n.yaml`, ARB sources, generated `AppLocalizations`, delegate wiring

### Modified
- `backoffice`: All hardcoded strings → `AppLocalizations` lookups
- `settings-ui`: R-SU-007 (Localization) now implemented; status flow decoupled to result types
- `wallpaper-gen`: Error strings → domain result types; UI maps them to ARB keys at display time

## Approach

1. **Create `l10n.yaml`** → `lib/l10n/`, template `app_en.arb`, supported ES/PT
2. **Expand ARB files**: add ~25 missing keys (interpolated strings use `Intl.message` params)
3. **Generate & wire**: `flutter gen-l10n`, add delegates to `MaterialApp`
4. **Refactor status flow** (critical): introduce sealed class `WallpaperStatus` (`idle | generating | updated(fileName) | error(reason) | noCategories`). UI listens and calls a local `_mapStatus()` using `AppLocalizations`
5. **Refactor wallpaper errors**: `WallpaperResult` variants → UI maps each to localized string
6. **Replace strings**: 9 files → `AppLocalizations.of(context)!`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/l10n/` | Modified | ARB expansion + `l10n.yaml` |
| `lib/main.dart` | Modified | l10n delegates |
| `lib/providers/settings_provider.dart` | Refactored | Status type replaces string field |
| `lib/services/wallpaper_generator.dart` | Modified | Error strings → result types |
| `lib/screens/*.dart` (6 files) | Modified | Strings → AppLocalizations |
| `lib/widgets/*.dart` (2 files) | Modified | Strings → AppLocalizations |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Provider refactoring breaks status display | Med | Add result type first with both old+new, migrate consumers, remove old |
| ARB key naming conflicts | Low | Normalize names; regenerate ARBs from scratch |
| Review budget blow (9 files) | Med | Split: (1) infra + backoffice, (2) settings + calibration, (3) provider refactor |

## Rollback Plan

Revert `l10n.yaml` → delete generated code → revert `MaterialApp` delegates → revert string replacements. Keep old `_statusMessage` as deprecated bridge during migration.

## Dependencies

`intl` + `flutter_localizations` packages in `pubspec.yaml`. Generated files checked into VCS.

## Success Criteria

- [ ] `AppLocalizations` compiles in all 9 files with zero missing-key errors
- [ ] `SettingsProvider` has zero hardcoded UI strings; status is `WallpaperStatus`
- [ ] `WallpaperGenerator` returns domain result types, not error strings
- [ ] `flutter gen-l10n` completes with zero warnings
- [ ] Toggling ES ↔ PT shows all UI strings correctly
