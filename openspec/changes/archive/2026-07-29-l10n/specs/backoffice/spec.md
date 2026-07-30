# Delta for Backoffice

## MODIFIED Requirements

### Requirement: Locale Resolution

The system SHALL delegate locale resolution to the l10n infrastructure (`l10n-core`). Backoffice screens MUST consume the active locale through `AppLocalizations` rather than managing locale state independently. Verse and category display SHALL react to locale changes propagated by `MaterialApp` rebuild.
(Previously: backoffice owned its own locale detection and override logic)

#### Scenario: Displays in active locale

- GIVEN `l10n-core` resolves the locale to PT
- WHEN the backoffice list screen opens
- THEN verses and categories display in Portuguese

#### Scenario: Reacts to locale switch

- GIVEN the user changes locale from ES to PT while on the backoffice list
- WHEN the locale change propagates through `MaterialApp`
- THEN the verse list re-renders in PT

## ADDED Requirements

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
