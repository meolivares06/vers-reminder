# Proposal: Auto-update + Data Cleanup

## Intent
Add self-update capability (check GitHub Releases → confirm → download → install) and fix the unbounded temp-file leak in wallpaper generation, ensuring old APKs and stale temp files don't grow disk usage over time. All while preserving the user's configuration (DB, SharedPreferences, user background image, wallpaper backup).

## Why
- The app is distributed via GitHub Releases (no Play Store). Users currently must manually download and install each new APK.
- `WallpaperGenerator._render` writes `wallpaper_{millis}.png` to `getTemporaryDirectory()` on every foreground generation and NEVER cleans them up — confirmed leak (1–4 MB each, accumulates unbounded).
- Downloaded APKs would accumulate on disk unless cleaned.

## Approach (split into 2 PRs)

### PR 1 — Data cleanup (independent, smaller)
Fix the temp-file leak and prepare cleanup infrastructure:
1. Add `TempCleanupService` that sweeps `getTemporaryDirectory()` for `wallpaper_*.png`, deleting all except the one referenced by `last_wallpaper_path` in SharedPreferences
2. Add `UpdateCleanupService` (or fold into above) that manages a dedicated download dir and removes stale/previous APKs
3. Create helpers resilient to file-not-found (defensive delete)
4. Factored so both services can be reused by the update flow

### PR 2 — Auto-update (depends on PR 1)
1. Add `http` dependency; add `android_intent_plus` for install; keep a small `dio`-like progress with plain `http` (or add `dio` if progress needs are richer)
2. `UpdateService`: check `https://api.github.com/repos/meolivares06/vers-reminder/releases/latest`
   - Parse `tag_name`, compare against current `PackageInfo.version+buildNumber` (custom comparator handling `+build`)
   - Compare builds numerically; treat equal as "up to date"
3. Download the release APK (the arm64 asset) to `getApplicationSupportDirectory()/updates/{version}-{build}.apk`
4. Trigger install via `android_intent_plus` `ACTION_VIEW` + FileProvider on the APK
5. Add FileProvider to AndroidManifest + `res/xml/file_paths.xml` pointing at the updates dir
6. Add `REQUEST_INSTALL_PACKAGES` permission
7. UX: 
   - About section: "Check for updates" ListTile + auto subtitle when update available
   - Confirmation dialog with release info → Download → progress dialog → Install
   - Handle "Install unknown apps" launch when needed
8. Link usage: assign preflight for both PRs; estimate lines

## Semver/build comparison nuance
GitHub tags are `v1.0.0+3`. `package_info_plus` gives `version` ("1.0.0") + `buildNumber` ("3"). Compare semantic parts numerically; if equal, compare build ints. Only prompt when remote > local.

## Preserving config (CRITICAL)
APK update-in-place does NOT touch `/data/data/{pkg}` — DB, SharedPreferences, `user_background.png`, `wallpaper_backup/` all survive automatically. Cleanup only touches `cache/` temp dirs + the dedicated updates dir. NEVER delete:
- `verses.db` + sidecar
- SharedPreferences
- `user_background.png`
- `wallpaper_backup/original.png`
- the file at `last_wallpaper_path`

## Non-goals
- Auto-update without confirmation (user always confirms)
- Play Store distribution
- Wallpaper management UI (future feature, out of scope)
- Auto-cleanup of `nature_cache` (bounded, self-healing)

## Scope
- Modify: `pubspec.yaml`, `AndroidManifest.xml`, `build.gradle.kts` (already signed), add `res/xml/file_paths.xml`
- Add services: `TempCleanupService`, `UpdateService`
- Modify: `settings_screen.dart` (About UI), `main.dart` or `settings_provider.dart` (hook cleanup + update check)
- Tests for: cleanup service, version comparator, update check with mocked HTTP

## Estimated Review Workload
- PR 1 (cleanup): ~150–200 lines
- PR 2 (auto-update): ~350–450 lines
- Total exceeds 400 → split as decided
