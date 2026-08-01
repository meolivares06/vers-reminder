# Archive Report: auto-update-and-cleanup

**Archived on**: 2026-07-31
**Artifact Store**: openspec
**Change**: auto-update-and-cleanup (PR 1 — Data Cleanup + PR 2 — Auto-update)

## Task Completion Gate

- `tasks-cleanup.md`: 7/7 tasks `[x]` ✅
- `tasks-update.md`: 26/26 tasks `[x]` ✅ (plus 7/7 batch tasks and 4/4 browser-fallback fix tasks in `apply-progress-update.md`)
- Verify reports: `verify-report-cleanup.md` and `verify-report-update.md` — both **PASS WITH WARNINGS**
- No CRITICAL issues in either report ✅
- No stale-checkbox reconciliation needed (no stale unchecked tasks)

## What Was Delivered

### PR 1 — Data Cleanup (cleanup-temp + cleanup-updates)
- `TempCleanupService` — singleton that sweeps `getTemporaryDirectory()` for `wallpaper_*.png` on app start, deleting all except the file referenced by `last_wallpaper_path`, with defensive per-file error handling and deleted-count logging
- `UpdateCleanupService` — singleton managing `{appSupport}/updates/`: creates the dir lazily, deletes stale `.apk` files before a new download, tolerates missing files
- Hook in `lib/main.dart` — fire-and-forget temp cleanup after screen-dim cache, before `runApp`
- Tests: 13 new unit tests (7 temp + 6 updates)

### PR 2 — Auto-update (update-core + update-install + update-ux)
- `UpdateService` — checks `https://api.github.com/repos/meolivares06/vers-reminder/releases/latest`, parses `tag_name` + arm64 asset, compares via pure `compareVersions()` (numeric semver + build), downloads the APK streamed with progress to the updates dir, and installs via `android_intent_plus`
- `UpdateCheckResult` + `GithubRelease` parse models
- Android config — `REQUEST_INSTALL_PACKAGES` permission, FileProvider `${applicationId}.fileprovider`, `res/xml/file_paths.xml` exposing the updates dir, `<queries>` for browser fallback visibility
- UX — "Check for updates" ListTile in About (no auto-prompt), confirmation dialog, cancelable `LinearProgressIndicator` progress dialog, Install action, up-to-date/error snackbars with Retry
- l10n — 10 new ARB keys in EN/ES/PT + regenerated localizations
- Tests — comparator, check/download/install service tests, 7 widget tests for the About flow; testability seams (`IntentLauncher` factory, `SettingsScreen.updateService`)

## Verification Evidence

- **132/132 tests pass** (full suite, exit 0) — PR 1 at 99/99, PR 2 at 132/132 after the browser-fallback fix
- **17/17 spec scenarios COMPLIANT** (update-core 8, update-install 3, update-ux 6) — the sole PARTIAL (`installer-not-resolvable`) was resolved by the browser-fallback fix
- PR 1 compliance: 9/10 scenarios fully compliant, 1/10 PARTIAL (`cleanup-updates` Sc.2 — behavior present via `cleanUpdatesDir()` APK sweep; design's dedicated `deleteFailedDownload(path)` API was not implemented, per tasks/signature decision)
- `flutter analyze` — 0 new issues (22 pre-existing, none touching change files)

## Known Warnings

1. **Device-only manual verification pending (design 7.1)** — real system-installer UI on Android 11+ (does the package-archive intent actually open the installer) and `<queries>` browser visibility for the fallback need a manual device check on the PR. Cannot be closed by unit/widget tests in this environment. Non-code, planned.
2. **Review budget note** — PR 2 ~590 lines + batch ~455 + fix ~15 vs the 400-line guard; orchestrator accepted `size:exception`. Informational; reviewers aware the diff is large.
3. **PR 1 accepted deviations** — blanket `catch (_)` instead of `on PathNotFoundException`; `String?` override params instead of `Directory?`; design interface `ensureUpdateDir()`/`cleanup()`/`deleteFailedDownload()` replaced by `updatesDir()` + `cleanUpdatesDir()` per tasks/signature decision. All documented in `apply-progress-cleanup.md` and the PR 1 verify report.

No CRITICAL issues in any report. Archive proceeds as a standard archive with warnings recorded above (intentional-with-warnings, no override text needed — warnings are non-blocking by policy).

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| cleanup-temp | Created (new main spec) | Temp wallpaper cleanup — 1 requirement, 5 scenarios |
| cleanup-updates | Created (new main spec) | Updates dir management — 1 requirement, 5 scenarios |
| update-core | Created (new main spec) | UpdateService version check + APK download — 2 requirements, 8 scenarios |
| update-install | Created (new main spec) | Install trigger via FileProvider and intent — 1 requirement, 3 scenarios |
| update-ux | Created (new main spec) | Update UX in About section — 1 requirement, 6 scenarios |

All five delta domains were NEW capabilities — no existing main spec was modified. New main specs were created from the deltas (converted from delta format to full spec format, matching the `calibration-ui` precedent from the 2026-07-29-wallpaper-live-preview archive). Requirements not mentioned in any delta were preserved (no other domains touched).

## Archive Contents

```
openspec/changes/archive/2026-07-31-auto-update-and-cleanup/
├── apply-progress-cleanup.md  ✅
├── apply-progress-update.md   ✅
├── design-cleanup.md          ✅
├── design-update.md           ✅
├── proposal.md                ✅
├── tasks-cleanup.md           ✅  (7/7 tasks complete)
├── tasks-update.md            ✅  (26/26 tasks complete)
├── verify-report-cleanup.md   ✅  (PASS WITH WARNINGS, 99/99 tests)
├── verify-report-update.md    ✅  (PASS WITH WARNINGS, 132/132 tests)
├── specs/
│   ├── cleanup/
│   │   ├── cleanup-temp/      ✅  spec.md
│   │   └── cleanup-updates/   ✅  spec.md
│   └── update/
│       ├── update-core/       ✅  spec.md
│       ├── update-install/    ✅  spec.md
│       └── update-ux/         ✅  spec.md
└── archive-report.md          ✅  (this file)
```

## Source of Truth Updated

| Main Spec | Status |
|-----------|--------|
| `openspec/specs/cleanup-temp/spec.md` | ✅ Created (new capability) |
| `openspec/specs/cleanup-updates/spec.md` | ✅ Created (new capability) |
| `openspec/specs/update-core/spec.md` | ✅ Created (new capability) |
| `openspec/specs/update-install/spec.md` | ✅ Created (new capability) |
| `openspec/specs/update-ux/spec.md` | ✅ Created (new capability) |

## Merge Notes

- All five delta specs were new capabilities → created as new main spec files (delta → full spec conversion: `# Delta for X` → `# X`, `## ADDED Requirements` → `## Requirements` under the Description header, requirements verbatim)
- No MODIFIED/REMOVED/RENAMED requirements — nothing existed to modify
- No destructive merges; no large section removals
- No other main spec domain was affected (grep confirmed no `update|cleanup|APK|install` requirement overlap)

## Intentional Archive Override

(None — standard archive with recorded non-blocking warnings.)

## Next Steps

1. **Manual device verification on the PR** — Android 11+ device: real system-installer UI for the downloaded APK, `MANAGE_UNKNOWN_APP_SOURCES` deep-link path, and browser-fallback visibility (design 7.1). Close the verify-report WARNING #1 once confirmed.
2. **Organize PR branches** — PR 1 (cleanup) and PR 2 (auto-update) branch/PR organization was deferred by apply; prepare and submit both PRs from the verified working tree (currently uncommitted).

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived. Ready for the next change.
