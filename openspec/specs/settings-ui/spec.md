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

### UX-SET-001: About Screen Extraction

The system MUST move About content (update/version/share/contact) from `settings_screen.dart` into a dedicated `AboutScreen` (`lib/screens/settings/about_screen.dart`). Settings SHALL reach About via a Settings tile that opens `AboutScreen`. Settings SHALL reduce from six sections to four sections plus one About link, in order: Appearance, Scheduling, Categories, Actions, then About. The restructure MUST be non-tabbed and non-collapsible.

- **Finding**: F4

#### Scenario: Settings shows restructured sections

- GIVEN the user opens Settings
- WHEN the screen renders
- THEN the appearance, scheduling, categories, actions, and About-link tiles render in that order
- AND no schedule-collapsible or tabbed grouping is used

#### Scenario: About opens on a dedicated screen

- GIVEN the user taps the About tile
- WHEN navigation resolves
- THEN `AboutScreen` renders update, version, share, and contact information

#### Scenario: Update tiles removed from Settings

- GIVEN the user is on Settings
- WHEN the screen renders
- THEN no update-check/version/share/contact tiles are present in Settings
- AND navigation to About is the only path to that content

### UX-SET-002: Single Dynamic Offset Label

The system MUST render exactly ONE offset-related caption for the horizontal offset slider. The caption SHALL derive direction from the value sign: negative → "Left", positive → "Right", zero → "Right" (or neutral). The static left/right `Row` labels SHALL be removed. No duplicate offset text nodes SHALL render in any state.

- **Finding**: F6

#### Scenario: Negative offset shows Left

- GIVEN `horizontalOffset` is `-5`
- WHEN the slider area renders
- THEN exactly one offset caption is shown with the "Left" direction

#### Scenario: Positive offset shows Right

- GIVEN `horizontalOffset` is `5`
- WHEN the slider area renders
- THEN exactly one offset caption is shown with the "Right" direction

#### Scenario: No duplicate labels

- GIVEN the Settings screen has an offset configured
- WHEN the slider area renders
- THEN only one offset-related text node exists in the widget tree

### UX-SET-003: Distinct Preview Captions

The system MUST caption both wallpaper previews so the real vs composition previews are distinguishable: Home shows a "Current wallpaper" caption accompanied by the updated time (see UX-HOME-001); Settings shows a "Preview" caption above its composition preview. The two preview types MUST be visually distinguishable by label.

- **Finding**: F7

#### Scenario: Home caption marks the live wallpaper

- GIVEN a wallpaper exists and the Home card renders
- WHEN the card is inspected
- THEN a localized "Current wallpaper" caption is shown alongside the updated time
- AND the underlying image is the real `Image.file`

#### Scenario: Settings caption marks the composition preview

- GIVEN the Settings Appearance section renders its preview
- WHEN the preview is inspected
- THEN a localized "Preview" caption is present

#### Scenario: Localized captions via ARB

- GIVEN the locale is PT
- WHEN the captions render on both screens
- THEN both caption strings resolve from ARB keys with PT values
- AND no hardcoded caption literal appears in Dart

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

### Requirement: Image Picker Integration

When the "Mío" segment is selected, if `{appDir}/user_background.png` does NOT exist, the system MUST open `ImagePicker.pickImage(source: ImageSource.gallery)` automatically. If the file exists, the system SHALL display a thumbnail of the stored image with a "Replace" option. The picked image MUST be saved to `{appDir}/user_background.png` (overwriting any previous file). After saving, the preview MUST regenerate with the new photo.

#### Scenario: First-time selection opens picker

- GIVEN the user selects "Mío" AND `{appDir}/user_background.png` does NOT exist
- WHEN the segment changes
- THEN `ImagePicker.pickImage()` MUST be called with `ImageSource.gallery`
- AND the background source remains "App" until the picker succeeds

#### Scenario: Image stored shows thumbnail + replace

- GIVEN the user selects "Mío" AND `{appDir}/user_background.png` exists
- WHEN the segment changes
- THEN the stored image thumbnail MUST be displayed
- AND a "Replace" button SHALL be visible

#### Scenario: Picked image saved and preview updates

- GIVEN the user picks an image from the gallery
- WHEN the picker returns the selected image
- THEN the image MUST be saved to `{appDir}/user_background.png`
- AND `useMyWallpaper` MUST be set to `true`
- AND the preview MUST regenerate using the new photo

#### Scenario: Picker cancelled reverts to "App"

- GIVEN the user selects "Mío" AND no image is stored
- WHEN the user cancels the image picker
- THEN `useMyWallpaper` MUST remain (or be reset to) `false`
- AND the SegmentedButton MUST revert to "App"

#### Scenario: Replace overwrites old file

- GIVEN `{appDir}/user_background.png` exists
- WHEN the user taps "Replace" and picks a new image
- THEN the old file MUST be overwritten
- AND the preview MUST regenerate with the new photo

### Requirement: Background Source Toggle

The Settings screen SHALL display a `SegmentedButton<string>` with segments "App" and "Mío" in the Appearance section, labeled by `AppLocalizations.backgroundSourceLabel`. The default selection SHALL be "App". The choice MUST persist via `SettingsProvider.useMyWallpaper` → SharedPreferences key `use_my_wallpaper`. Toggling the source SHALL invalidate the cached `_previewImagePath`. The SegmentedButton SHALL always be visible — no probe needed.

(Previously: SegmentedButton hidden when live wallpaper detected via probe. Probe removed — `image_picker` works on all Android versions.)

#### Scenario: Default segment is "App"

- GIVEN no persisted `use_my_wallpaper` value exists
- WHEN the Settings screen loads
- THEN the "App" segment MUST be selected
- AND `useMyWallpaper` returns `false`

#### Scenario: Toggle persists across restarts

- GIVEN the user selects "Mío"
- WHEN the app is restarted
- THEN the SegmentedButton MUST show "Mío" as selected
- AND `SharedPreferences` key `use_my_wallpaper` MUST be `true`

#### Scenario: Preview invalidated on toggle

- GIVEN a preview image is cached from "App" source
- WHEN the user toggles to "Mío"
- THEN `_previewImagePath` MUST be set to null
- AND the preview MUST regenerate with the new source

(Reason for removals: No probe needed — `getWallpaper` MethodChannel is removed and `image_picker` works on all Android versions. The SegmentedButton is always visible. File read failures in wallpaper-gen still fall back defensively but the UI no longer shows a `fallbackToNature` SnackBar.)
