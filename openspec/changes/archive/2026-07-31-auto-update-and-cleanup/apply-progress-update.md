# Apply Progress — PR 2: Auto-update (auto-update-and-cleanup)

**Mode**: Standard (strict_tdd: false)
**Batch**: PR 2 of 2 (single PR, size:exception accepted per orchestrator)
**applyState at start**: ready

## Phase 1: Dependencies

- [x] **1.1** `pubspec.yaml` — added `http: ^1.6.0` + `android_intent_plus: ^6.1.0` under `dependencies`; ran `flutter pub get` (resolved: android_intent_plus 6.1.0, http 1.6.0).

## Phase 2: Model + UpdateService

- [x] **2.1** `lib/models/update_check_result.dart` — `UpdateCheckResult` (`available`, `tagName`, `downloadUrl`, `assetName`, `sizeBytes`, `error`), `empty()`/`failure()` factories; `GithubRelease`/`GithubAsset` parse models (defensive, malformed fields → null/empty, never throw).
- [x] **2.2** `lib/services/update_service.dart` — Singleton `UpdateService.instance`/`_internal()`; top-level pure `compareVersions(...)`: strips `v`, splits `+build`, numeric semver then build tiebreak.
- [x] **2.3** `checkForUpdate({http.Client? client, String? versionOverride, String? buildOverride})` — GET `.../releases/latest`, parse tag + arm64 asset, compare, report available only when remote > local; network error / malformed tag / missing asset → failure state, never throws. Version/build resolved lazily via `PackageInfo.fromPlatform()` only when an override is absent (so tests passing both overrides never touch a platform channel).
- [x] **2.4** `download(release, {onProgress, client, appSupportOverride})` — `UpdateCleanupService.cleanUpdatesDir()` then `updatesDir()`, stream `http.Client.send()` response to `{updatesDir}/{assetName}` reporting bytes/total; on failure delete partial + rethrow; returns APK path. Uses the `downloadUrl` exactly as provided (no re-encode).
- [x] **2.5** `install(apkPath, {releaseUrl})` — file-exists guard (else false, no intent); `AndroidIntent` VIEW + `content://com.versreminder.vers_reminder.fileprovider/updates/{file}` + package-archive MIME + `FLAG_GRANT_READ_URI_PERMISSION`; `canResolveActivity()` false → browser fallback to release URL; launch throws → deep-link `MANAGE_UNKNOWN_APP_SOURCES`; returns whether an intent fired.

## Phase 3: Android config

- [x] **3.1** `AndroidManifest.xml` — `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>` above `<application>`.
- [x] **3.2** `AndroidManifest.xml` — `<provider>` FileProvider (`${applicationId}.fileprovider`, `exported=false`, `grantUriPermissions=true`) + `FILE_PROVIDER_PATHS` meta-data; added `<queries>` intent for `ACTION_VIEW` + `https` scheme (browser fallback visibility on Android 11+).
- [x] **3.3** `android/app/src/main/res/xml/file_paths.xml` — created `<files-path name="updates" path="updates/"/>`.

## Phase 4: UI — About update flow

- [x] **4.1** `_SettingsScreenState` — `_UpdateCheckState` enum (idle/checking/available/downloading/installing), `_updateResult`, `_downloadedApkPath`, `_downloadProgress`; `_checkForUpdate()`, `_downloadAndInstall()`, `_startInstall()`, `_showUpdateConfirmDialog`, `_showInstallAction`, `_formatSize`, `_displayVersion` — all `mounted`-guarded.
- [x] **4.2** About — "Check for updates" `ListTile` above version tile; subtitle `updateAvailable(version)` when available; no auto-prompt.
- [x] **4.3** Confirmation dialog — title `updateAvailable(version)`, content `downloadUpdateConfirm(version, size)`, Cancel/Download actions.
- [x] **4.4** Progress dialog — title `downloadingUpdate`, `LinearProgressIndicator` + `updateDownloadProgress(percent)`, `barrierDismissible: true`.
- [x] **4.5** On download complete — close progress, show Install action dialog (`downloadComplete` message + `installNow` → `_startInstall` → `UpdateService.install(apkPath, releaseUrl: ...)`).
- [x] **4.6** Snackbars — `upToDate` no-update; `updateCheckFailed` + Retry on error; install not-fired snackbar.

## Phase 5: Localization

- [x] **5.1** `app_en.arb` — added `checkForUpdates`, `updateAvailable`, `downloadUpdateConfirm`, `downloadUpdate`, `installNow`, `upToDate`, `updateCheckFailed`, `downloadingUpdate`, `updateDownloadProgress`, `downloadComplete` (with placeholder metadata).
- [x] **5.2** Mirrored in `app_es.arb` (Rioplatense) + `app_pt.arb`.
- [x] **5.3** `flutter gen-l10n` regenerated `lib/l10n/generated/app_localizations.dart`; methods present, no stale references.

