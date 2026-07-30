# Design: User Wallpaper Background

## Technical Approach

Route background sourcing through a single private helper `_getBackgroundBytes({required bool useMyWallpaper})` in `WallpaperGenerator`. When `useMyWallpaper` is `true`, call `getWallpaper` MethodChannel; when `false`, use `ImageCacheService.getNextRandomImage()` (existing path). All four call sites (`generateAndSetWallpaper`, `_render`, `renderPreview`, `preGenerateWallpapers`) swap to this helper — `_compositeCanvas` requires zero changes. A `bool _useMyWallpaper` field in `SettingsProvider` persists to SharedPreferences key `use_my_wallpaper`, following the existing `_schedulerEnabled` pattern. A `SegmentedButton<bool>` ("App" | "Mío") in the Appearance section of SettingsScreen controls the toggle. Live wallpaper is detected once on screen load via `getWallpaper` probe; if null, the SegmentedButton is hidden and explanation text shown.

## Architecture Decisions

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| Background source routing | if/else in 4-5 methods vs single private helper | Private `_getBackgroundBytes()` | Single point of change; avoids duplicated MethodChannel calls and fallback logic across methods |
| Toggle UI control | Switch vs SegmentedButton | SegmentedButton | Follows existing alignment SegmentedButton pattern — consistent UX; extensible to 3+ sources |
| Live wallpaper detection timing | Probe on every generation vs probe once on Settings load | Probe once in `initState` | Tradeoff: stale if user changes system wallpaper mid-session, but live wallpapers are persistent choices; avoids per-generation overhead |
| Pre-gen background snapshot | Read per wallpaper vs read once per batch | One `getWallpaper` call per batch | Spec requirement: consistent background across all 5 pre-generated wallpapers in a batch |
| SnackBar on runtime fallback | Fire from WallpaperGenerator vs SettingsProvider | SettingsProvider via status payload | `generateAndSetWallpaper` returns a `WallpaperResult`; runtime fallback is communicated transparently — no new return variant needed |

## Data Flow

```
SettingsProvider           WallpaperGenerator            Android Platform
     │                           │                            │
     ├─ useMyWallpaper: true     │                            │
     │   └─ triggerNow() ──────► generateAndSetWallpaper()    │
     │                           │                            │
     │                           ├─ _getBackgroundBytes(true) │
     │                           │   └─ MethodChannel ──────► getWallpaper
     │                           │      ◄────── Uint8List ────┘
     │                           │                            │
     │                           ├─ _compositeCanvas(bytes)   │
     │                           │   (zero changes)           │
     │                           │                            │
     │                           └─ _setWallpaper(path) ────► wallpaper_manager
     │                                                            │
     ├─ _preGenerateFutureWallpapers() ──► preGenerateWallpapers()
     │                                       └─ _getBackgroundBytes(true) × 1
     │                                          (reused for all 5 wallpapers)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Modify | Add `_getBackgroundBytes()` helper; add `useMyWallpaper` param to `generateAndSetWallpaper`, `_render`, `renderOnly`, `renderPreview`, `preGenerateWallpapers`; wire calls through helper (~40 lines) |
| `lib/providers/settings_provider.dart` | Modify | Add `_useMyWallpaper` field, getter, setter with SharedPreferences persistence; pass to `triggerNow()` and `_preGenerateFutureWallpapers()` (~25 lines) |
| `lib/screens/settings/settings_screen.dart` | Modify | Add live-wallpaper probe in `initState`; add `SegmentedButton<bool>` below alignment control; invalidate `_previewImagePath` on toggle; show `liveWallpaperNotSupported` text when blocked (~35 lines) |
| `lib/l10n/app_en.arb` | Modify | Add 5 keys: `backgroundSourceLabel`, `backgroundSourceApp`, `backgroundSourceMine`, `liveWallpaperNotSupported`, `fallbackToNature` |
| `lib/l10n/app_es.arb` | Modify | Add translated values for 5 keys |
| `lib/l10n/app_pt.arb` | Modify | Add translated values for 5 keys |
| `test/services/wallpaper_generator_test.dart` | Modify | Mock MethodChannel for `useMyWallpaper: true` path; test fallback to nature on null/PlatformException (~40 lines) |
| `test/providers/settings_provider_test.dart` | Modify | Test SharedPreferences persistence roundtrip for `use_my_wallpaper` key (~15 lines) |

## Interfaces / Contracts

```dart
// New private helper in WallpaperGenerator
Future<Uint8List?> _getBackgroundBytes({required bool useMyWallpaper}) async {
  if (!useMyWallpaper) {
    final path = await ImageCacheService.instance.getNextRandomImage();
    if (path == null) return null;
    return await File(path).readAsBytes();
  }
  const channel = MethodChannel('vers_reminder/wallpaper');
  try {
    final bytes = await channel.invokeMethod<Uint8List>('getWallpaper');
    return bytes;
  } catch (_) {
    return null; // live wallpaper or PlatformException
  }
}

// New parameter on existing signatures
//  generateAndSetWallpaper({..., bool useMyWallpaper = false})
//  _render({..., required bool useMyWallpaper})
//  renderOnly({..., bool useMyWallpaper = false})
//  renderPreview({..., bool useMyWallpaper = false})
//  preGenerateWallpapers({..., bool useMyWallpaper = false})
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | WallpaperGenerator `_getBackgroundBytes` fallback | Mock MethodChannel returning null / throwing `PlatformException`; assert nature fallback |
| Unit | WallpaperGenerator with `useMyWallpaper: true` | Mock MethodChannel returning valid `Uint8List`; assert bytes passed to `_compositeCanvas` |
| Unit | SettingsProvider `use_my_wallpaper` persistence | Set `true`, reload provider, assert getter returns `true` |
| Widget | SettingsScreen toggle visibility | Probe live wallpaper via mock channel → `null`; assert SegmentedButton absent, explanation text present |
| Widget | SettingsScreen preview invalidation | Toggle source, assert `_previewImagePath` cleared and new preview generated |

## Migration / Rollout

No migration required. The `use_my_wallpaper` SharedPreferences key is new — absent on existing installs defaults to `false` (nature images). Rollback: delete the key or ship with default `false` to restore existing behavior.

## Open Questions

None. All design decisions are resolved.
