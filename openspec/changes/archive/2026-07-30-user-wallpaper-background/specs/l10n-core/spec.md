# Delta for L10n Core

## ADDED Requirements

### Requirement: Background Source Localization Keys

The system MUST add five new ARB keys across all three locale files: `backgroundSourceLabel`, `backgroundSourceApp`, `backgroundSourceMine`, `liveWallpaperNotSupported`, and `fallbackToNature`. English (`app_en.arb`) SHALL be the template. All keys MUST be present in `app_es.arb` and `app_pt.arb` with translated values.

#### Scenario: All five keys present across locales

- GIVEN `app_en.arb` defines the five new keys
- WHEN `app_es.arb` and `app_pt.arb` are validated
- THEN every new key MUST exist with a translated value in both files

#### Scenario: SegmentedButton renders localized labels

- GIVEN the active locale is Spanish
- WHEN the Settings screen renders the background source toggle
- THEN the "App" segment MUST display the ES value of `backgroundSourceApp`
- AND the "Mío" segment MUST display the ES value of `backgroundSourceMine`
- AND the section label MUST display the ES value of `backgroundSourceLabel`

#### Scenario: Live wallpaper explanation is localized

- GIVEN the device has a live wallpaper and locale is Portuguese
- WHEN the Settings screen hides the toggle
- THEN the explanation text MUST display the PT value of `liveWallpaperNotSupported`

#### Scenario: Fallback SnackBar is localized

- GIVEN a runtime fallback occurs and locale is Portuguese
- WHEN the SnackBar is shown
- THEN the message MUST display the PT value of `fallbackToNature`
