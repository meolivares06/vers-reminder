# Home Navigation Specification

## Purpose

The Home screen's About section: shows the real installed app version and exposes an action to share the app (GitHub releases/latest link), mirroring the Settings screen behavior.

## Requirements

### Requirement: Dynamic Version Tile on Home

The Home About section MUST display the installed app version using the shared App Version Helper (see `shared-ui`). The Home screen MUST NOT display the hardcoded `l10n.aboutVersion` string. The displayed version SHALL match what the Settings About section shows.

#### Scenario: Home shows real version

- GIVEN the app is installed with version `3.0.1` and build `12`
- WHEN the Home About section loads
- THEN it SHALL display `v3.0.1+12`

#### Scenario: Home does not show stale version

- GIVEN the installed version differs from any previously hardcoded value
- WHEN the Home About section renders
- THEN no static/hardcoded version string SHALL be displayed

### Requirement: Share Action on Home

The Home About section SHALL provide a Share action mirroring the Settings screen. Activating it SHALL invoke the platform share sheet with the app's GitHub releases/latest link.

#### Scenario: Shares releases link

- GIVEN the user is on the Home screen
- WHEN the user taps the Share action
- THEN the platform share sheet SHALL open with the GitHub releases/latest URL

#### Scenario: Share cancel does not crash

- GIVEN the share sheet is open
- WHEN the user dismisses/cancels it
- THEN the Home screen SHALL remain unchanged with no error shown
