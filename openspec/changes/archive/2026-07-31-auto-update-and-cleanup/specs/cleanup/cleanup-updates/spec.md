# Delta for cleanup-updates

## ADDED Requirements

### Requirement: Updates dir management

**PR 1 — cleanup.** The system MUST maintain an `UpdateCleanupService` that manages a dedicated download directory at `{getApplicationSupportDirectory()}/updates/` for downloaded APK files. The service MUST be reusable by the auto-update flow (PR 2).

Before a new APK download begins, the system MUST delete any existing APK file already present in the updates dir, keeping only the in-flight download. On a download failure, the system MUST delete the partial file. All deletions MUST tolerate `PathNotFoundException` without propagating errors.

The system MUST NOT perform any version checking, network access, or install logic in this PR.

#### Scenario 1: Cleans old APKs before new download

- GIVEN the updates dir contains stale `v1.0.0-1.apk` and `v0.9.0-3.apk`
- WHEN a new download is prepared
- THEN both stale APK files are deleted before the new download starts
- AND only the in-flight download remains in the updates dir

#### Scenario 2: Cleans partial file on failed download

- GIVEN a download began and wrote a partial `{version}-{build}.apk` into the updates dir
- WHEN the download fails
- THEN the partial APK file is deleted from the updates dir

#### Scenario 3: Empty updates dir is a no-op

- GIVEN the updates dir exists but contains no files
- WHEN a download is prepared
- THEN no deletion occurs
- AND no error is raised

#### Scenario 4: File missing at delete time is tolerated

- GIVEN a defensive delete targets an APK path
- AND that path no longer exists at delete time
- WHEN the delete executes
- THEN the `PathNotFoundException` is caught and logged
- AND the service does not raise

#### Scenario 5: Updates dir absent is handled

- GIVEN the updates dir does not yet exist
- WHEN a download is prepared
- THEN the service creates the dir or treats its absence as a no-op
- AND no error is raised
