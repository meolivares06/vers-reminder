# Proposal: Wallpaper Screen-Size Output

## Intent

Wallpaper PNGs generated at native photo resolution (~0.56 aspect ratio) get cropped by Android's WallpaperManager on devices with narrower screens (~0.45). Centered verse text appears shifted right. Fix: resize background to screen dimensions before compositing so the output image matches the device screen.

## Scope

### In Scope
- Detect device screen dimensions at runtime via `dart:ui` PlatformDispatcher
- Cache dimensions write-once in SharedPreferences for background isolate access
- Resize nature background to screen dimensions inside `WallpaperGenerator._render()` before compositing
- Preserve existing text overlay, dark overlay, and locale behavior unchanged

### Out of Scope
- Modifying `wallpaper_manager_flutter` plugin or its native Kotlin code
- Fixing launcher-specific cropping behaviors
- Migrating off deprecated `setStream()` API
- Multi-window or foldable-specific handling
- Refreshing cached dimensions (write-once only)

## Capabilities

> This section is the CONTRACT between proposal and specs phases.

### New Capabilities
None — no new domain capabilities introduced.

### Modified Capabilities
- `wallpaper-gen`: Visual Composition requirement MUST mandate output at device screen dimensions. Background resize must happen before text overlay compositing so both layers share the same canvas size.

## Approach

1. **Main isolate (UI thread)**: On app start, read `PlatformDispatcher.instance.views.first.physicalSize` divided by `devicePixelRatio`. Store `screen_width` / `screen_height` in SharedPreferences. Runs once per install.
2. **Background isolate (Workmanager callback)**: Read cached dimensions from SharedPreferences. Fallback: 1080×1920 if no cache exists.
3. **In `WallpaperGenerator._render()`**: After decoding the nature JPEG, call `img.copyResize(background, width: screenWidth, height: screenHeight)`. Apply dark overlay and text compositing to the resized image. Both layers now share exact screen dimensions.
4. **`_renderTextOverlay()`**: Already uses `background.width/height` from the resized image — font sizing, word-wrap, and centering adapt automatically.
5. **`_setWallpaper()`**: No changes — feeds the screen-sized PNG to the plugin which sets it as-is.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Modified | `_render()` adds background resize step. Signature adds optional `screenWidth`/`screenHeight` params. |
| `lib/main.dart` | Modified | Dimension caching on app start. |
| `lib/services/wallpaper_scheduler.dart` | Modified | Pass cached dimensions from SharedPreferences to generator. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Background isolate can't access SharedPreferences | Low | SharedPreferences works across isolates in Flutter. Tested path in Workmanager callbacks. |
| Different launchers still crop screen-sized images | Low | Most launchers display screen-sized wallpapers without cropping. Moto default launcher confirmed compatible. |
| Image quality loss from downscale | Low | ~3500px → ~1080px is visually imperceptible on phone displays. |

## Rollback Plan

Revert `wallpaper_generator.dart` to generate at native resolution (remove the `copyResize` call). Remove dimension caching from `main.dart` and `wallpaper_scheduler.dart`. No DB migration or data loss.

## Dependencies

- `dart:ui` (PlatformDispatcher) — available in Flutter SDK, no pub dependency
- `shared_preferences` — already in project
- `image` package — already in project for PNG compositing

## Success Criteria

- [ ] Wallpaper PNG dimensions match device screen dimensions (verified via file metadata)
- [ ] Verse text appears visually centered on both home and lock screens on the Moto G56 5G
- [ ] Automated wallpaper generation (Workmanager) produces correctly centered output
- [ ] No regression in text overlay behavior (font sizing, word-wrap, locale)
