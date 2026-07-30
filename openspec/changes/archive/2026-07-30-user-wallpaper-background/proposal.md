# Proposal: User Wallpaper Background

## Intent

Let users choose their own device wallpaper as the background for verse composition, replacing the current nature-only source. When the device has no static wallpaper (live wallpaper detected), the option is hidden entirely with an explanation.

## Scope

### In Scope
- `useMyWallpaper` toggle in Appearance section: SegmentedButton with "App" (default) | "Mío"
- Read device wallpaper via `getWallpaper` MethodChannel before compositing
- Live wallpaper detection: hide SegmentedButton, show explanation text when unavailable
- Persist choice via SharedPreferences (`use_my_wallpaper`, default `false`)
- Pre-generation cache uses one wallpaper snapshot for all 5 wallpapers in a batch
- Preview in Settings reflects selected source; invalidate preview cache on toggle
- Runtime fallback to nature images + SnackBar if `getWallpaper` fails unexpectedly
- Localized strings for all new UI: ES, PT, EN

### Out of Scope
- Per-source overlay opacity adjustment (v2)
- Re-reading wallpaper between each pre-generated wallpaper in a batch
- Background preview thumbnail within the toggle
- Dynamic re-detection when system wallpaper changes mid-session

## Capabilities

### New Capabilities

None. All changes fit within existing capability domains.

### Modified Capabilities
- `wallpaper-gen`: Add `useMyWallpaper` bool parameter to `generateAndSetWallpaper()`, `_render()`, `renderPreview()`, and `preGenerateWallpapers()`. Swap background source (nature asset vs `getWallpaper` bytes). Add live-wallpaper detection helper. `_compositeCanvas()` requires zero changes — already accepts `backgroundBytes: Uint8List`.
- `wallpaper-scheduler`: Pass `useMyWallpaper` through pre-generation pipeline; call `getWallpaper` once per batch.
- `settings-ui`: Add "App" | "Mío" SegmentedButton in Appearance section. Probe `getWallpaper` on screen load — hide toggle and show `bg_live_wallpaper_disabled` when null. Invalidate preview cache on source toggle.
- `l10n-core`: Three new ARB keys: `bg_source_app`, `bg_source_mine`, `bg_live_wallpaper_disabled`.

## Approach

**Foreground MethodChannel + pre-generation cache.** `generateAndSetWallpaper()` calls `getWallpaper` MethodChannel when `useMyWallpaper == true` → raw bytes → `_compositeCanvas()` (zero changes needed). Scheduler calls `getWallpaper` once per pre-gen batch; all 5 wallpapers share the same snapshot for visual consistency.

**Live wallpaper guard.** On settings screen load, probe `getWallpaper`. If null → hide SegmentedButton, show localized explanation. If static wallpaper exists → show toggle. Runtime failures (permission denied mid-operation) fall back to nature images + SnackBar.

**Settings provider.** New `_useMyWallpaper` bool field, persisted in SharedPreferences under key `use_my_wallpaper`. Follows existing `_schedulerEnabled` pattern for getter/setter/persistence.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/providers/settings_provider.dart` | Modified | New `_useMyWallpaper` field, getter/setter, SharedPreferences key (~25 lines) |
| `lib/screens/settings/settings_screen.dart` | Modified | SegmentedButton in Appearance, live-wallpaper probe, preview invalidation (~35 lines) |
| `lib/services/wallpaper_generator.dart` | Modified | `useMyWallpaper` param to 5 methods, MethodChannel source swap (~50 lines) |
| `lib/l10n/app_{en,es,pt}.arb` | Modified | 3 new keys × 3 locales (~9 lines) |
| `test/services/wallpaper_generator_test.dart` | Modified | Mock MethodChannel for my-wallpaper path (~40 lines) |
| `test/providers/settings_provider_test.dart` | Modified | Persistence roundtrip (~15 lines) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| MethodChannel latency (200-500ms for bitmap allocate + PNG compress) | Medium | Async, non-blocking. Acceptable for foreground and scheduler batch operations. |
| Scheduler uses stale wallpaper snapshot across cycles | Low | Same limitation as nature images (don't change). Next pre-gen cycle refreshes. |
| `getWallpaper` permission denied at runtime | Low | Catch `PlatformException`, fall back to nature images + SnackBar warning. |
| Live wallpaper probe fails silently | Low | Treat null as live wallpaper → hide toggle. Conservative default protects UX. |

## Rollback Plan

Set `use_my_wallpaper` SharedPreferences default to `false`. All code paths fall through to nature images. Revert settings UI to remove SegmentedButton and live-wallpaper probe. No data migration needed — the key is new.

## Dependencies

- Existing `getWallpaper` MethodChannel (already implemented in Android platform code)
- `_compositeCanvas()` already accepts `backgroundBytes: Uint8List` — zero contract changes
- `SettingsProvider` pattern for SharedPreferences persistence (established by `_schedulerEnabled`)

## Success Criteria

- [ ] "App" | "Mío" SegmentedButton toggles wallpaper background source in real time
- [ ] Choice persists across app restarts via SharedPreferences
- [ ] Live wallpaper detected → SegmentedButton hidden, explanation text shown
- [ ] Pre-generation uses one wallpaper snapshot for all 5 wallpapers per batch
- [ ] Settings preview reflects selected source immediately on toggle
- [ ] All new strings localized in ES, PT, EN
- [ ] Runtime `getWallpaper` failure falls back to nature + SnackBar without crash
