# Delta for Home UX

## ADDED Requirements

### Requirement: Wallpaper Card Fraction-Height

The wallpaper card on Home SHALL fill 85-88% of visible vertical space, computed as a fraction of viewport height. The system MUST NOT use fixed-pixel sizing.

#### Scenario: Card fills majority of viewport

- GIVEN the user is on Home tab (index 0)
- WHEN the Home screen renders
- THEN the card height is between 85% and 88% of visible vertical space

#### Scenario: Empty state preserves fraction

- GIVEN no wallpaper exists
- WHEN the Home screen renders
- THEN the empty-state card occupies the same 85-88% height fraction

#### Scenario: Card does not push FAB off-screen

- GIVEN a wallpaper card at 88% height with a long-verse caption
- WHEN the Home screen renders
- THEN the gold circular FAB remains visible and tappable in its bottom-right position

### Requirement: Gold Circular FAB Primary Action

A gold circular FloatingActionButton SHALL be the primary wallpaper-change action on Home. The FAB MUST use `colorScheme.secondary` for its background. Tapping the FAB SHALL trigger the existing permission-gated generation flow. The FAB MUST NOT render on tab index 1.

#### Scenario: FAB triggers generation with permission granted

- GIVEN the user is on Home tab with storage permission granted
- WHEN the gold circular FAB is tapped
- THEN wallpaper generation starts

#### Scenario: FAB shows permission dialog when needed

- GIVEN the user is on Home tab without storage permission
- WHEN the gold circular FAB is tapped
- THEN the permission dialog appears
- AND generation proceeds only after permission is granted

#### Scenario: FAB absent on verse list tab

- GIVEN the user is on tab index 1 (verse list)
- WHEN the Scaffold renders
- THEN the gold FAB MUST NOT be visible
- AND the existing add-verse FAB SHALL render instead

## MODIFIED Requirements

### Requirement: UX-HOME-002 Activity Confined to Home Primary CTA

The primary "Change now" CTA SHALL be a gold circular FAB on Home. The wallpaper card SHALL remain tappable as a secondary affordance triggering the same generation flow. Settings MAY retain a contextual "Change now" action as secondary.
(Previously: primary action was a full-width AsyncActionButton rendered below the card)

#### Scenario: FAB is Home primary action

- GIVEN the user is on Home with a wallpaper present
- WHEN they tap the gold circular FAB
- THEN wallpaper generation starts from Home

#### Scenario: Card tap still triggers generation

- GIVEN a wallpaper exists on the Home card
- WHEN the user taps the wallpaper card
- THEN the same permission-gated generation flow is triggered

## REMOVED Requirements

### Requirement: UX-HOME-003 Localized Active-Categories Count

(Reason: categories tile moved from Home to Settings-only concern. Settings already manages categories via CheckboxListTile.)
(Migration: remove `activeCategoriesCount` l10n key from all ARB files. Delete `test/home_ux/categories_tile_test.dart`.)

### Requirement: Rotation Switch on Home Tab

(Reason: rotation toggle moved to Settings-only. Settings already exposes the auto-change SwitchListTile.)
(Migration: remove rotation ListTile and `_formatMinutes` dead code from home_screen.dart. Settings retains the toggle unchanged.)

### Requirement: l10n Key activeCategoriesCount

(Reason: unused after UX-HOME-003 removal from Home.)
(Migration: delete the key from `app_en.arb`, `app_es.arb`, `app_pt.arb`. Regenerate l10n files. No consumer remains.)
