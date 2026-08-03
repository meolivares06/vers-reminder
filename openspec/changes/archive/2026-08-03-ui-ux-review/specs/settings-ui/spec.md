# Delta for Settings UI

## ADDED Requirements

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
