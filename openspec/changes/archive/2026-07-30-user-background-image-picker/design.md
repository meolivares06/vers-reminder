# Design: User Background via Image Picker

## Technical Approach

Replace the broken `getWallpaper` MethodChannel (blocked on API 33+) with `image_picker`. When the user selects "Mío" in the SegmentedButton, the app opens the gallery. The picked image is saved to `{appDocDir}/user_background.png`; its path is stored in SharedPreferences (`user_background_path`). `_getBackgroundBytes(useMyWallpaper: true)` reads from that file instead of calling the MethodChannel. The live wallpaper probe (`_probeWallpaper`, `_wallpaperProbeOk`) is removed entirely — the toggle is always visible. `getWallpaper` is removed from `MainActivity.kt`; `suggestDesiredDimensions` stays. The backup service (`WallpaperBackupService.backupCurrent()`) keeps its `getWallpaper` call but fails gracefully on API 33+ (unchanged behavior).

## Architecture Decisions

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| Image source | MethodChannel vs image_picker vs both | image_picker | MethodChannel blocked on API 33+. image_picker works everywhere, no permission needed |
| When to open picker | Auto on toggle vs explicit button | Auto-open when no image stored | Fewer taps; user expects immediate action when selecting "Mío" |
| Storage location | App docs dir (`user_background.png`) vs SharedPreferences bytes | `user_background.png` | Large images in prefs are wasteful; file is efficient, path in prefs |
| Cancel behavior | Keep "Mío" with no image vs revert to "App" | Revert to "App" | No generation without a valid background |
| File format | PNG vs JPEG | PNG | Lossless; image reused many times across pre-generation |
| `getWallpaper` channel handler | Keep for backup vs remove | Remove from channel | No longer called by main flow; backup fails gracefully |
| Live wallpaper probe | Keep vs remove | Remove | No `getWallpaper` → no probe needed. Toggle always visible |

## Data Flow

```
User taps "Mío" in SegmentedButton
  │
  ├─ user_background.png exists?
  │   ├─ Yes → show thumbnail + "Replace" button
  │   └─ No  → open ImagePicker.gallery
  │              ├─ User picks photo → save to user_background.png
  │              │   └─ triggerNow() / preview reads from file
  │              └─ User cancels → revert to "App"
  │
  ├─ triggerNow() / renderPreview():
  │   └─ _getBackgroundBytes(useMyWallpaper: true)
  │       └─ File(user_background.png).readAsBytes() → _compositeCanvas()
  │
  └─ preGenerateWallpapers():
      └─ _getBackgroundBytes(true) → bytes reused for all 5 PNGs
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `pubspec.yaml` | Modify | Add `image_picker: ^1.0.0` dependency |
| `lib/services/wallpaper_generator.dart` | Modify | `_getBackgroundBytes(true)` reads `user_background.png` via `SettingsProvider.userBackgroundPath` from SharedPreferences. Remove `lastGenerationHadFallback` static, `import services.dart`. |
| `lib/providers/settings_provider.dart` | Modify | Add `_userBackgroundPath` + getter + `setUserBackgroundPath()`. Remove `lastFallback` getter. |
| `lib/screens/settings/settings_screen.dart` | Modify | Remove `_probeWallpaper()`, `_wallpaperProbeOk`, and the probe-gated branches. Add image picker auto-open + thumbnail + replace button. Import `image_picker`. |
| `lib/l10n/app_en.arb` | Modify | Add `pickImage`, `replaceImage`. Remove `liveWallpaperNotSupported`, `fallbackToNature`. |
| `lib/l10n/app_es.arb` | Modify | Same as above |
| `lib/l10n/app_pt.arb` | Modify | Same as above |
| `android/app/src/main/.../MainActivity.kt` | Modify | Remove `getWallpaper` case. Keep `suggestDesiredDimensions`. Remove `drawableToBitmap` helper. |
| `test/services/wallpaper_generator_test.dart` | Modify | Update `_getBackgroundBytes(true)` tests to use temp file instead of MethodChannel mock |
| `test/widgets/settings_background_source_test.dart` | Rewrite | Replace probe tests with picker flow tests (auto-open, cancel revert, thumbnail) |
| `test/providers/settings_provider_test.dart` | Modify | Add `userBackgroundPath` persistence test (set + recreate provider + assert) |

## Interfaces / Contracts

```dart
// New: SettingsProvider
String? get userBackgroundPath;

Future<void> setUserBackgroundPath(String? path) async {
  final prefs = await SharedPreferences.getInstance();
  if (path != null) {
    await prefs.setString('user_background_path', path);
  } else {
    await prefs.remove('user_background_path');
  }
  _userBackgroundPath = path;
  notifyListeners();
}
```

```dart
// Changed: _getBackgroundBytes(useMyWallpaper: true)
// Old: MethodChannel → New: File read via user_background_path
Future<Uint8List?> _getBackgroundBytes({required bool useMyWallpaper}) async {
  if (!useMyWallpaper) {
    // unchanged: ImageCacheService path
  }
  final prefs = await SharedPreferences.getInstance();
  final path = prefs.getString('user_background_path');
  if (path == null || !await File(path).exists()) return null;
  return await File(path).readAsBytes();
}
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | `_getBackgroundBytes(true)` — file exists | Write temp PNG to known path, mock SharedPreferences, assert bytes match |
| Unit | `_getBackgroundBytes(true)` — file missing | Mock SharedPreferences returning null or non-existent path, assert null |
| Unit | `SettingsProvider.userBackgroundPath` persistence | Set path, recreate provider via `init()`, assert getter returns same path |
| Widget | Picker opens on "Mío" toggle with no file | Mock `ImagePicker.pickImage()` returning an image path, assert called once |
| Widget | Cancel picker reverts to "App" | Mock picker returning null, assert toggle back to false |
| Widget | Thumbnail + replace visible | Pre-set `user_background_path` in prefs, assert thumbnail widget + replace button shown |

## Migration / Rollout

- Single `user_background.png` — overwritten on replace, no accumulation
- `use_my_wallpaper` SharedPreferences key stays unchanged
- Previous users who had "Mío" enabled will auto-open the picker on next settings visit (good UX — they wanted their own background)
- `FallbackToNature` SnackBar removed; if `_getBackgroundBytes(true)` returns null, generation is a hard error (not a silent fallback)
- Backup service retains its own `getWallpaper` call; it will fail on API 33+ the same way it does today — no regression

## Open Questions

None.
