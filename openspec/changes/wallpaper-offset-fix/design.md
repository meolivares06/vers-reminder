# Design: Wallpaper Screen-Size Output

## Technical Approach

Resize the decoded nature background to device screen dimensions before compositing, so the output PNG matches screen size. Screen dimensions are cached write-once in SharedPreferences (UI thread), read by the background isolate, and passed through `WallpaperGenerator` as explicit parameters. Fallback: 1080×1920.

The existing pipeline adapts automatically: `_renderTextOverlay` uses `background.width/height` from the already-resized image, font sizing is ratio-based, and `bgRgba` creation inherits the new dimensions.

## Architecture Decisions

| Decision | Options | Chosen | Rationale |
|----------|---------|--------|-----------|
| Dimension store | SharedPreferences / SQLite `app_config` / in-memory singleton | **SharedPreferences** | Already in use (locale). Isolate-safe. No DB migration. Two int keys — not worth SQLite schema change. |
| Resize algorithm | `copyResize` with fill (stretch) / `copyResize` maintaining aspect ratio with letterbox / crop to fit | **Direct fill (stretch)** | Minor aspect distortion (~0.56 → ~0.45 ratio) hidden by 40% dark overlay. Simpler code path. |
| Param plumbing | Explicit optional params on public API / SharedPreferences read inside `_render()` / service class | **Explicit optional params** | Keeps `WallpaperGenerator` pure (no storage dependency), testable. Matches existing param-passing convention (`Verse`, `locale`). |
| Cache strategy | Write every launch / Write-once via `containsKey` check | **Write-once** | Matches spec "once per install." Avoids unnecessary writes. Reinstall = fresh cache on device change. |

## Data Flow

```
Main Isolate (main.dart init)
  PlatformDispatcher.instance.views.first
    → physicalSize / devicePixelRatio → logical px
    → SharedPreferences.putInt('screen_width', w)
    → SharedPreferences.putInt('screen_height', h)
         │
         ▼
Background Isolate (callbackDispatcher)
  SharedPreferences.getInt('screen_width')  ?? 1080
  SharedPreferences.getInt('screen_height') ?? 1920
    → generateAndSetWallpaper(screenWidth, screenHeight)
         │
         ▼
WallpaperGenerator._render()
  img.decodeImage(bytes) → img.copyResize(width: sw, height: sh)
    → _applyDarkOverlay(resizedImage)
    → _renderTextOverlay(imageWidth: resizedImage.width, ...)
    → compositeImage → encodePng
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/main.dart` | Modify | Add `PlatformDispatcher` and `SharedPreferences` imports. In `main()`, read physical size, compute logical px, write-once to `screen_width`/`screen_height` keys. |
| `lib/services/wallpaper_generator.dart` | Modify | Add optional `screenWidth`/`screenHeight` (int?) params to `generateAndSetWallpaper`, `renderOnly`, and `_render`. In `_render`, after `decodeImage`: if both params non-null, `img.copyResize(background, width: screenWidth!, height: screenHeight!)`. |
| `lib/services/wallpaper_scheduler.dart` | Modify | In `callbackDispatcher`, read `screen_width`/`screen_height` from existing `SharedPreferences` instance, pass to `generateAndSetWallpaper`. |

## Interfaces / Contracts

```dart
// WallpaperGenerator — updated signatures
Future<WallpaperResult> generateAndSetWallpaper({
  required Verse verse,
  required String locale,
  int? screenWidth,   // NEW: optional, nullable
  int? screenHeight,  // NEW: optional, nullable
});

Future<String?> renderOnly({
  required Verse verse,
  required String locale,
  int? screenWidth,   // NEW: optional, nullable
  int? screenHeight,  // NEW: optional, nullable
});

// SharedPreferences keys (new)
static const String _screenWidthKey  = 'screen_width';
static const String _screenHeightKey = 'screen_height';
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `_render` with explicit dimensions uses `copyResize` and produces correct output size | Mock background image (fixed size), call with `screenWidth=1080, screenHeight=2340`, assert output PNG is 1080×2340 |
| Unit | `_render` without dimensions preserves native size (backward compat) | Same mock, omit params, assert output matches input dimensions |
| Unit | Fallback values when SharedPreferences returns null | Test `?? 1080` / `?? 1920` expressions |
| Integration | `callbackDispatcher` reads cached prefs and passes to generator | Set SharedPreferences manually before calling, verify generator receives values |

## Migration / Rollout

No migration required. Existing wallpapers continue working. On first launch after update, screen dimensions are cached. On next wallpaper generation cycle, output switches from native to screen-sized. Rollback: remove `copyResize` call and dimension params.

## Open Questions

None.
