## Verification Report

**Change**: auto-update-and-cleanup (PR 2 — Auto-update)
**Version**: N/A (delta specs: update-core, update-install, update-ux)
**Mode**: Standard (strict_tdd: false)
**Verdict**: **PASS WITH WARNINGS**
**Reason**: Re-verification after the Browser Fallback Fix (2026-07-31). The sole code warning from the previous report — `install()`'s browser fallback probed `canResolveActivity()` but never called `launch()` — is **RESOLVED**: the fallback now probes the browser, returns `false` when it does not resolve, and on resolve calls `launch()` inside try/catch returning `true` on success / `false` on launch failure. The `installer-not-resolvable` scenario flips from PARTIAL to **COMPLIANT** — the covering test now asserts the browser VIEW intent (data = releaseUrl, type = null) is actually LAUNCHED. Full suite: **132/132** (exit 0); `flutter analyze`: 22 issues, **0 new**. **17/17 spec scenarios COMPLIANT.** Remaining WARNING is the pre-existing device-only manual verification (design 7.1) — no code issues outstanding.

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 26 |
| Tasks complete | 26 |
| Tasks incomplete | 0 |

All 26 tasks in `tasks-update.md` are marked `[x]`; all 7 batch tasks (T-1…T-7) in the "Test Completion Batch" section of `apply-progress-update.md` are marked `[x]`; all 4 fix tasks (B-1…B-4) in the new "Browser fallback fix" section are marked `[x]`. No incomplete implementation task.

### Build & Tests Execution
**Build**: ✅ Passed
```text
flutter test → All 132 tests passed! (exit 0)
```

**Tests**: ✅ 132 passed / ❌ 0 failed / 0 skipped
```text
flutter test (full suite)
00:31 +132: All tests passed!
Breakdown: 131 pre-fix (119 pre-batch + 5 service + 7 widget) + 1 new (browser fallback does not resolve either)

flutter test test/services/update_service_test.dart --reporter expanded (install group)
install missing APK returns false without launching an intent                     → PASS
install fires the system installer when it resolves the intent (...)             → PASS
install falls back to the browser when no installer resolves the intent          → PASS
install returns false without launching when the browser fallback does not resolve either → PASS
install deep-links to unknown-app-sources when the installer launch fails        → PASS
```

**Coverage**: ➖ Not available (no coverage gate configured; unit + widget tests cover all 17 spec scenarios as listed below).

**Static Analysis**: ✅ No new issues (22 total, all pre-existing)
```text
flutter analyze → 22 issues found. (ran in 14.8s)
None of the 22 touch PR 2 files: update_service.dart, update_check_result.dart,
settings_about_update_test.dart, update_service_test.dart, ARB/generated l10n are
clean. The 3 settings_screen.dart infos (295:26 use_build_context_synchronously,
601:55/601:59 unnecessary_underscores) are the same pre-existing restore/background
patterns recorded in the previous report. The browser-fallback fix introduced no
new analyzer issues.
```