## Phase 6: Tests

- [x] **6.1** `test/services/update_service_test.dart` — `compareVersions`: higher/equal/lower, `v` strip, `+build` tiebreak numeric, same-version higher-build → update.
- [x] **6.2** `checkForUpdate` with `MockClient` + overrides — available / equal / lower / HTTP 500 / malformed tag / malformed JSON / missing arm64 → states, no throw.
- [x] **6.3** `download` — `_StreamClient` (http.BaseClient) stream → file written to `appSupportOverride` updates dir; mid-stream error → partial deleted + rethrow.
- [x] **6.4** `install` — missing APK → returns false without platform channel.
- [x] **6.5** `flutter test` — 119 pass (99 pre-existing + 20 new).
- [x] **6.6** `flutter analyze` — no new issues (22 pre-existing only; 2 issues I introduced early — an unused `dart:typed_data` import and a `GithubAsset.downloadUrl` getter mix-up — were fixed).

## Phase 7: Cleanup / Docs

- [x] **7.1** `design-update.md` open questions updated — `update-ux` spec confirmed present and aligned; `<queries>` entry added for browser fallback, device verification deferred to verify phase.
- [x] **7.2** `tasks-cleanup.md` 2.1 note updated — `UpdateCleanupService` now wired via PR 2 `UpdateService.download()` (clean-update-dir before each download, updatesDir destination).

## Deviations

1. **`downloadUpdate` key added** — the brief's key list omitted a "Download" action button label, which the confirmation dialog needs; design-update listed `downloadUpdate`, so I added it (EN "Download", ES "Descargar", PT "Baixar").
2. **`downloadComplete` key added** — needed for the post-download Install action dialog content ("Download complete. Install the update now?"); not in the brief's list but required for a coherent UX.
3. **`updateDownloadProgress` in progress dialog** — used as the primary progress indicator message (shown under a `downloadingUpdate` title) per the brief.
4. **`GithubAsset` exposes `browserDownloadUrl`** (not `downloadUrl`) — the design's initial code sketch used `asset.downloadUrl`, but the model correctly uses the GitHub JSON key; resolved to `browserDownloadUrl` throughout.

## Issues

- **None blocking.** Pre-existing analyzer infos (`use_build_context_synchronously`, `unnecessary_underscores`, old test warnings) in unrelated files are left untouched. `flutter analyze` full run: 22 issues, all pre-existing. My settings additions introduced no new analyzer issues.
- Browser fallback `<queries>` visibility only truly verifiable on device — deferred to verify phase.

## Workload / PR Boundary

- Mode: single PR — size:exception accepted by orchestrator.
- Current work unit: entire PR 2 (auto-update).
- Boundary: all 7 phases of `tasks-update.md`; 21/21 tasks complete.
- Estimated review budget impact: ~590 code+tests (incl. Android XML + l10n), ~300 core Dart without tests.

---

# Test Completion Batch (2026-07-31) — post-verify runtime coverage

**Trigger**: `verify-report-update.md` FAIL verdict — 11 of 17 spec scenarios had no runtime test (all 6 `update-ux`, plus update-core/update-install: stale-APK clear, installer-available install, installer-not-resolvable fallback); design-planned `test/screens/settings_about_update_test.dart` never delivered.
**Mode**: Standard (strict_tdd: false). **Delivery**: exception-ok, PR 2 of 2. No new commits/branches.

## Changes

- [x] **T-1** `lib/services/update_service.dart` — minimal testability seam (production behavior unchanged): `@visibleForTesting abstract class IntentLauncher { bool canResolveActivity(); Future<bool> launch(); }` + `AndroidIntentLauncher`; `install()` gains `@visibleForTesting IntentLauncher Function(AndroidIntent)? intentLauncherFactory` (defaults `AndroidIntentLauncher.new`).
- [x] **T-2** `lib/screens/settings/settings_screen.dart` — `SettingsScreen({super.key, this.updateService})` with `@visibleForTesting final UpdateService? updateService`; state uses `late final _updateService = widget.updateService ?? UpdateService.instance` for check/download/install.
- [x] **T-3** `test/services/update_service_test.dart` — +5 tests: (1) stale APK pre-seeded in updates dir deleted before new download written; (2) `onProgress` start+finish bytes; (3) install fires system installer via `_FakeIntentLauncher` — asserts VIEW action, `content://com.versreminder.vers_reminder.fileprovider/updates/{fileName}`, MIME `application/vnd.android.package-archive`, `FLAG_GRANT_READ_URI_PERMISSION`; (4) install falls back to browser (VIEW, no MIME) when `canResolveActivity()` false; (5) bonus: deep-links `MANAGE_UNKNOWN_APP_SOURCES` when installer launch throws (returns false).
- [x] **T-4** `test/screens/settings_about_update_test.dart` — NEW, 7 widget tests against real `SettingsScreen` + `_FakeUpdateService implements UpdateService`, covering all 6 update-ux scenarios: (Sc.1) available → tile subtitle + confirm dialog with size text; (Sc.2a) Cancel dismisses, no download; (Sc.2b) Download → progress dialog (`downloadingUpdate` + `updateDownloadProgress(50)` + `LinearProgressIndicator`, barrier-dismissible); (Sc.3) download completes → Install action dialog; (Sc.4) Install fires `service.install(apkPath)` and closes dialog; (Sc.5) up-to-date → `upToDate` snackbar; (Sc.6) check failure → `updateCheckFailed` snackbar + Retry re-runs check (asserted via `checkCalls == 2`).
- [x] **T-5** Harness details — MultiProvider (SettingsProvider/LocaleProvider/VerseProvider), MaterialApp locale `en` + real AppLocalizations; package_info channel mocked (`getAll` → version 1.0.0, buildNumber 3) so `_loadVersion` never touches a real channel; `scrollUntilVisible` to About tile; `_FakeUpdateService` uses `Completer<String>` to freeze mid-download; download/install tests reuse existing `appSupportOverride` + `_StreamClient` patterns.

