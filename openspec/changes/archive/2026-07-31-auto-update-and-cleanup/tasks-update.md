# Tasks: PR 2 — Auto-update (auto-update-and-cleanup)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| File: `lib/models/update_check_result.dart` | ~45 lines |
| File: `lib/services/update_service.dart` | ~150 lines |
| File: `lib/screens/settings/settings_screen.dart` | ~+90 lines |
| File: `android/app/src/main/AndroidManifest.xml` | ~+12 lines |
| File: `android/app/src/main/res/xml/file_paths.xml` | ~4 lines |
| File: `lib/l10n/app_{en,es,pt}.arb` | ~+60 lines |
| File: `test/services/update_service_test.dart` | ~200 lines |
| Estimated total changed lines | ~560 (code+tests), core ~300 |
| 400-line budget risk | Medium (code-only under; with tests above) |
| Chained PRs recommended | No (PR 2 is the second of 2) |
| Suggested split | Single PR |
| Delivery strategy | exception-ok |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

> Note: code-only ~300 stays under 400; total edges to ~560 with tests. Tests are the bulk (download + comparator + widget). If budget is strict, tests can be a follow-up commit, but PR stays single.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Auto-update services + model + Android config | PR 2 | Base = main (after PR 1 merges). Depends on `UpdateCleanupService.updatesDir()`. |
| 2 | About UI + l10n + tests | PR 2 | Same PR; UI depends on services (unit 1). |

## Phase 1: Dependencies

- [x] 1.1 `pubspec.yaml` — add `http: ^1.6.0` + `android_intent_plus: ^6.1.0` under `dependencies`; run `flutter pub get`.

## Phase 2: Model + UpdateService

- [x] 2.1 `lib/models/update_check_result.dart` — class `UpdateCheckResult` with `available`, `tagName`, `downloadUrl`, `assetName`, `sizeBytes`, `error`; factories for no-update and error states; `GithubRelease` parse model for `tag_name` + `assets[]` arm64 `browser_download_url`.
- [x] 2.2 `lib/services/update_service.dart` — Singleton `UpdateService.instance`/`_internal()`; top-level pure `int compareVersions(String remoteTag, String localVersion, String localBuild)`: strips `v`, parses semver+build numerically, returns remote>local 1 / equal 0 / remote<local -1.
- [x] 2.3 `update_service.dart` — `Future<UpdateCheckResult> checkForUpdate({http.Client? client, String? versionOverride, String? buildOverride})`: GET `.../releases/latest`, parse tag+arm64 asset, compare against `package_info_plus` (or overrides); network error / malformed tag / missing asset → error state, NO throw; use URL exactly as given (no re-encode).
- [x] 2.4 `update_service.dart` — `Future<String> download(UpdateCheckResult release, {void Function(int bytes, int total)? onProgress})`: `UpdateCleanupService.instance.cleanUpdatesDir()` first (stale APKs), stream response to `{updatesDir}/{assetName}` reporting bytes/total (start/finish); on failure delete partial + rethrow; returns APK path.
- [x] 2.5 `update_service.dart` — `Future<bool> install(String apkPath, {String? releaseUrl})`: file exists check (else return false, no intent), `android_intent_plus` `AndroidIntent(action: 'action_view', data: 'content://{applicationId}.fileprovider/updates/{file}', type: 'application/vnd.android.package-archive', flags: [FLAG_GRANT_READ_URI_PERMISSION])`; `canResolveActivity()` false → browser fallback to release URL; launch throws → deep-link `MANAGE_UNKNOWN_APP_SOURCES`; returns whether intent fired.

## Phase 3: Android config

- [x] 3.1 `android/app/src/main/AndroidManifest.xml` — add `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>` above `<application>`.
- [x] 3.2 `AndroidManifest.xml` — inside `<application>` add `<provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.fileprovider" android:exported="false" android:grantUriPermissions="true">` + `<meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths"/>` (also add `<queries>` for browser fallback if Android 11+ visibility blocks `http://`).
- [x] 3.3 `android/app/src/main/res/xml/file_paths.xml` — `<files-path name="updates" path="updates/"/>`.

## Phase 4: UI — About update flow (settings_screen.dart)

- [x] 4.1 `_SettingsScreenState` — add `_UpdateCheckState` enum (idle/checking/available/downloading/installing) + `_UpdateCheckResult? _updateResult`; add `_checkForUpdate()`, `_downloadAndInstall()`, `_startInstall()` methods calling `UpdateService.instance`, guarded by `mounted`.
- [x] 4.2 About section — add "Check for updates" `ListTile` (above version tile) with subtitle "Update available: vX.Y.Z+N" when `available`; no auto-prompt on app start.
- [x] 4.3 Confirmation dialog (`_showUpdateConfirmDialog`) — "New version vX available. Download (≈size)? It preserves your wallpapers and settings" → Cancel/Download.
- [x] 4.4 Progress dialog — showDialog with `LinearProgressIndicator` driven by download `onProgress` callback (`updateDownloadProgress` message); cancelable.
- [x] 4.5 On download complete — close progress, show Install action → `UpdateService.instance.install(apkPath, releaseUrl: ...)`.
- [x] 4.6 Snackbars — `upToDate` when no update; `updateCheckFailed` (+ Retry) on network error; confirm install fired.

## Phase 5: Localization

- [x] 5.1 `lib/l10n/app_en.arb` — add keys `checkForUpdates`, `updateAvailable`, `downloadUpdate`, `installNow`, `upToDate`, `updateCheckFailed`, `downloadingUpdate`, `updateDownloadProgress` (with `%` placeholder), `updateVersion`, `updateSize`.
- [x] 5.2 Mirror same keys in `lib/l10n/app_es.arb` + `lib/l10n/app_pt.arb` (ES/PT translations).
- [x] 5.3 Run `flutter gen-l10n` to regenerate `lib/l10n/generated/app_localizations.dart`; verify no stale references.

## Phase 6: Tests

- [x] 6.1 `test/services/update_service_test.dart` — `compareVersions`: higher/equal/lower, `v` prefix strip, `+build` tiebreak numeric, same-version higher-build → update available.
- [x] 6.2 `update_service_test.dart` — `checkForUpdate` with `MockClient` + `versionOverride`/`buildOverride`: available / equal / lower / HTTP 500 / malformed `tag_name` / missing arm64 asset → correct result states, NO throw.
- [x] 6.3 `update_service_test.dart` — `download`: `MockClient` stream → file written to `appSupportOverride` updates dir; mid-transfer failure → partial file deleted.
- [x] 6.4 `update_service_test.dart` — `install`: missing APK → returns false without launching (no platform channel touched).
- [x] 6.5 Run `flutter test` — full suite passes (existing 99 + new).
- [x] 6.6 Run `flutter analyze` — clean, no new issues.

## Phase 7: Cleanup / Docs

- [x] 7.1 Update `openspec/changes/auto-update-and-cleanup/design-update.md` open questions: confirm `update-ux` spec (or link to `tasks-update.md` authoritative), resolve `<queries>` visibility on device.
- [x] 7.2 Note in `tasks-cleanup.md` references that `UpdateCleanupService` is now wired by PR 2 from startup note.
