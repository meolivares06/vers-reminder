# L10n Core Specification

## Purpose

Provide Flutter localization infrastructure for ES and PT locales. Owns `l10n.yaml`, ARB source files, generated `AppLocalizations`, `MaterialApp` delegate wiring, and locale resolution (auto-detect + manual override).

## Requirements

### R-L10N-001: ARB Source Files

The system MUST provide `app_en.arb` as the key template with `app_es.arb` and `app_pt.arb` as full translations. All ~50 user-facing strings MUST share the same key set across locales. Frequency labels MUST use flat ARB entries (`freq_30min`, `freq_1h`, `freq_3h`, `freq_6h`, `freq_12h`, `freq_24h`).

#### Scenario: All keys present across locales

- GIVEN `app_en.arb` defines keys for all ~50 strings
- WHEN `app_es.arb` and `app_pt.arb` are validated
- THEN every key in `app_en.arb` exists in both translated files

#### Scenario: Generation succeeds

- GIVEN `l10n.yaml` configures `synthetic-package: false` with supported locales `[en, es, pt]`
- WHEN `flutter gen-l10n` runs
- THEN `AppLocalizations` and delegate classes are generated under `lib/l10n/`
- AND generation completes with zero warnings

### R-L10N-002: Locale Resolution

The app SHALL detect the device locale on startup and select ES or PT matching the device preference. The user MAY override the locale via a persistent setting. The override SHALL take precedence and persist across sessions.

#### Scenario: Device locale auto-detection

- GIVEN the device language is Portuguese
- WHEN the app launches with no stored locale override
- THEN `MaterialApp` renders all UI in Portuguese

#### Scenario: Manual override persists

- GIVEN the user overrides locale from ES to PT
- WHEN the app is restarted
- THEN the UI renders in PT

#### Scenario: Unsupported locale falls back

- GIVEN the device locale is French (not ES or PT)
- WHEN the app launches
- THEN `MaterialApp` falls back to the default locale (ES)

### R-L10N-003: AppLocalizations Wiring

The system MUST add `AppLocalizations.delegate` and `LocalizationsDelegate` for ES and PT to `MaterialApp.supportedLocales` and `MaterialApp.localizationsDelegates`. Generated delegates SHALL be the single source of truth for all user-facing strings.

#### Scenario: Delegates wired correctly

- GIVEN `main.dart` imports the generated l10n library
- WHEN `MaterialApp` is configured
- THEN `supportedLocales` contains `Locale('en')`, `Locale('es')`, `Locale('pt')`
- AND `localizationsDelegates` includes `AppLocalizations.delegate`

### Requirement: Image Picker Localization Keys

The system MUST add four new ARB keys across all three locale files (EN, ES, PT): `pickBackgroundImage`, `replaceBackgroundImage`, `backgroundSelected`, and `backgroundPickFailed`. English (`app_en.arb`) SHALL be the template with these values: "Choose background image", "Replace image", "Background image selected", and "Could not open image picker". All keys MUST be present in `app_es.arb` and `app_pt.arb` with translated values.

#### Scenario: All four keys present across locales

- GIVEN `app_en.arb` defines the four new keys
- WHEN `app_es.arb` and `app_pt.arb` are validated
- THEN every new key MUST exist with a translated value in both files

#### Scenario: Image picker button is localized

- GIVEN the active locale is Portuguese AND `{appDir}/user_background.png` exists
- WHEN "Mío" is selected and the user sees the replace option
- THEN the button label MUST display the PT value of `replaceBackgroundImage`

### Requirement: Background Source Localization Keys

The system MUST add three ARB keys across all three locale files: `backgroundSourceLabel`, `backgroundSourceApp`, and `backgroundSourceMine`. The SegmentedButton SHALL always be visible — `liveWallpaperNotSupported` and `fallbackToNature` are REMOVED. The `backgroundSourceMine` description SHALL read "Your photo via image picker" instead of "Your device wallpaper".

(Previously: five keys including `liveWallpaperNotSupported` and `fallbackToNature`. `backgroundSourceMine` described "Use your device wallpaper")

#### Scenario: Three keys present across locales

- GIVEN `app_en.arb` defines the three remaining keys
- WHEN `app_es.arb` and `app_pt.arb` are validated
- THEN every key MUST exist in both files

#### Scenario: SegmentedButton renders localized labels

- GIVEN the active locale is Spanish
- WHEN the Settings screen renders the background source toggle
- THEN the "App" segment MUST display the ES value of `backgroundSourceApp`
- AND the "Mío" segment MUST display the ES value of `backgroundSourceMine`
- AND the section label MUST display the ES value of `backgroundSourceLabel`
