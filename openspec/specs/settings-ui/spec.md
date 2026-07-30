# Settings UI

## Description
A settings screen that provides controls for the wallpaper scheduler: enable/disable toggle, frequency selection, category filter, and immediate wallpaper trigger.

## Requirements

### R-SU-001: Settings Screen
The system SHALL provide a `SettingsScreen` accessible from the app. Navigation entry point SHALL be from the main app bar or navigation.

### R-SU-002: Scheduler Toggle
The screen SHALL display a switch toggle to enable/disable the wallpaper scheduler.

### R-SU-003: Frequency Radio List
The screen SHALL display radio buttons for frequency selection: 30 min, 1h, 3h, 6h, 12h, 24h. The currently selected frequency SHALL be pre-selected. Changing the selection SHALL immediately update and persist.

### R-SU-004: Frequency Disabled State
The frequency radio list SHALL be visually disabled (greyed out, non-interactive) when scheduling is OFF.

### R-SU-005: Category Checklist
The screen SHALL display a checkbox list of all categories from `VerseProvider.categories`. Each category SHALL have a checkbox reflecting its active/inactive state. Toggling a checkbox SHALL immediately persist the change.

### R-SU-006: "Change Now" Button
The screen SHALL display a prominent button labeled "Change Now" (or localized equivalent). Tapping it SHALL:
- If at least one category is active: immediately generate and set a wallpaper with a random verse from active categories
- If no categories are active: display a snackbar or message "Select at least one category first"

### R-SU-007: Localization

The screen MUST render all user-facing strings using `AppLocalizations` lookups via the generated l10n library. Status messages MUST be derived from `WallpaperStatus` enum values through a local `_mapStatus` method. Toggling the app locale SHALL update all visible strings immediately.

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

## Scenarios

### Scenario SU-01: Open settings
Given the user is on the main screen
When the user navigates to Settings
Then the Settings screen is displayed with scheduler toggle (OFF), frequency list, category checkboxes, and "Change Now" button

### Scenario SU-02: Enable and see frequencies enabled
Given the Settings screen is open with scheduler OFF
When the user toggles scheduling ON
Then the frequency radio list becomes interactive
And the selected frequency is highlighted

### Scenario SU-03: Disable and see frequencies disabled
Given the Settings screen is open with scheduler ON
When the user toggles scheduling OFF
Then the frequency radio list becomes greyed out and non-interactive

### Scenario SU-04: Toggle a category
Given the Settings screen is open
When the user checks/unchecks a category
Then the change is persisted immediately in `app_config.active_category_ids`

### Scenario SU-05: "Change Now" works
Given at least one category is active
When the user taps "Change Now"
Then a wallpaper is generated with a verse from an active category

### Scenario SU-06: "Change Now" with no categories
Given no categories are active
When the user taps "Change Now"
Then a snackbar shows "Select at least one category first"
