# Home Navigation Specification

## Purpose

Navigation shell hosting Home and Verses tabs via `IndexedStack`. Provides a single AppBar shared across tabs, tab-aware FAB, and a `NavigationBar` for tab switching.

## Requirements

### Requirement: Shared AppBar

The system SHALL render a single AppBar shared across both tabs. The title MUST change with the selected tab. Settings and language toggle icons MUST appear on both tabs.

#### Scenario: Title on Home tab

- GIVEN the user selects the Home tab (index 0)
- WHEN the AppBar renders
- THEN the title shows "Vers Reminder"
- AND settings and language icons are visible

#### Scenario: Title on Verses tab

- GIVEN the user selects the Verses tab (index 1)
- WHEN the AppBar renders
- THEN the title shows the localized verse list title
- AND settings and language icons are visible

#### Scenario: Single AppBar on Verses tab

- GIVEN the user switches to the Verses tab
- WHEN the Verses tab renders its content
- THEN exactly one AppBar is visible
- AND the verse list renders without wrapping Scaffold chrome

### Requirement: Language Toggle in AppBar

The system MUST provide an ES/PT locale toggle as an AppBar action accessible from both tabs. Tapping the icon SHALL switch the locale and cause all visible strings to update.

#### Scenario: Toggle locale from Home tab

- GIVEN the current locale is ES and the user is on the Home tab
- WHEN the user taps the language icon
- THEN the locale switches to PT
- AND all strings in both Home content and AppBar update to Portuguese

#### Scenario: Toggle locale from Verses tab

- GIVEN the current locale is PT and the user is on the Verses tab
- WHEN the user taps the language icon
- THEN the locale switches to ES
- AND the verse list and categories re-render in Spanish

### Requirement: Contextual FAB

The system SHALL display a FAB only when the Verses tab is selected. On the Home tab the FAB MUST be hidden. The FAB SHALL open the verse creation form.

#### Scenario: FAB hidden on Home tab

- GIVEN the user is on the Home tab
- WHEN the HomeScreen renders
- THEN no FAB is visible

#### Scenario: FAB visible on Verses tab

- GIVEN the user switches to the Verses tab
- WHEN the HomeScreen renders
- THEN a FAB with add icon is visible

#### Scenario: FAB opens verse creation

- GIVEN the FAB is visible on the Verses tab
- WHEN the user taps the FAB
- THEN the verse creation form opens
- AND the verse list refreshes after returning from the form

### Requirement: Tab Switching via NavigationBar

The system SHALL provide a `NavigationBar` with Home and Verses destinations. Selecting a destination SHALL switch the displayed content in the `IndexedStack`.

#### Scenario: Switch to Verses tab

- GIVEN the user is on the Home tab
- WHEN the user taps the Verses destination
- THEN the verse list is displayed
- AND the AppBar title updates to the verse list title
- AND the FAB appears
- AND the Home tab content remains alive in the stack

#### Scenario: Switch to Home tab

- GIVEN the user is on the Verses tab
- WHEN the user taps the Home destination
- THEN the Home content is displayed
- AND the AppBar title updates to "Vers Reminder"
- AND the FAB disappears
- AND the Verses tab content remains alive in the stack