### Spec Compliance Matrix
| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| UpdateService version check | Remote version higher | `update_service_test.dart > checkForUpdate available: remote higher returns available with asset info` | ✅ COMPLIANT |
| UpdateService version check | Remote version equal | `... > checkForUpdate equal version returns no update` | ✅ COMPLIANT |
| UpdateService version check | Remote version lower | `... > checkForUpdate lower version returns no update` | ✅ COMPLIANT |
| UpdateService version check | Network error | `... > checkForUpdate network error (non-2xx) returns failure without throwing` | ✅ COMPLIANT |
| UpdateService version check | Malformed tag_name | `... > checkForUpdate malformed tag_name returns failure without throwing` (+ malformed JSON extra) | ✅ COMPLIANT |
| UpdateService APK download | Successful download | `... > download writes APK file to updates dir and reports progress` + `download reports progress via onProgress (start and finish)` | ✅ COMPLIANT |
| UpdateService APK download | Download failure mid-transfer | `... > download download failure mid-transfer deletes partial file and rethrows` | ✅ COMPLIANT |
| UpdateService APK download | Stale APKs cleared before download | `... > download stale APKs in the updates dir are cleared before the new download is written` | ✅ COMPLIANT |
| Install trigger via FileProvider & intent | APK present and installer available | `... > install fires the system installer when it resolves the intent (FileProvider URI + package-archive MIME)` | ✅ COMPLIANT |
| Install trigger via FileProvider & intent | Installer not resolvable | `... > install falls back to the browser when no installer resolves the intent` — asserts probe order (install intent first, browser second), `fired == true`, and that the browser VIEW intent is **actually launched** with `data == releaseUrl` and `type == null` | ✅ COMPLIANT ***(was ⚠️ PARTIAL — resolved: the fallback now calls `launch()` and the test asserts it)*** |
| Install trigger via FileProvider & intent | APK missing | `... > install missing APK returns false without launching an intent` | ✅ COMPLIANT |
| Update UX in About | Check finds an update available | `settings_about_update_test.dart > Sc.1 ...` | ✅ COMPLIANT |
| Update UX in About | Confirming the download | `... > Sc.2 cancel dismisses...` + `Sc.2 confirming download shows a cancelable progress dialog with a LinearProgressIndicator` | ✅ COMPLIANT |
| Update UX in About | Download completes | `... > Sc.3 download completes: progress closes, Install action shown` | ✅ COMPLIANT |
| Update UX in About | Installing | `... > Sc.4 installing fires the install flow with the downloaded APK` | ✅ COMPLIANT |
| Update UX in About | No update available | `... > Sc.5 no update available: up-to-date snackbar, no dialog` | ✅ COMPLIANT |
| Update UX in About | Check fails on network error | `... > Sc.6 check fails on network error: error snackbar with Retry` | ✅ COMPLIANT |

**Compliance summary**: **17/17 scenarios fully compliant** (was 16/17 + 1 PARTIAL). The `installer-not-resolvable` scenario is now COMPLIANT: its covering test passes and directly asserts the browser fallback launches the release page.

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Browser fallback launches the browser | ✅ Implemented | `install()` fallback branch (lines 244–251): `browserLauncher` held once (factory invoked once per intent); `canResolveActivity() != true` → `return false`; on resolve → `await browserLauncher.launch()` in try/catch → `true` on success, `false` on launch failure. Doc comment updated (`false` now also covers "the browser fallback fails to launch"). This is the only production change in the fix (B-1). |
| Resolver order preserved | ✅ Implemented | Install intent probed first (`launcherOf(installIntent).canResolveActivity()`), then browser (`browserLauncher.canResolveActivity()`), then launch. Asserted by the test's `resolved` probe-order expectation. |
| `compareVersions` pure function | ✅ Implemented | Unchanged; 10 unit tests. |
| `checkForUpdate` API + parse + compare | ✅ Implemented | Unchanged; 7 unit tests incl. malformed JSON + missing arm64 asset. |
| URL passed exactly, no re-encode | ✅ Implemented | Unchanged; `%2B`-encoded URL round-trip asserted. |
| `download` uses cleanUpdatesDir + updatesDir | ✅ Implemented | Unchanged; stale-APK-clear asserted inside `download()`. |
| `install` FILEProvider URI + fallbacks | ✅ Implemented | Installer path, missing-APK guard, browser fallback (now launching), deep-link all covered by 5 install tests. |
| AndroidManifest (permission + provider + queries) | ✅ Implemented | Unchanged. |
| `file_paths.xml` | ✅ Implemented | Unchanged. |
| settings_screen About update flow | ✅ Implemented | Tile/subtitle/confirm/progress/Install/snackbars asserted by the 7 widget tests. |
| No auto-prompt on startup | ✅ Implemented | Unchanged; update check reachable only via tile onTap (gated on `idle`). |
| ARB keys EN/ES/PT | ✅ Implemented | Unchanged. |
| Dependencies | ✅ Implemented | Unchanged (`http ^1.6.0`, `android_intent_plus ^6.1.0`). |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| #1 `http: ^1.6.0` direct dep | ✅ Yes | Unchanged. |
| #2 `android_intent_plus: ^6.1.0` | ✅ Yes | Unchanged. |
| #3 Singleton + injectable client/version | ✅ Yes | Unchanged; `install()` additionally gains injectable `intentLauncherFactory` (additive seam). |
| #4 Pure `compareVersions` | ✅ Yes | 10 unit tests. |
| #5 Local `_UpdateCheckState` + mounted-guarded setState | ✅ Yes | Unchanged. |
| #6 Dialog sequence per brief | ✅ Yes | Confirm → progress → Install action, exercised in Sc.1–Sc.4. |
| #7 Fire install first, deep-link on failure | ✅ Yes | Unchanged; deep-link covered by the bonus test. |
| #8 FileProvider `<files-path>` at `${appSupport}/updates` | ✅ Yes | Unchanged. |
| Data flow: `canResolveActivity()? launch : browser fallback` | ✅ Yes | The fix makes the fallback actually launch the browser, matching the designed data flow; a browser that does not resolve now returns `false` instead of reporting a phantom success. |
| Test seams preserve production behavior | ✅ Yes | `UpdateService.install()` defaults `intentLauncherFactory` to `AndroidIntentLauncher.new`; `SettingsScreen.updateService` defaults to `UpdateService.instance`. Both seams `@visibleForTesting`; no production call site passes them. Fix reuses the same seam — no new seams. |

