# Proposal: Wallpaper Source Toggle + Live Calibration Preview

## Intent

Users can't use their own wallpaper as compositing source, and calibration requires a tedious generate→apply→check→adjust loop. Fix both.

## Scope

**Phase A**: MethodChannel for reading wallpaper via WallpaperManager. `wallpaperSource` field in SettingsProvider. Pipeline source param. UI toggle + scheduler wiring. Tests.
**Phase B**: Extract `_composite()` → `Uint8List`. Add `renderPreview()` at ¼ res. Rewrite CalibrationScreen as StatefulWidget with `Image.memory()` + 300ms debounce. Widget tests.
**Out**: Nature asset removal. iOS. Live wallpaper edge cases (silent fallback). API < 28 (peekDrawable covers it).

## Capabilities

### New
- `wallpaper-read`: Read device wallpaper via custom MethodChannel. `getWallpaperFile()` (API 28+) → `peekDrawable()` fallback → PNG bytes. No new permissions.

### Modified
- `wallpaper-gen`: Add `wallpaperSource` param. Extract `_composite()`. Add `renderPreview()`.
- `wallpaper-scheduler`: R-WS-003 — pass `wallpaper_source` from SharedPreferences.
- `settings-ui`: New R-SU-009 — source toggle SwitchListTile + persistence.
- `l10n-core`: New ARB keys for source toggle strings.

## Approach

Phase A first (ships standalone): Kotlin MethodChannel + source param + scheduler + UI toggle. Then Phase B: extract `_composite()`, add preview path, rewrite CalibrationScreen. Shared compositing guarantees visual parity.

## Affected Areas

`MainActivity.kt` (channel), `wallpaper_generator.dart` (split+preview), `calibration_screen.dart` (rewrite), `settings_provider.dart` (source field), `settings_screen.dart` (toggle), `wallpaper_scheduler.dart` (pass param), `app_*.arb` (strings).

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Preview lags on slow devices | Med | 300ms debounce + ¼ res |
| Live wallpaper returns null | Med | Silent fallback to nature |
| 400-line budget exceeded | High | Two sequential PRs |

## Rollback Plan

**Phase A**: Remove channel, revert settings/scheduler. Key is inert at worst. **Phase B**: Restore old CalibrationScreen, revert `_render()`. Phase A preserved.

## Success Criteria

- [ ] Source toggle changes wallpaper generation source
- [ ] Scheduled changes respect source toggle
- [ ] Calibration preview updates ≤300ms after last slider move
- [ ] "Save" applies full-resolution wallpaper
- [ ] Read failure → graceful nature fallback + logged warning
- [ ] Existing wallpaper-gen tests pass unmodified
- [ ] No new package dependencies

---

## Proposal Question Round

1. **One PR or two?** ~10 files, 400-line budget. Two sequential PRs (Phase A → Phase B) or one combined?
2. **Preview resolution: fixed or configurable?** Fixed at ~¼ screen or user-controlled quality?
3. **Live wallpaper fallback UX:** Silent nature fallback, info banner, or disable+grey out the option?
