## Exploration: Wallpaper Source Toggle + Live Calibration Preview

### Current State

The app generates wallpapers by compositing verse text over a **bundled nature image** (10 JPGs in `assets/images/nature/`). The `WallpaperGenerator` class follows a fixed pipeline:

1. `ImageCacheService.getNextRandomImage()` → picks a random cached nature JPG
2. `_render()` → decodes, crops (calibratedInset), resizes (screen dimensions), applies 40% dark overlay
3. `_renderTextOverlay()` → renders verse text as `ui.Image` via `PictureRecorder`
4. Compositing: background (3‑channel `img.Image`) → 4‑channel → composite text over it → `img.encodePng` → write to temp file
5. `_setWallpaper()` → `WallpaperManagerFlutter.setWallpaper()` → file path

The `CalibrationScreen` is a `StatelessWidget`. Users adjust a slider, tap "Apply & verify", the wallpaper **is generated and SET** on device, they must navigate away to check the home screen, then come back to adjust the slider again. **No live preview.**

The `SettingsProvider.triggerNow()` flow: picks a verse, calls `generateAndSetWallpaper()`, updates `WallpaperStatus`, notifies UI.

---

### A. Reading Current Wallpaper

**`wallpaper_manager_flutter` v1.0.1** only exposes `setWallpaper(File, int)` — it has **NO method to read/get the current wallpaper**. Verified by reading source from GitHub (the Dart API only has `setWallpaper` + three screen constants).

**Required approach: Custom MethodChannel.**

| Approach | Description | Effort |
|----------|-------------|--------|
| **A1 — `WallpaperManager.getDrawable()`** | Kotlin: `WallpaperManager.getInstance(context).drawable` → convert `BitmapDrawable` to PNG bytes → return to Flutter. `getDrawable()` was deprecated in API 33 but still works. Requires `READ_EXTERNAL_STORAGE` permission pre‑Android 13. | Low |
| **A2 — `WallpaperManager.getWallpaperFile()`** | Kotlin: `wm.getWallpaperFile(FLAG_SYSTEM)` → `BitmapFactory.decodeFileDescriptor(fd.fileDescriptor)` → PNG bytes. No storage permission needed (Android 9+). Returns `null` for live wallpapers. | Low |
| **A3 — `WallpaperManager.peekDrawable()`** | Like `getDrawable()` but without throwing exceptions. Also no extra permission. Returns `null` for live wallpapers. | Low |

**Recommendation: A2 (getWallpaperFile) with A3 fallback.** For Android 9+ devices (~98% of active Android), `getWallpaperFile` returns the actual wallpaper file without extra permissions. Fall back to `peekDrawable()` for older devices.

**TL;DR:** Add ~30 lines of Kotlin + 15 lines of Dart. Register a `MethodChannel('vers_reminder/wallpaper')` in `MainActivity.kt`.

---

### B. Generator Pipeline Split

Current `_render()` method is a monolithic private method. It does everything from decode to file write. For a live preview we need to **intercept before file write** and return the composited image data.

**Pipeline anatomy:**

```
_RENDER:
  decodeImage(bytes) → img.Image (3‑ch)
  ↓
  copyCrop (calibratedInset)
  ↓
  copyResize (screenWidth×screenHeight)
  ↓
  _applyDarkOverlay (40% black fill)
  ↓
  _renderTextOverlay → ui.Image (text layer)
  ↓
  Convert bg to 4-channel img.Image
  ↓
  compositeImage (text on bg)
  ↓
  encodePng → writeAsBytes (FILE WRITE — SKIP FOR PREVIEW)
```

**Key finding:** `_renderTextOverlay` already returns a `ui.Image`. The compositing happens at the `img.Image` level (the `image` package, not `dart:ui`). The final output before file write is **PNG bytes**.

| Split Approach | Pros | Cons |
|----------------|------|------|
| **B1 — Extract `_composite()` returning `Uint8List`** | Minimal refactor. `_render` calls `_composite()` then writes. Preview caller gets bytes directly. PNG encoding still happens. | Extra encode/decode roundtrip if converting to `dart:ui.Image` for preview. |
| **B2 — Extract `_composite()` returning `img.Image`** | No encode penalty for the caller that wants raw pixel data. Caller decides format. | `img.Image` is from the `image` package — can't be used directly in Flutter widgets. Must still encode to PNG or convert to `dart:ui.Image`. |
| **B3 — Duplicate pipeline as `renderPreview()`** | Clean separation. Preview can run at lower resolution. | Code duplication. Maintenance burden. |