### Issues Found

**CRITICAL**: None.

**WARNING**:
- ~~Browser fallback never launches~~ — **RESOLVED** (previous WARNING #1, closed by this fix). `install()`'s fallback now probes the browser, returns `false` when it does not resolve, and calls `launch()` on resolve (true on success, false on launch failure). Proven by two passing tests: the updated fallback test asserts the browser VIEW intent with the release URL is actually launched; the new no-resolve test asserts `fired == false` with nothing launched.
- Device-only verification still pending per design 7.1: real system-installer UI on Android 11+ (does the package-archive intent actually open the installer) and `<queries>` browser visibility for the fallback. Needs a manual device check on the PR — cannot be closed by unit/widget tests in this environment. Non-code, planned.
- Review budget: PR 2 ~590 lines + batch ~455 + fix ~15 (mostly tests) vs the 400-line guard; orchestrator accepted `size:exception`. No action needed; reviewers should be aware the diff is large.

**SUGGESTION**:
- The browser-fallback launch-failure sub-branch (catch → `false` inside the fallback's try/catch) is verified by source inspection only; a test where the browser resolves but `launch()` throws — mirroring the deep-link test for the installer branch — would lock it in. Not a spec scenario: `installer-not-resolvable` is fully covered by the launch assertion.
- Keep the bonus tests (malformed-JSON check failure; unknown-app-sources deep-link) — they cover failure paths beyond the spec.
- Document for future widget tests: any test pumping `SettingsScreen` must mock the `dev.fluttercommunity.plus/package_info` channel (else `_loadVersion` throws `MissingPluginException`) — recorded in apply-progress, not a product bug.

### Verdict
PASS WITH WARNINGS
The sole code warning is closed: the browser fallback now launches the release page and the `installer-not-resolvable` scenario is COMPLIANT, giving **17/17 scenarios with passing covering tests** — 132/132 tests (exit 0), `flutter analyze` 0 new issues (22 pre-existing), 26/26 tasks + 7 batch + 4 fix tasks complete, production behavior unchanged outside the fixed branch (installer path, deep-link, APK-missing guard, seams all intact and still green). The only remaining WARNING is the pre-existing device-only manual verification (design 7.1) and the informational budget note — no code issues outstanding.
