# Shared UI Specification

## Purpose

Reusable UI building blocks shared across screens: an app-version helper and an inline blocking loader for long-running actions. These widgets keep screens consistent and avoid per-screen duplication of loading and version logic.

## Requirements

### Requirement: App Version Helper

The system MUST provide a shared helper that resolves the installed app version and build number via `package_info_plus`, returning a display string in the format `v{version}+{build}`. Both the Home About section and the Settings About section SHALL consume this single helper. The helper MUST NOT return or render the previously hardcoded `l10n.aboutVersion` string.

#### Scenario: Resolves current version

- GIVEN the app is installed with version `2.4.1` and build `7`
- WHEN the Home or Settings About section loads
- THEN the version displayed SHALL be `v2.4.1+7`

#### Scenario: Package info unavailable

- GIVEN `PackageInfo.fromPlatform()` fails or returns no version
- WHEN the helper is called
- THEN the helper SHALL surface the error verbatim (no fallback to a hardcoded version string)

### Requirement: Inline Blocking Loader Button

The system SHALL provide a reusable button widget that runs an asynchronous action (`Future<void>`). While the future is in flight, the button SHALL be disabled and SHALL show an inline `CircularProgressIndicator` in place of its label. The wrapped future's result and errors SHALL be forwarded to the caller verbatim, with no transformation. The widget SHALL NOT be a modal and SHALL NOT coordinate with or trigger the update state machine.

#### Scenario: Shows spinner while action runs

- GIVEN the user taps the loader-backed button
- WHEN the wrapped future is in flight
- THEN the button SHALL be disabled
- AND an inline `CircularProgressIndicator` SHALL replace the label

#### Scenario: Forwards successful result

- GIVEN the wrapped future completes successfully
- WHEN the future resolves
- THEN the loader SHALL stop
- AND the future's value SHALL be returned to the caller unchanged

#### Scenario: Forwards error verbatim

- GIVEN the wrapped future throws an error
- WHEN the future rejects
- THEN the loader SHALL stop and re-enable the button
- AND the original error SHALL be rethrown to the caller unchanged
