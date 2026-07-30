# Tasks: L10n — Full UI Translation & Provider Decoupling

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~200-350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR (all phases in one batch) |
| Delivery strategy | single-pr-default |
| Chain strategy | none |

Decision needed before apply: No (resolved — single PR, medium budget risk, under the 400-line ceiling)

Chained PRs recommended: No
Chain strategy: none
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Infrastructure: l10n config, ARB expansion, delegates wiring | Single PR | 3-4 files, ~80 lines |
| 2 | Provider/Model refactor: WallpaperStatus, WallpaperResult error variants | Single PR | 3 files, ~60-80 lines |
| 3 | UI string replacement: 9 files → AppLocalizations lookups | Single PR | 7 UI + 2 service files, ~100-150 lines |
| 4 | Tests: WallpaperStatus, locale switching | Single PR | 3 test files, ~60 lines |

## Pre-flight Checks

- [x] Verify `intl ^0.20.2` and `flutter_localizations` are already in `pubspec.yaml` (confirmed — present)
- [x] Confirm `flutter gen-l10n` CLI is available on the dev machine
- [x] Confirm existing ARB keys at `lib/l10n/app_{es,pt}.arb` (25 keys each) as baseline

## Phase 1: Infrastructure

- [x] 1.1 Create `l10n.yaml` at project root with `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-dir: lib/l10n/generated`
- [x] 1.2 Create `app_en.arb` as template with 61 keys in English: appBar titles, button labels, form labels/hints, toggle, frequency/alignment/slider labels, dialog strings, status messages, calibration strings, validation errors, empty states. Uses `@placeholders` with `{citation}`, `{error}` for interpolated strings
- [x] 1.3 Add ~39 missing keys to `app_es.arb`: frequency labels, alignment labels, slider labels, dialog strings, calibration instructions, permission dialog, status messages, validation errors
- [x] 1.4 Add ~39 missing keys to `app_pt.arb` — Portuguese translations for all new keys
- [x] 1.5 Run `flutter gen-l10n` — success. Generated 4 files under `lib/l10n/generated/`: `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_es.dart`, `app_localizations_pt.dart`
- [x] 1.6 Update `lib/main.dart`: import AppLocalizations, use `AppLocalizations.localizationsDelegates`, add `Locale('en')` to `supportedLocales`. Removed unused `flutter_localizations` import

## Phase 2: Provider/Model Refactor

- [x] 2.1 Create `lib/models/wallpaper_status.dart` — simple enum (not sealed class) per user's explicit instruction: `WallpaperStatus { idle, generating, updated, error, noCategories }`. The UI switches on this and reads `statusPayload` from SettingsProvider.
- [x] 2.2 Refactor `lib/models/wallpaper_result.dart` — replaced flat class with sealed `WallpaperResult` type: `WallpaperResultSuccess` with `wallpaperPath`, `verseText`, `citation` and `WallpaperResultError` with `WallpaperErrorReason`. Removed all hardcoded error strings from `wallpaper_generator.dart`, replaced with domain error variants.
- [x] 2.3 Refactor `lib/providers/settings_provider.dart` — removed `_statusMessage` and `setStatusMessage()`. Added `WallpaperStatus _status` and `String? _statusPayload`. Updated `triggerNow()` to use status enum. Exposed `WallpaperStatus get status` getter.

## Phase 3: UI String Replacement

All user-facing strings in the following files MUST use `AppLocalizations.of(context)!` lookups. No hardcoded string literals in UI contexts.

- [x] 3.1 `lib/main.dart` — replaced `title: 'Vers Reminder'` with `AppLocalizations.of(context)?.appTitle ?? 'Vers Reminder'` (nullable-safe; AppLocalizations not available at Consumer context before MaterialApp builds)
- [x] 3.2 `lib/screens/settings/settings_screen.dart` — replaced all ~25 hardcoded strings (appbar title, toggle labels, frequency labels via `_frequencyLabel()` helper, radio titles, slider labels, button text, permission dialog, status message display migrated to use `WallpaperStatus` via `_mapStatus()` method)
- [x] 3.3 `lib/screens/backoffice/verse_list_screen.dart` — replaced appbar title, empty state; pass verse citation to ConfirmDeleteDialog instead of hardcoded string
- [x] 3.4 `lib/screens/backoffice/verse_form_screen.dart` — replaced appbar title (edit/new), save button, form labels, hint text, validation errors, categories label, add-category chip label
- [x] 3.5 `lib/screens/backoffice/category_create_dialog.dart` — replaced dialog title, label text, validation error, cancel/create buttons
- [x] 3.6 `lib/screens/calibration/calibration_screen.dart` — replaced all ~15 strings (appbar title, instruction card, labels, button text, snackbar message, reset button, status card migrated to `WallpaperStatus`)
- [x] 3.7 `lib/widgets/confirm_delete_dialog.dart` — replaced dialog title, content template, cancel/delete buttons

## Phase 4: Tests

- [x] 4.1 Update `test/models/wallpaper_result_test.dart` — rewrote tests for sealed `WallpaperResultSuccess` and `WallpaperResultError` variants, verified all four `WallpaperErrorReason` values
- [x] 4.2 Update `test/providers/settings_provider_test.dart` — verify `WallpaperStatus.idle` initial state, `noCategories` on trigger with empty categories, `error` after trigger with categories but no verses
- [x] 4.3 Add locale switching integration test in `test/l10n/locale_test.dart` — verify `AppLocalizations.of(context)` returns correct localized strings for ES, PT, and EN locales, and that switching from ES to PT updates all strings