**Recommendation: B1 — Extract a `_composite()` method returning `Uint8List` (PNG bytes).** Then:

- `_render()` → calls `_composite()` → writes bytes to file → returns file path
- New `renderPreview()` → calls `_composite()` at preview size → returns `Uint8List` for `Image.memory()`

Preview size: pass a `previewWidth`/`previewHeight` param to render at e.g. 270×480. The text overlay `_renderTextOverlay` is resolution-dependent (font size scales from image width), so preview renders need their own sizing — which is exactly what the user wants to calibrate.

---

### C. Live Preview Approach

**Options for displaying the rendered image in Flutter:**

| Option | Description | Performance | Effort |
|--------|-------------|-------------|--------|
| **C1 — `Image.memory(pngBytes)`** | Encode composited result to PNG, pass bytes to `Image.memory()` widget. Simplest. | Good for preview resolution. Native PNG decode in Flutter. | Low |
| **C2 — `RawImage` from `dart:ui.Image`** | Convert `img.Image` → `decodeImageFromList(encodePng(...))` → `RawImage`. Extra encode/decode. | Same as C1 but more boilerplate. | Medium |
| **C3 — Pure `dart:ui` compositing** | Rewrite dark overlay + compositing using `Canvas`/`Paint` instead of the `image` package. | Best (no encoding). Single code path. | **High** — major refactor, risk of visual differences |

**Recommendation: C1 (`Image.memory`).** For a live calibration preview:

1. Render at ~¼ resolution (e.g., phone screen / 4) — fast enough for slider interaction
2. Wrap in a `RepaintBoundary` and use a **debounced** tile (300ms delay after last slider change)
3. `CalibrationScreen` becomes a `StatefulWidget` with a `Uint8List? _previewBytes` field
4. Slider `onChanged` triggers a debounced render via `SettingsProvider` or directly

**Preview flow:**
```
Slider moves → debounce 300ms → WallpaperGenerator.renderPreview(...)
→ composite at preview size → Uint8List → setState(() => _previewBytes = bytes)
→ Image.memory(_previewBytes)
```

"Save" button: calls `WallpaperGenerator.generateAndSetWallpaper()` at full resolution.

---

### D. Wallpaper Source Toggle

