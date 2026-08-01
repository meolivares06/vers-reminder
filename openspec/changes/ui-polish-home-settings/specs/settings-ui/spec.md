# Delta for Settings UI

## ADDED Requirements

### Requirement: Wallpaper-First Section Order

The Settings screen SHALL render sections in this order: (1) Wallpaper section — preview and its parameter controls (font, alignment, offset, background source) grouped first, (2) Scheduling, (3) Categories, (4) Actions, (5) About. The wallpaper preview and its parameters SHALL appear above Scheduling. No other section SHALL precede the wallpaper section.

#### Scenario: Wallpaper section is first

- GIVEN the user opens Settings
- WHEN the screen renders
- THEN the wallpaper preview and its parameters SHALL appear above Scheduling
- AND Scheduling, Categories, Actions, and About SHALL follow in that order

### Requirement: Restore Original Wallpaper Tile

The Restore action SHALL be rendered as a clearly clickable tile within the wallpaper section, not as plain text. The tile SHALL be tappable only when a wallpaper backup exists. When no backup exists, the tile SHALL be either hidden or disabled, with no tap action available. Tapping it SHALL invoke the wallpaper restore.

#### Scenario: Backup exists — tile clickable

- GIVEN a wallpaper backup exists AND the user is on the wallpaper section
- WHEN the user taps the Restore tile
- THEN the original wallpaper SHALL be restored

#### Scenario: No backup — tile disabled or hidden

- GIVEN no wallpaper backup exists
- WHEN the wallpaper section renders
- THEN the Restore tile SHALL be hidden or disabled AND NOT tappable

### Requirement: Inline Blocking Loader on Actions

The "Change Now", "Check for updates", and "Restore original wallpaper" actions SHALL each use the shared Inline Blocking Loader Button (see `shared-ui`). While each action's future is in flight, its button SHALL be disabled and SHALL show an inline `CircularProgressIndicator`. The loader SHALL forward each action's result and errors verbatim, and SHALL NOT couple with the update state machine or wallpaper trigger logic.

#### Scenario: Change Now blocks while running

- GIVEN the user taps "Change Now"
- WHEN its future is in flight
- THEN the button SHALL be disabled and SHALL show an inline spinner

#### Scenario: Check for updates blocks while running

- GIVEN the user taps "Check for updates"
- WHEN the update-check future is in flight
- THEN the action SHALL be disabled and SHALL show an inline spinner

#### Scenario: Restore blocks while running

- GIVEN the user taps "Restore original wallpaper"
- WHEN the restore future is in flight
- THEN the Restore tile SHALL be disabled and SHALL show an inline spinner

## MODIFIED Requirements

### Requirement: "Change Now" Button

The screen SHALL display a prominent button labeled "Change Now" (or localized equivalent). While its action runs, the button SHALL be disabled and show an inline `CircularProgressIndicator` via the shared loader button. On success:
- If at least one category is active: immediately generate and set a wallpaper with a random verse from active categories
- If no categories are active: display a snackbar "Select at least one category first"

(Previously: tapping the button ran the action with no inline blocking loading state)

#### Scenario: Spinner during generation

- GIVEN the user taps "Change Now" with a category active
- WHEN the generation future is in flight
- THEN the button SHALL be disabled with an inline spinner

#### Scenario: Generates wallpaper

- GIVEN at least one category is active
- WHEN the future completes successfully
- THEN a wallpaper SHALL be generated from an active category
- AND the button SHALL re-enable

#### Scenario: No categories

- GIVEN no categories are active
- WHEN the user taps "Change Now"
- THEN a snackbar SHALL show "Select at least one category first"

#### Scenario: Error propagated

- GIVEN the generation future throws
- WHEN the action completes
- THEN the original error SHALL be surfaced unchanged
- AND the button SHALL re-enable
