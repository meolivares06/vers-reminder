# Design: PR 2 — Auto-update

## Technical Approach

Add self-update to About: `UpdateService` checks GitHub Releases (latest), compares against installed version via a pure comparator, downloads the arm64 APK to the PR 1 `updates/` dir (streamed, with progress), and fires an install intent via `android_intent_plus` + AndroidX FileProvider. UI is a local-state dialog sequence in `SettingsScreen` (already a `StatefulWidget`), no new provider.

Implements `update-core` and `update-install` specs. (`update-ux` spec absent — UX here follows the orchestrator brief; flag for sdd-spec.)

## Architecture Decisions

| # | Decision | Options / Tradeoff | Chosen |
|---|----------|--------------------|--------|
| 1 | HTTP client | `dio` (free progress, adds dep) vs plain `http` (already transitive 1.6.0, manual byte-stream + `contentLength`). One progress % is trivial to hand-roll. | `http: ^1.6.0` as direct dep |
| 2 | Install intent | `android_intent_plus ^6.1.0` (verified publisher, Dart 3 / AGP 8.13 OK) vs manual MethodChannel (more native code). Plugin has `AndroidIntent(action, flags, data, type)` + `canResolveActivity()`. | `android_intent_plus: ^6.1.0` |
| 3 | Service shape | Singleton `instance` matches existing services; injectable `http.Client` + version override for tests. | Singleton + injection |
| 4 | Version compare | Pure top-level `compareVersions(remoteTag, localVersion, localBuild)` — strips `v`, numeric semver then build. Pure = trivially unit-tested. | Pure function in `update_service.dart` |
| 5 | UI state | Provider vs local field. Flow is dialog/progress-transient; screen already stateful. `ChangeNotifier` adds wiring for no benefit. | Local `_UpdateCheckState enum` + `setState` guarded `mounted` |
| 6 | UX sequence | Separate tiles vs dialog. Mirrors `_showRestoreDialog`. | Dialog sequence per brief |
| 7 | "Install unknown apps" | Pre-guess vs fire-then-fail. Deep-link `MANAGE_UNKNOWN_APP_SOURCES` only after install fails (spec: no pre-guessing). | Fire first, deep-link on failure |
| 8 | FileProvider path | `{appSupport}/updates` = `/data/data/{pkg}/files/` → `<files-path name="updates" path="updates/"/>`, authority `${applicationId}.fileprovider`. APK update never touches `/data/data`. | `<files-path>` in `file_paths.xml` |

## Data Flow

```
About "Check for updates" tap
  └─ UpdateService.instance.checkForUpdate()            // injectable http.Client
      ├─ GET .../releases/latest → parse arm64 APK asset
      └─ compareVersions(tag, version, build) → UpdateCheckResult
  ├─ none → SnackBar upToDate
  ├─ error → SnackBar updateCheckFailed
  └─ available → AlertDialog (tag + size) → confirm
      └─ download(release, onProgress)
          ├─ cleanUpdatesDir() → updatesDir()            // stale APKs first
          ├─ stream response → {updatesDir}/{assetName}  // onProgress → setState %
          │    └─ failure → deleteFailedDownload(path)
          └─ progress dialog swaps to "Install"
              └─ install(apkPath)
                  ├─ File exists? else return failure (no intent)
                  ├─ ACTION_VIEW + FileProvider + package-archive MIME
                  │   + GRANT_READ_URI_PERMISSION
                  ├─ canResolveActivity()? launch : browser fallback
                  └─ launch throws → deep-link MANAGE_UNKNOWN_APP_SOURCES
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/update_service.dart` | Create | Singleton; `checkForUpdate`, `download`, `install`; top-level `compareVersions` |
| `lib/models/update_check_result.dart` | Create | Result model (`available`, `tagName`, `downloadUrl`, `assetName`, `sizeBytes`, `error`) + `GithubRelease` parse model |
| `lib/screens/settings/settings_screen.dart` | Modify | About: "Check for updates" ListTile, confirmation dialog, progress dialog, install + snackbars, `_UpdateCheckState` |
| `android/app/src/main/AndroidManifest.xml` | Modify | `REQUEST_INSTALL_PACKAGES` + FileProvider `<provider>` block |
| `android/app/src/main/res/xml/file_paths.xml` | Create | `<files-path name="updates" path="updates/"/>` |
| `lib/l10n/app_en.arb` + `app_es` + `app_pt` | Modify | `checkForUpdates`, `updateAvailable`, `downloadUpdate`, `installing`, `upToDate`, `updateCheckFailed`, `updateDownloadProgress`, `installNow`, `updateVersion`, `updateSize` |
| `pubspec.yaml` | Modify | Add `http: ^1.6.0`, `android_intent_plus: ^6.1.0` |
| `test/services/update_service_test.dart` | Create | Comparator + check/download with `MockClient` |
| `test/screens/settings_about_update_test.dart` | Create | Widget test: tile, confirm dialog, progress, install trigger (injectable service) |

## Interfaces / Contracts

```dart
// Pure — export for tests.
int compareVersions(String remoteTag, String localVersion, String localBuild);

class UpdateCheckResult {
  final bool available; final String? tagName;
  final String? downloadUrl; final String? assetName;
  final int? sizeBytes; final String? error;
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  Future<UpdateCheckResult> checkForUpdate({http.Client? client,
      String? versionOverride, String? buildOverride});
  Future<String> download(UpdateCheckResult r, {void Function(int b, int t)? onProgress});
  Future<bool> install(String apkPath, {String? releaseUrl});
}
```

`android_intent_plus` install intent (confirmed v6.1.0 API): `AndroidIntent(action: 'action_view', data: 'content://com.versreminder.vers_reminder.fileprovider/updates/{file}', type: 'application/vnd.android.package-archive', flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION])` → `.canResolveActivity()` → `.launch()`. Fallback browser: `action_view` with data = release URL. Unknown-apps: `action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES'`.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | `compareVersions` | remote higher/lower/equal, `v` prefix, build tiebreak, same-version+higher-build |
| Unit | `checkForUpdate` | `MockClient`: available / equal / lower / 500 / malformed tag / no arm64 asset — result states, no throws |
| Unit | `download` | `MockClient` stream → file written; mid-transfer failure → partial deleted |
| Unit | `install` | missing APK → failure without launch |
| Widget | About UI | stub service → tile, confirm dialog, progress → Install, install calls service |

Download/install use `appSupportOverride` + `MockClient` — no platform channels, matches `update_cleanup_service_test.dart`.

## Migration / Rollout

None for user data. Explicit check (no auto-prompt). First install needs one-time "Install unknown apps" grant, surfaced via failure deep-link only when needed.

## Open Questions

- `update-ux` spec is present (`openspec/changes/auto-update-and-cleanup/specs/update/update-ux/spec.md`) — the dialog sequence in sdd-apply matches the brief and that spec; `tasks-update.md` is authoritative for behavior.
- Browser-fallback `<queries>` visibility on Android 11+: a `<queries>` intent for `android.intent.action.VIEW` with `https` scheme was added to `AndroidManifest.xml` so `canResolveActivity()` can see browsers; the system package installer (`vnd.android.package-archive`) is always visible. Final verification happens on device during verify.
