# Update UX

## Description

User-facing update flow in the About section of the settings screen: a manual "Check for updates" entry point, confirmation before download, progress feedback, and an install action — with no intrusive auto-prompting.

## Requirements

### Requirement: Update UX in About section

The system MUST add a "Check for updates" `ListTile` to the About section of the settings screen. When an update is available, the section MUST show the subtitle "Update available: vX.Y.Z+N" and an action/badge. The system MUST NOT auto-prompt on app start — the update check may run silently to surface a subtle indicator, but MUST NOT show an intrusive modal automatically.

On tap, the system MUST confirm with the user before any network use or download. Confirming the download MUST show a cancelable progress dialog with a `LinearProgressIndicator`. On successful download the system MUST present an Install action that triggers the install flow. On failure the system MUST show a dismissible error with Retry.

#### Scenario: Check finds an update available

- GIVEN the user taps "Check for updates"
- AND a newer version is available on GitHub
- THEN the subtitle shows "Update available: vX.Y.Z+N"
- AND a confirmation dialog appears offering Download / Cancel

#### Scenario: Confirming the download

- GIVEN the user confirms the download
- WHEN the download starts
- THEN a progress dialog with a `LinearProgressIndicator` is shown
- AND the dialog can be canceled

#### Scenario: Download completes

- GIVEN the download finishes successfully
- THEN the progress dialog closes
- AND an Install action is presented to the user

#### Scenario: Installing

- GIVEN the user taps Install after a completed download
- THEN the system install flow is triggered

#### Scenario: No update available

- GIVEN the user taps "Check for updates"
- AND the app is already on the latest version
- THEN a snackbar shows "You're up to date"
- AND no dialog is shown

#### Scenario: Check fails on network error

- GIVEN the user taps "Check for updates"
- AND the network request fails
- THEN a dismissible error is shown with a Retry action
- AND no crash occurs
