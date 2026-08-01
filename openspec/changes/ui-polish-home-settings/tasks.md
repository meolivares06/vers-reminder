# Tasks: UI Polish — Home & Settings Screens

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~520–650 (additions + deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1: shared widgets + helper → PR2: Settings reorder/Restore/loaders → PR3: Home version/Share + tests |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Shared `async_action_button.dart` + `app_version.dart` + unit/widget tests | PR 1 | Autonomous; base = main |
| 2 | Settings: reorder, Restore tile, loaders ×3, dynamic version; drop `aboutVersion` + gen-l10n | PR 2 | Base = main; depends on PR 1 widgets |
| 3 | Home: dynamic version + Share tile + Change-now loader; test updates | PR 3 | Base = main; depends on PR 1 & PR 2 |

## Phase 1: Shared Foundation

- [x] 1.1 Create `lib/widgets/app_version.dart` — top-level `Future<String> resolveAppVersionString()` via `PackageInfo.fromPlatform()` returning `'v{version}+{buildNumber}'`; NO try/catch, errors propagate verbatim
- [x] 1.2 Create `lib/widgets/async_action_button.dart` — `enum AsyncActionButtonStyle { filled, elevated, text, tile }`; `StatefulWidget` owning `_busy`; `onPressed: Future<void> Function()`, `label`, `icon`, `style`, `enabled`
- [x] 1.3 In `AsyncActionButton`: on tap set `_busy=true`, render `CircularProgressIndicator` in label slot + `onPressed:null`; `try { await onPressed(); } finally { if (mounted) setState(_busy=false); }` — rethrow; NO catch/state-machine coupling
- [x] 1.4 Add `test/widgets/app_version_test.dart` — mock `dev.fluttercommunity.plus/package_info` channel asserting `v2.4.1+7` and that a throw propagates rethrown verbatim
- [x] 1.5 Add `test/widgets/async_action_button_test.dart` — completer-gated future: assert spinner + disabled while pending, restored afterward; result forwarded; error rethrown unchanged

## Phase 2: Settings Screen

- [x] 2.1 `settings_screen.dart` — delete `_loadVersion` + `package_info_plus` import; `initState` calls `resolveAppVersionString()` into `_appVersion` (try/catch → leave empty on error); About version tile renders `_appVersion` (drop `l10n.aboutVersion` fallback)
- [x] 2.2 Reorder ListView to wallpaper-first: mini-preview + alignment + background-source + offset + font params top, then Restore tile, then `Divider`→Scheduling, `Divider`→Categories, `Divider`→Actions, `Divider`→About
- [x] 2.3 Replace `TextButton.icon` Restore with `AsyncActionButton(style: tile, enabled: settings.hasBackup)` wrapping `_showRestoreDialog`; when `!hasBackup` render disabled tile (remove `SizedBox.shrink` branch)
- [x] 2.4 Replace "Change now" `ElevatedButton.icon` with `AsyncActionButton` (style filled) running the permission-check → `triggerNow` + snackbar handler
- [x] 2.5 Replace "Check for updates" `ListTile` with `AsyncActionButton(style: tile)` wrapping `_checkForUpdate` (keep confirm/download/install dialogs untouched)
- [x] 2.6 `app_en.arb` / `app_es.arb` / `app_pt.arb` — remove `aboutVersion` key from all 3; run `flutter gen-l10n` and remove stale accessor from generated output

## Phase 3: Home Screen

- [x] 3.1 `home_screen.dart` — `initState` calls `resolveAppVersionString()`; About version `ListTile` renders dynamic `v{ver}+{build}` (drop `l10n.aboutVersion`)
- [x] 3.2 Add Share `ListTile` in Home About reusing `l10n.aboutShare`, `onTap: Share.share(...github releases/latest...)` mirroring Settings
- [x] 3.3 Wrap Home "Change now" `FilledButton.icon` in `AsyncActionButton` (style filled) running permission-check + `triggerNow`

## Phase 4: Tests & Verification

- [x] 4.1 `test/widgets/settings_restore_test.dart` — update fake section + assertions to `AsyncActionButton`/`ListTile` tile: disabled+`onTap:null` when `!hasBackup`; clickable when backup exists
- [x] 4.2 `test/screens/settings_about_update_test.dart` — verify `scrollUntilVisible(find.text('Check for updates'))` still resolves after wallpaper-first reorder (About moved lower)
- [x] 4.3 Update order-sensitive Settings tests (e.g. `settings_about_update_test`, any section-order assertions) to wallpaper-first layout; add Change-now + Restore loader busy/disabled assertions
- [x] 4.4 Add/update Home test asserting dynamic version tile + Share tile present (mirror Settings share)
- [x] 4.5 Run `flutter analyze` — zero errors
- [x] 4.6 Run `flutter test` — full suite green (incl. `app_version_test`, `async_action_button_test`)
- [x] 4.7 Run `flutter gen-l10n` and grep to confirm `aboutVersion` absent from all artifacts
