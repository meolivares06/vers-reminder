# Proposal: UI Polish — Home & Settings Screens

## Intent

Stale/misleading UI on Home + Settings: home About shows hardcoded "Version 1.0.0" (`l10n.aboutVersion`) that never tracks releases; Change now / Check for updates / Restore give no inline blocking feedback; Settings is ordered by implementation (Scheduling first), not the wallpaper model; Restore reads as plain text; Home lacks Settings' Share action.

## Scope

### In Scope
1. **Dynamic version (home)** — extract shared `PackageInfo` version helper for BOTH Home About + Settings; drop stale `aboutVersion`.
2. **Reusable inline blocking loader** — shared widget (spinner + disabled while `Future` runs) for Change now (Home + Settings), Check for updates, Restore.
3. **Reorder Settings** — wallpaper preview + text first, then its params (font/alignment/offset/bg source), then Scheduling → Categories → Actions → About.
4. **Restore clickable tile** — promote to clickable tile inside wallpaper section; no-backup case hidden/disabled.
5. **Share action (home)** — Share tile in Home About mirroring Settings (GitHub releases/latest link).

### Out of Scope
- NOT extracting the full update state machine ("desacoplado" = reusable loader only).
- NOT changing update/trigger business logic.
- NOT adding a dependency (reuses `package_info_plus`, `share_plus`).
- NOT reworking calibration.

## Capabilities

### New Capabilities
- `shared-ui`: version helper + inline blocking loader widget.

### Modified Capabilities
- `settings-ui`: wallpaper-first order; Restore clickable tile; Change now / Check for updates blocked-with-spinner.
- `l10n-core`: remove `aboutVersion`, add strings.
- `home-navigation` (of active change `fix-duplicate-appbar`): Home About gains dynamic version tile + Share.

## Approach

Minimal, no new deps:
- `lib/widgets/app_version.dart`: helper returning `v{version}+{build}`; both screens consume it.
- `lib/widgets/async_action_button.dart`: runs `Future<void>`; spinner + disabled in-flight; forwards result/errors unchanged.
- Reorder Settings tree; group preview + params; Restore as backup-aware `ListTile`.
- Home About Share tile — copy Settings' share target (`Share.share(<releases/latest url>)`).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/screens/home_screen.dart` | Modified | Version tile + Share |
| `lib/screens/settings/settings_screen.dart` | Modified | Reorder, Restore tile, loader ×3 |
| `lib/widgets/app_version.dart` | New | Version helper |
| `lib/widgets/async_action_button.dart` | New | Inline blocking loader |
| `lib/l10n/app_{en,es,pt}.arb` | Modified | Drop `aboutVersion`, add strings |
| `test/screens/*` | Modified | Fix order/state assertions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Reorder breaks widget tests asserting order | Med | Update tests in-change |
| Loader alters wrapped-future semantics | Low | Forward results/errors verbatim; unit-test |
| Collide with active `fix-duplicate-appbar` on home_screen | Med | Coordinate before apply |

## Rollback Plan

Revert changed files to `HEAD` (self-contained; no data/schema migration). `openspec` syncs to main specs only after verify.

## Dependencies

None new. Reuses `package_info_plus`, `share_plus`, `UpdateService`.

## Success Criteria

- [ ] Home About shows real `v{version}+{build}` matching Settings
- [ ] `l10n.aboutVersion` gone; regenerated l10n
- [ ] Change / Check updates / Restore show spinner + disabled while running
- [ ] Settings order is wallpaper-first, then Scheduling/Categories/Actions/About
- [ ] Restore is a visible clickable tile in the wallpaper section
- [ ] Home About sharable
- [ ] `flutter analyze` clean; widget tests pass
