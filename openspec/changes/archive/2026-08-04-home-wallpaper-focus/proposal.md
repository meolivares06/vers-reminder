# Proposal: Home Wallpaper Focus Redesign

## Intent

The Home tab competes with its own controls. The wallpaper preview — the product's visual output — sits at a fixed 320px inside a ListView, dwarfed by a full-width button, a rotation switch, and a categories tile that duplicate Settings functionality. Users come to Home to SEE the wallpaper, not manage settings. This redesign makes the wallpaper the hero, restores visual breathing room, and moves the primary action to a thumb-accessible FAB.

## Scope

### In Scope
- Wallpaper card grows to 85-88% of visible screen height via `MediaQuery`, replacing fixed `SizedBox(height: 320)`.
- Gold circular FAB (`#EFB14D` / `onGoldAccent` `#2B1F0E`) replaces the full-width "Change now" button, reusing `_triggerNow` / `_showPermissionDialog`.
- Remove rotation `ListTile` (Switch) and categories `ListTile` from Home. Both remain in Settings.
- Verse → EB Garamond italic (`fontStyle: italic`). Citation → sans-serif uppercase with `letterSpacing` + drawn gold rule. Mirror both in `_resolveFontSize` measurement styles.
- Register `EBGaramond-Italic.ttf` under EB Garamond family with `style: italic` in `pubspec.yaml`.
- Remove `_formatMinutes` dead code; drop unused `AsyncActionButton` import.
- Remove unused l10n key `activeCategoriesCount` from ARBs.
- Delete `test/home_ux/categories_tile_test.dart`. Add assertions in home_screen tests that rotation + categories tiles are gone. Add generator tests for italic verse + uppercase citation.

### Out of Scope
- Verse-list search, chat-bubble overlay, settings restructuring.
- FAB animation, haptic feedback, or entrance transitions.

## Capabilities

### New Capabilities
None — all changes modify existing capabilities.

### Modified Capabilities
- `home-ux`: UX-HOME-002 primary action becomes gold circular FAB (card tap trigger retained). UX-HOME-003 categories tile removed from Home.
- `wallpaper-gen`: verse typography → EB Garamond italic; citation → sans-serif uppercase with gold rule. Measurement styles must mirror paint styles.

## Approach

**Layout**: Use `LayoutBuilder` / screen-fraction approach. Card height = `constraints.maxHeight * 0.85`. Scaffold FAB conditionally shows gold button on `_currentIndex == 0`, coexisting with add-verse FAB on tab 1.

**Typography**: Add `fontStyle: FontStyle.italic` to all 4 verse TextStyles in `WallpaperGenerator`. Citation styles get sans-serif family, `toUpperCase()`, `letterSpacing`, and a small gold `Rect` above the citation text on the canvas.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/screens/home_screen.dart` | Modified | Card height, gold FAB, remove rotation/categories tiles, dead code |
| `lib/services/wallpaper_generator.dart` | Modified | Verse italic, citation sans-serif uppercase + gold rule |
| `pubspec.yaml` | Modified | Register EBGaramond-Italic.ttf under EB Garamond family |
| `assets/fonts/EBGaramond-Italic.ttf` | New | Copied from temp prototype directory |
| `lib/l10n/app_*.arb` | Modified | Remove `activeCategoriesCount` |
| `test/home_ux/categories_tile_test.dart` | Removed | All tests assert removed tile |
| `test/services/wallpaper_generator_test.dart` | Modified | Add italic + sans-serif citation tests |
| `test/screens/home_screen_test.dart` | Modified | Assert rotation + categories tiles absent |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `_resolveFontSize` measurement vs paint drift (italic + uppercase change text metrics) | Medium | Mirror both style passes identically; add dimension regression tests |
| Italic font not bundled in test runner | Low | Use real font binding; fallback dimension check if face absent |
| FAB overlap with long-verse card at 88% height | Low | 88% cap leaves safe `bottomRight` FAB area |

## Rollback Plan

Revert `home_screen.dart` → restore ListView with 320px card + AsyncActionButton + rotation + categories tiles. Remove gold FAB condition. Revert `wallpaper_generator.dart` TextStyles → remove italic/sans-serif. Delete `EBGaramond-Italic.ttf` from `pubspec.yaml`. Restore `activeCategoriesCount` ARB key.

## Dependencies

- `EBGaramond-Italic.ttf` file confirmed at temp path (exploration validated).
- Settings already exposes rotation + categories — zero Settings changes needed.

## Success Criteria

- [ ] Wallpaper card fills 85-88% of visible screen height on Home tab
- [ ] Gold circular FAB triggers wallpaper change; coexists with add-verse FAB on tab 1
- [ ] Rotation and categories tiles absent from Home; available in Settings
- [ ] Generated wallpaper: EB Garamond italic verse, sans-serif uppercase citation with gold rule
- [ ] No dead code, unused imports, or unused l10n keys
- [ ] Existing tests pass; categories tile test removed; new typography tests present
