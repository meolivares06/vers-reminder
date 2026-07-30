# Design: Wallpaper Generator

## Technical Approach

A stateless pipeline that composes verse text over a nature background using the `image` Dart package, then optionally sets it as wallpaper on Android via `wallpaper_manager_flutter`. The generator is a singleton (matching `ImageCacheService`/`DatabaseService` pattern) that chains three phases: pick → render → set.

## Architecture Decisions

| Decision | Option | Tradeoff | Choice |
|----------|--------|----------|--------|
| **Singleton pattern** | DI vs ServiceLocator vs singleton | Project convention is singleton (`instance` getter + `_internal` constructor). | Singleton |
| **Font format** | Bitmap font vs TrueType | Bitmap needs pre-rasterized .bmf files per size; TrueType loaded via `BitmapFont` supports dynamic sizing from a single asset. | TrueType (OpenSans) |
| **Text rendering** | `drawString` with `BitmapFont` vs manual pixel drawing | `drawString` handles kerning and baseline. After scaling `image` lib 4.x dropped `drawString`, use `drawStringCentered` from `image` >=4.x API or manual positioning with `drawChar`. | `drawChar` loop with manual word-wrap |
| **Dark overlay** | Pre-multiplied PNG vs draw rectangle with blend mode | Draw black rect with opacity then render text on top — simple, deterministic, no asset overhead. | `drawImage` with `BlendMode` or fill rect with alpha |
| **Output format** | PNG vs JPEG | PNG lossless, no artifacts on text edges; slightly larger file but wallpapers are single-use temps. | PNG |
| **Font asset source** | Bundled TTF vs download at runtime | Bundled TTF works offline, no loading delay. | OpenSans-Regular.ttf in `assets/fonts/` |

## Data Flow

```
VerseProvider ──→ verse (text + citation)
                       │
ImageCacheService ──→ background image path
                       │
                       ▼
              WallpaperGenerator
              ┌─────────────────────────┐
              │ 1. Load image (decoded) │
              │ 2. Dark overlay (40%)   │
              │ 3. Measure + wrap text  │
              │ 4. Draw text layers     │
              │ 5. Encode PNG           │
              └─────────┬───────────────┘
                        │ temp PNG path
                        ▼
              wallpaper_manager_flutter
              ┌─────────────────────────┐
              │ setHomeScreen +         │
              │ setLockScreen (Android) │
              └─────────┬───────────────┘
                        │ WallpaperResult
                        ▼
                    Caller
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/services/wallpaper_generator.dart` | Create | Core service: `generateAndSetWallpaper()` pipeline |
| `lib/models/wallpaper_result.dart` | Create | Result type with success/fail, path, error, verse metadata |
| `assets/fonts/OpenSans-Regular.ttf` | Create | OpenSans font asset (Google Fonts, OFL license) |
| `pubspec.yaml` | Modify | Add `assets/fonts/` and `wallpaper_manager_flutter` dependency |

## Interfaces / Contracts

```dart
class WallpaperResult {
  final bool success;
  final String? imagePath;
  final String? error;
  final String? verseText;
  final String? citation;
  final double fontSize;
}

class WallpaperGenerator {
  static final WallpaperGenerator instance = WallpaperGenerator._internal();
  WallpaperGenerator._internal();

  /// Main entry: pick random verse + image, render, set wallpaper.
  Future<WallpaperResult> generateAndSetWallpaper();

  /// Render-only: returns path to temp PNG without setting wallpaper.
  Future<String?> renderOnly();
}
```

Word-wrap algorithm (pseudocode):
```
maxWidth = imageWidth * 0.8  // 10% margin each side
currentSize = 36
repeat:
  for each line (split by words):
    width = measureText(line, font, currentSize)
    if width > maxWidth: reduce currentSize by 2, restart
  if all lines fit or currentSize < 12: break
if currentSize < 12:
  truncate last visible line with "..."
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Word-wrap & font-size reduction | Pure function: test with known text lengths, assert reduced font size |
| Unit | Locale consistency validation | Test that mismatch between verse locale and active locale rejects correctly |
| Unit | `WallpaperResult` construction | Standard Dart unit tests |
| Integration | Full render pipeline | Load a test image + font, render verse, assert PNG bytes produced |
| Widget | N/A | This service has no UI |

## Migration / Rollout

No migration required. The font asset and dependency are additive — existing code is untouched. The feature is gated by the caller invoking `generateAndSetWallpaper()`.

## Open Questions

- [ ] Does `wallpaper_manager_flutter` require `SET_WALLPAPER` permission on Android manifest, or does the plugin handle it? If required, need to document manifest changes in sdd-apply.
- [ ] What is the exact `drawString`/`drawChar` API in `image` 4.x for this project's version? Verify at apply time.