A `SwitchListTile` in **SettingsScreen** to choose between:
- `wallpaperSource: 'nature'` (current behavior — bundled assets)
- `wallpaperSource: 'current'` (device's current wallpaper)

**Storage:** add a `wallpaper_source` key to `SharedPreferences`. Default: `'nature'`.

**Flow changes in `WallpaperGenerator`:**

```
_render() / renderPreview():
  if source == 'nature':
    imagePath = ImageCacheService.getNextRandomImage()
  else:
    imagePath = read current wallpaper via MethodChannel → save to temp file → use path
```

The `WallpaperResultError.backgroundMissing` still works — if reading the current wallpaper fails, return that error.

**Scheduler impact:** `callbackDispatcher` in `wallpaper_scheduler.dart` reads `SharedPreferences` — it just needs to read the `wallpaper_source` key and pass it to the generator. Small change.

**Impact on `ImageCacheService`:** Optional — if source is 'current', we skip the cache entirely and save the read wallpaper to a temp file for the pipeline.

---

### E. Android Native Changes

`MainActivity.kt` currently extends `FlutterActivity` with zero custom code. Need to add:

```kotlin
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "vers_reminder/wallpaper"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getWallpaper") {
                try {
                    val wm = WallpaperManager.getInstance(this@MainActivity)
                    var bytes: ByteArray? = null

                    // Try getWallpaperFile first (API 28+, no permission needed)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        val fd = wm.getWallpaperFile(WallpaperManager.FLAG_SYSTEM)
                        if (fd != null) {
                            val bitmap = BitmapFactory.decodeFileDescriptor(fd.fileDescriptor)
                            if (bitmap != null) {
                                val stream = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                bytes = stream.toByteArray()
                            }
                            fd.close()
                        }
                    }

                    // Fallback to peekDrawable
                    if (bytes == null) {
                        val drawable = wm.peekDrawable()
                        if (drawable is BitmapDrawable) {
                            val bitmap = drawable.bitmap
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            bytes = stream.toByteArray()
                        }
                    }

                    if (bytes != null) {
                        result.success(bytes)
                    } else {
                        result.error("NO_WALLPAPER", "Could not read wallpaper", null)
                    }
                } catch (e: Exception) {
                    result.error("WALLPAPER_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
```

**Flutter side (new method in WallpaperGenerator or a separate service):**

```dart
static const _channel = MethodChannel('vers_reminder/wallpaper');

Future<Uint8List?> getCurrentWallpaperBytes() async {
  try {
    return await _channel.invokeMethod('getWallpaper');
  } on PlatformException {
    return null;
  }
}
```

**Permission note:** `peekDrawable()` and `getWallpaperFile()` do NOT require `READ_EXTERNAL_STORAGE`. No new manifest permissions needed.

---

### F. Test Changes

Current tests in `wallpaper_generator_test.dart`:
- Use `_createTestImage(width, height)` to create synthetic images via the `image` package
- Test resize behavior, error handling for corrupt/missing images
- `generateAndSetWallpaper` uses `ImageCacheService` which requires Flutter test binding — the test expects `backgroundMissing` when no cache exists

**New test patterns needed:**

| Test Area | What to Test | Approach |
|-----------|-------------|----------|
| Pipeline split | `_composite()` returns bytes without writing to disk | Call `renderPreview()` with a test image path; verify `Uint8List` is non-null and decodes to expected dimensions |
| Source toggle | `renderFromPath()` receives wallpaper bytes instead of nature path | Inject a mock path; verify the pipeline runs with external bytes |
| Current wallpaper | MethodChannel integration | Use `TestDefaultBinaryMessenger` to mock `getWallpaper` response with test image bytes |
| Widget test | CalibrationScreen live preview updates | `testWidgets` with mocked generator; move slider; verify `Image.memory` widget appears |
| Error path | Wallpaper read fails → `backgroundMissing` | Mock channel to return null; verify error result |
| Preview resolution | `renderPreview(previewWidth: 270)` produces 270px-wide output | Assert output image dimensions |

---

### Affected Areas

| File | Why Affected |
|------|-------------|
| `lib/services/wallpaper_generator.dart` | Core pipeline refactor: extract `_composite()`, add `renderPreview()`, add `wallpaperSource` param |
| `lib/screens/calibration/calibration_screen.dart` | Rewrite from `StatelessWidget` → `StatefulWidget` with live `Image.memory` preview, debounced slider |
| `lib/providers/settings_provider.dart` | Add `wallpaperSource` field + persistence, add `useCurrentWallpaper` toggle setter |
| `lib/screens/settings/settings_screen.dart` | Add `SwitchListTile` for wallpaper source toggle |
| `lib/services/wallpaper_scheduler.dart` | Read `wallpaper_source` from SharedPreferences and pass to generator in `callbackDispatcher` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Add `MethodChannel` with `getWallpaper` handler |
| `lib/services/image_cache_service.dart` | Minor: skip cache init when source is 'current' (optional optimization) |
| `lib/l10n/generated/app_localizations_*.dart` | Add strings for "Use current wallpaper", wallpaper source labels |
| `test/services/wallpaper_generator_test.dart` | Add tests for preview pipeline, source toggle, MethodChannel mock |
| `openspec/specs/wallpaper-gen/spec.md` | Add requirements for wallpaper source toggle and preview rendering |

---

### Approaches

1. **Incremental pipeline refactor + MethodChannel + StatefulWidget preview**
   - Extract `_composite()` returning `Uint8List` from `_render()`
   - Add `renderPreview()` that calls `_composite()` at preview resolution
   - Add custom `MethodChannel` in Kotlin for reading current wallpaper
   - Convert `CalibrationScreen` to `StatefulWidget` with debounced preview
   - Add `wallpaperSource` toggle to `SettingsProvider` + UI
   - **Effort:** Medium (3–4 focused sessions)
   - **Pros:** No dependencies on new packages. Clean refactor. Preview + source toggle are independent features that can ship separately (toggle ships first).
   - **Cons:** Requires Flutter plugin channel knowledge. `Image.memory()` involves PNG encode/decode per preview frame.

2. **Replace compositing with pure `dart:ui` Canvas rendering**
   - Rewrite dark overlay and compositing using `Canvas`/`Paint` instead of the `image` package
   - All pipelines return `dart:ui.Image` directly
   - **Effort:** High (risky, changes fundamental rendering strategy)
   - **Pros:** One code path for preview and file output. No encode/decode for preview.
   - **Cons:** Major refactor of working code. The `image` package handles format conversion/encoding reliably. Risk of visual regressions.

3. **Replace wallpaper_manager_flutter entirely with custom MethodChannel**
   - Write both `getWallpaper` and `setWallpaper` via the same channel
   - Remove dependency on `wallpaper_manager_flutter`
   - **Effort:** Medium but adds scope creep
   - **Cons:** Unnecessary. The existing plugin works fine for setting. Don't fix what isn't broken.

---

### Recommendation

**Approach 1 — Incremental pipeline refactor + MethodChannel + StatefulWidget preview.**

The two features (wallpaper source toggle and live preview) are **independent but complementary**. The architecture naturally splits into:

**Phase A (wallpaper source toggle)** — can ship standalone:
1. Add `getWallpaperBytes` MethodChannel (Kotlin + Dart)
2. Add `wallpaperSource` param to `WallpaperGenerator._render()`
3. Add UI toggle in `SettingsScreen` + `SettingsProvider`
4. Update scheduler to pass the param
5. Tests

**Phase B (live calibration preview)** — layered on top:
1. Extract `_composite()` from `_render()`
2. Add `renderPreview()` returning `Uint8List`
3. Rewrite `CalibrationScreen` as `StatefulWidget` with debounced preview
4. "Save" button triggers full-res `generateAndSetWallpaper()`
5. Widget tests

This ordering means the source toggle ships sooner (it's simpler), and the preview work doesn't block it.

---

### Risks

- **Live wallpaper detection**: If the device is using a live wallpaper, `getWallpaperFile()` returns null. The fallback to `peekDrawable()` may return the default wallpaper or null. Must handle gracefully (fall through to nature assets).
- **Preview render performance**: Even at ¼ resolution, each render involves decoding a JPG, running the compositing pipeline, and encoding PNG. On slower devices, slider response may lag. Mitigate with 300ms debounce and a loading indicator.
- **Pipeline divergence**: The preview pipeline must produce visually identical output to the full pipeline. Using the same `_composite()` method (just at different resolutions) guarantees this.
- **Cognitive load for reviewer**: These changes touch 10+ files. The delivery strategy should split into 2 PRs (Phase A, Phase B) to stay under the 400-line review budget.
- **TextPainter in preview**: `_renderTextOverlay` uses `TextPainter` which requires `WidgetsFlutterBinding`. If `renderPreview()` is called from a widget context, this is fine. But the scheduler's `callbackDispatcher` won't have a binding — that's already handled because it calls the full pipeline.
- **`img.Image` to `dart:ui.Image` gap**: The compositing uses the `image` package. If we ever need true `dart:ui.Image` for preview (e.g., `RawImage`), we'd need `decodeImageFromList(encodePng(imgImage))` — a wasteful encode→decode. `Image.memory()` avoids this by going through Flutter's image cache.

---

### Ready for Proposal

Yes. The exploration is complete. The orchestrator can proceed to `sdd-propose` with the following:
- **Change name**: `wallpaper-source-preview`
- **Split into 2 deliverable phases** (Phase A: source toggle, Phase B: live preview)
- **Delivery strategy**: `auto-chain` — Phase A first (simpler, lower risk), then Phase B
- **Core decisions made**:
  - Custom `MethodChannel` for reading current wallpaper (approach A2)
  - Pipeline refactor extracting `_composite()` → `Uint8List` (approach B1)
  - `Image.memory()` for live preview (approach C1)
  - Debounced slider (300ms) to throttle preview renders
  - No new package dependencies
