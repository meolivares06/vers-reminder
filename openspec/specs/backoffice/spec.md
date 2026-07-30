# Backoffice Specification

## Purpose

Provide screens for managing Bible verses and categories. Users can create, edit, delete, and browse verses grouped by category, create categories inline, and switch between ES and PT locales.

## Requirements

### Requirement: Verse List Grouped by Category

The system SHALL display verses organized by category header, sorted alphabetically by category name within the current locale. Empty categories SHALL NOT appear.

#### Scenario: Shows verses grouped

- GIVEN three verses exist in "Fe" and two in "Esperanza" for locale ES
- WHEN the user opens the backoffice list
- THEN the screen shows the "Esperanza" group first, then "Fe"
- AND each group contains its respective verses

#### Scenario: Hides group when empty

- GIVEN a category has no verses in the current locale
- WHEN the list is rendered
- THEN that category is not shown as a group

### Requirement: Verse Create/Edit Form

The system MUST provide a form to create and edit verses with fields: reference, text, book, and multi-category selection via chips. The form SHALL validate that at least one category is selected before saving. On edit, the form SHALL pre-populate all fields from the existing verse.

#### Scenario: Creates a verse with categories

- GIVEN the user fills reference, text, book, and selects two category chips
- WHEN they tap "Save"
- THEN the verse is persisted with the two categories
- AND the list updates to include the new verse

#### Scenario: Rejects save without categories

- GIVEN the user fills reference and text but selects no categories
- WHEN they tap "Save"
- THEN an error message "Select at least one category" is shown
- AND the verse is NOT saved

#### Scenario: Pre-populates edit form

- GIVEN the user taps edit on an existing verse with categories "Fe" and "Esperanza"
- WHEN the form opens
- THEN all fields show the existing values
- AND "Fe" and "Esperanza" chips are already selected

### Requirement: Inline Category Creation

The user MAY create a new category directly from the verse form without navigating to a separate screen. The new category SHALL appear in the selection chips immediately after creation.

#### Scenario: Creates category inline

- GIVEN the verse form is open with category chips displayed
- WHEN the user taps "Add category" and enters a new name
- THEN the new category is persisted
- AND the chip appears selected in the category list

### Requirement: Verse Deletion

The system MUST allow deleting a verse with a confirmation dialog. On confirmation, the verse and its category links SHALL be removed. On cancel, no change occurs.

#### Scenario: Deletes verse after confirmation

- GIVEN a verse exists and the user taps delete
- WHEN the user confirms in the dialog
- THEN the verse is removed from the database and the list

#### Scenario: Cancels deletion

- GIVEN a verse exists and the user taps delete
- WHEN the user cancels the dialog
- THEN the verse remains in the database and the list

### Requirement: Locale Resolution

The system SHALL delegate locale resolution to the l10n infrastructure (`l10n-core`). Backoffice screens MUST consume the active locale through `AppLocalizations` rather than managing locale state independently. Verse and category display SHALL react to locale changes propagated by `MaterialApp` rebuild.

#### Scenario: Displays in active locale

- GIVEN `l10n-core` resolves the locale to PT
- WHEN the backoffice list screen opens
- THEN verses and categories display in Portuguese

#### Scenario: Reacts to locale switch

- GIVEN the user changes locale from ES to PT while on the backoffice list
- WHEN the locale change propagates through `MaterialApp`
- THEN the verse list re-renders in PT

### Requirement: Localized Strings

All user-facing strings in backoffice screens MUST use `AppLocalizations` lookups. Hardcoded string literals SHALL NOT exist in backoffice screen files. This applies to: list headers, form labels, save buttons, error messages, confirmation dialogs, and category creation dialogs.

#### Scenario: Form buttons localized

- GIVEN the backoffice verse form is displayed with locale set to PT
- WHEN the form renders
- THEN the save button label reads the Portuguese equivalent
- AND category chip labels display in Portuguese

#### Scenario: Error messages localized

- GIVEN the user tries to save without selecting a category
- WHEN the locale is PT
- THEN the error message displays the Portuguese equivalent of "Select at least one category"

#### Scenario: Category creation dialog localized

- GIVEN the user taps "Add category" inline
- WHEN the locale is ES
- THEN the dialog title, hint text, and action buttons display in Spanish

#### Scenario: Confirmation dialog localized

- GIVEN the user taps delete on a verse
- WHEN the locale is PT
- THEN the confirm and cancel buttons display Portuguese labels
