# Delta for update-core

## ADDED Requirements

### Requirement: UpdateService version check

**PR 2 — auto-update.** The system MUST provide an `UpdateService` that checks for a newer release by calling `https://api.github.com/repos/meolivares06/vers-reminder/releases/latest`.

The system MUST parse the response `tag_name` (e.g. `v1.0.0+3`) and compare it against the current `PackageInfo.version` + `buildNumber` using a custom comparator: semantic version parts compared numerically; if the version is equal, build numbers compared numerically. The system MUST report an update available only when remote > local.

The system MUST treat network errors, malformed `tag_name`, and missing asset info as a failure state (no update) WITHOUT raising or crashing.

#### Scenario: Remote version higher

- GIVEN current version is `1.0.0+3`
- AND the GitHub API returns `tag_name: "v1.2.0+1"` with an arm64 APK `browser_download_url`
- WHEN the version check runs
- THEN the check returns "update available"
- AND returns the remote tag, APK asset name, and download URL

#### Scenario: Remote version equal

- GIVEN current version is `1.0.0+3`
- AND the GitHub API returns `tag_name: "v1.0.0+3"`
- WHEN the version check runs
- THEN the check returns "no update"

#### Scenario: Remote version lower

- GIVEN current version is `1.0.0+3`
- AND the GitHub API returns `tag_name: "v0.9.0+5"`
- WHEN the version check runs
- THEN the check returns "no update"

#### Scenario: Network error

- GIVEN the GitHub API is unreachable or returns a non-2xx status
- WHEN the version check runs
- THEN the check returns a failure state
- AND no exception escapes to the caller

#### Scenario: Malformed tag_name

- GIVEN the GitHub API returns `tag_name: "latest"` (no version parts)
- WHEN the version check runs
- THEN the check returns a failure state
- AND no exception escapes to the caller

### Requirement: UpdateService APK download

**PR 2 — auto-update.** When an update is confirmed, the system MUST download the arm64 APK asset to `{updatesDir}/{safeFileName}` using the `browser_download_url` from the release JSON. The system MUST use the URL exactly as provided — already URL-encoded (e.g. `%2B` for `+`) — and MUST NOT re-encode it.

The system MUST download via the `http` package with byte/stream download, reporting at least start/finish and progress when feasible. The download MUST clear stale APKs first via `UpdateCleanupService.updatesDir()`/clean. The system MUST write the file into the updates dir; on failure the system MUST delete the partial file and return a failure state.

#### Scenario: Successful download

- GIVEN an update is confirmed and the release JSON provides an arm64 asset URL
- WHEN the download completes
- THEN the APK file exists in the updates dir
- AND start/finish are reported (progress reported if streamed)

#### Scenario: Download failure mid-transfer

- GIVEN the download starts and writes a partial file
- WHEN the connection fails before completion
- THEN the partial APK file is deleted from the updates dir
- AND a failure state is returned

#### Scenario: Stale APKs cleared before download

- GIVEN the updates dir contains a previous version's APK
- WHEN a new download begins
- THEN the stale APK is removed before the new file is written
- AND only the in-flight download remains in the updates dir
