# Delta for L10n Core

## ADDED Requirements

### Requirement: Version string is dynamic

The version shown in the Home and Settings About sections SHALL be rendered from the shared App Version Helper (see `shared-ui`), not from a localized ARB string. No ARB key is required for the version display.

#### Scenario: About sections use dynamic version

- GIVEN the app is installed with a real version and build
- WHEN the Home or Settings About section renders
- THEN the displayed version SHALL reflect the installed build, independent of the active locale

### Requirement: Existing strings reused for new actions

The Home Share action SHALL reuse the existing `aboutShare` key, and the Restore tile SHALL reuse the existing `restoreOriginalWallpaper`/`restoreOriginalWallpaperSubtitle` keys. No new locale keys SHALL be introduced for these actions beyond what already exists.

#### Scenario: Share label present in all locales

- GIVEN the Home Share action is rendered
- WHEN the active locale is ES, PT, or EN
- THEN the action SHALL display the localized value of `aboutShare` for that locale

## REMOVED Requirements

### Requirement: aboutVersion string

The `aboutVersion` ARB key SHALL be removed from `app_en.arb`, `app_es.arb`, and `app_pt.arb`, and its generated accessor SHALL be removed from `l10n`/generated output. The app MUST NOT reference `aboutVersion` anywhere.

(Reason: it hardcodes a stale "Version 1.0.0" that never tracks releases; versions are now dynamic via the shared App Version Helper.)
(Migration: replace any `l10n.aboutVersion` reference with the version string produced by the App Version Helper; regenerate l10n so the unused accessor disappears.)
