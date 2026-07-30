# Delta for Settings UI

## ADDED Requirements

### Requirement: Restore Wallpaper Button

The Settings screen SHALL display a "Restore original wallpaper" button below the alignment section. The button SHALL be visible only when `hasBackup == true`. The button SHALL be accessible but not intrusive — a secondary-styled control (text button or outlined button).

#### Scenario: Button visible with backup

- GIVEN `hasBackup == true`
- WHEN the Settings screen renders
- THEN a restore button is visible below the alignment section

#### Scenario: Button hidden without backup

- GIVEN `hasBackup == false`
- WHEN the Settings screen renders
- THEN no restore button is displayed

### Requirement: Restore Confirmation Dialog

Before restoring, the system MUST show a confirmation dialog warning that the current wallpaper will be replaced.

#### Scenario: User confirms restore

- GIVEN the restore button is tapped
- WHEN the confirmation dialog appears and the user taps confirm
- THEN the backup is applied via `WallpaperBackupService.restore()`
- AND a success snackbar is displayed

#### Scenario: User cancels restore

- GIVEN the restore button is tapped
- WHEN the confirmation dialog appears and the user taps cancel or dismisses
- THEN no wallpaper change occurs

### Requirement: Restore Feedback

The system SHALL display a snackbar on restore success or failure using localized strings.

#### Scenario: Success snackbar

- GIVEN restore completes successfully
- WHEN the operation finishes
- THEN a snackbar displays the localized success message

#### Scenario: Failure snackbar

- GIVEN restore fails (missing file, platform error)
- WHEN the operation finishes
- THEN a snackbar displays the localized failure message