## Verification

- [x] **T-6** `flutter test` — **131/131 pass** (119 pre-existing + 12 new: 5 service + 7 widget).
- [x] **T-7** `flutter analyze` — **22 issues, all pre-existing (0 new)**; the `settings_screen.dart` infos at 295/601 predate this batch (seam edits add no async gaps or underscore params).

## Deviations (this batch)

1. **Injection seams for testability** — `install()` could NOT be exercised via channel mocking: `android_intent_plus` 6.1.0 hard-codes `LocalPlatform()` (off-Android `canResolveActivity()` always false, `launch()` a no-op). Added the `IntentLauncher` seam + `intentLauncherFactory` param (both `@visibleForTesting`). Production default path unchanged — this is additive, not a behavior change.
2. **`SettingsScreen` constructor param** — preferred over a separate widget test harness to test the real screen (l10n, dialogs, snackbars) rather than a wrapper; defaults to `UpdateService.instance` so production wiring is untouched.
3. **Widget test pump strategy** — `pumpAndSettle` never settles in `settings_about_update_test.dart` because the wallpaper mini-preview renders an indeterminate `CircularProgressIndicator` (ImageCacheService uninitialized in tests); used a `_pumpAndPause` helper (pump + fixed 300ms pump) instead.
4. **Bonus test (T-3 #5)** — unknown-app-sources deep-link path was untested; added at no cost while the fake launcher was in place.

## Issues

- **None blocking.** Package-info channel must be mocked in any widget test that pumps `SettingsScreen` (else `_loadVersion` throws MissingPluginException); noted for future tests, not a product bug.

## Workload / PR Boundary (this batch)

- Mode: single PR (size:exception already accepted) — test-only completion, ~0 production behavior change.
- Boundary: starts where PR 2 apply ended (119 passing) and ends with 131 passing + 0 new analyzer issues.
- Estimated review budget impact: +12 tests (~430 lines, mostly test code) + ~25 lines of `@visibleForTesting` seams.

## Browser fallback fix (2026-07-31) — verify WARNING #1

**Trigger**: `verify-report-update.md` WARNING — `install()`'s browser fallback probed `canResolveActivity()` and returned its result without calling `launch()`, so on a device with no installer the call reported success but opened nothing. Pre-existing since PR 2 apply; surfaced by the fallback test added in T-3.
**Mode**: Standard. **Scope**: surgical — browser fallback branch only + its test coverage. No commit, no branch.

- [x] **B-1** `lib/services/update_service.dart` — browser fallback now: probes `canResolveActivity()`; returns `false` when it does NOT resolve; on resolve calls `launch()` inside try/catch returning `true` on success and `false` on launch failure (mirrors the installer-launch branch style; `browserLauncher` held once so the factory is invoked once per intent). Doc comment updated: `false` now also covers "the browser fallback fails to launch". Nothing else in the file changed.
- [x] **B-2** `test/services/update_service_test.dart` — updated `install falls back to the browser...` to record launched intents via `onLaunch` and assert the browser VIEW intent (data = releaseUrl, type = null) is actually LAUNCHED with `fired == true` (resolve-order assertion unchanged: install intent probed first, then browser). Added `install returns false without launching when the browser fallback does not resolve either` (no resolve → `fired` false, nothing launched). Other tests untouched.
- [x] **B-3** `flutter test` — **132/132 pass** (131 + 1 new).
- [x] **B-4** `flutter analyze` — **22 issues, all pre-existing (0 new)**; none touch `update_service.dart` or `update_service_test.dart`.

**Deviations**: none — implementation matches the requested fix exactly.
**Issues**: none blocking. Resolves the `installer-not-resolvable` scenario from PARTIAL → COMPLIANT for the verify report follow-up.
