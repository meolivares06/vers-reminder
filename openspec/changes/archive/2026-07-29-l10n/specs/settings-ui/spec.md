# Delta for Settings UI

## MODIFIED Requirements

### R-SU-007: Localization

The screen MUST render all user-facing strings using `AppLocalizations` lookups via the generated l10n library. Status messages MUST be derived from `WallpaperStatus` enum values through a local `_mapStatus` method. Toggling the app locale SHALL update all visible strings immediately.
(Previously: forward placeholder stating support for ES/PT locales)

#### Scenario: Strings appear in selected locale

- GIVEN the app locale is set to PT
- WHEN the user navigates to Settings
- THEN all labels, buttons, and messages display in Portuguese

#### Scenario: Locale switch updates strings live

- GIVEN the Settings screen is open in ES
- WHEN the user switches locale to PT
- THEN all visible strings update to Portuguese without navigation

#### Scenario: Status displays localized message

- GIVEN `WallpaperStatus` is `updated` with fileName `wallpaper_123.jpg`
- WHEN the status listener fires
- THEN the UI displays the localized updated message including the file name

## ADDED Requirements

### R-SU-008: Status Display from Enum

The screen MUST derive its status display from a `WallpaperStatus` enum (`idle | generating | updated(fileName) | error(reason) | noCategories`) exposed by `SettingsProvider`. The screen SHALL map each variant to a localized string. The `String? statusPayload` field SHALL supply dynamic content (citation, error detail). The screen SHALL use `context.watch` to react to status changes.

#### Scenario: Shows "Generating" on generate request

- GIVEN `WallpaperStatus` is `generating`
- WHEN the Settings screen rebuilds
- THEN the UI shows the localized "Generating..." equivalent

#### Scenario: Shows updated result with file name

- GIVEN `WallpaperStatus` is `updated` with `statusPayload: "wallpaper_123.jpg"`
- WHEN the Settings screen rebuilds
- THEN the UI shows the localized updated message including the file name

#### Scenario: Shows no-categories message on action

- GIVEN the user taps "Change Now" with all categories inactive
- WHEN `SettingsProvider` sets `WallpaperStatus.noCategories`
- THEN the UI shows "Select at least one category first"

#### Scenario: Shows generic error message

- GIVEN `WallpaperStatus` is `error` with `statusPayload: "storage_failure"`
- WHEN the Settings screen rebuilds
- THEN the UI shows a generic localized error message
- AND the specific reason is logged to console

#### Scenario: Idle state shows nothing

- GIVEN `WallpaperStatus` is `idle`
- WHEN the Settings screen rebuilds
- THEN no status message area is rendered
