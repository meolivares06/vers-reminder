# Delta for l10n-core

## ADDED Requirements

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

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: liveWallpaperNotSupported key

(Reason: Live wallpaper probe removed — no conditional UI to translate.)
(Migration: Delete key from `app_en.arb`, `app_es.arb`, `app_pt.arb`. Remove all code references in `settings_screen.dart`.)

### Requirement: fallbackToNature key

(Reason: No SnackBar shown for fallback — file read fallback is silent.)
(Migration: Delete key from all three ARB files. Remove `lastFallback` SnackBar code from `settings_screen.dart`.)
