# Tasks: Wallpaper Live Preview

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250–350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

## Phase 1: Pipeline Refactor — Extract Composite, Add Preview

- [x] 1.1 Extract `_composite({backgroundBytes, verse, locale, screenWidth, screenHeight, horizontalOffset, verticalAlignment, fontScale, calibratedInset})` from `_render()` in `lib/services/wallpaper_generator.dart` — returns `Uint8List?` (PNG bytes), no file I/O
- [x] 1.2 Refactor `_render()`: replace inline composite with call to `_composite()` then `File(outputPath).writeAsBytes(pngBytes)`
- [x] 1.3 Add `renderPreview(int previewWidth, int previewHeight, ...)` — calls `_composite()` at preview resolution, returns `Uint8List?`, no disk writes

## Phase 2: CalibrationScreen Rewrite — StatefulWidget, Debounce, Image.memory

- [x] 2.1 Convert `lib/screens/calibration/calibration_screen.dart` from `StatelessWidget` to `StatefulWidget` with `Uint8List? _previewBytes` and `Timer? _debounce`
- [x] 2.2 Request initial preview in `initState()` via `renderPreview()` at ¼ screen, show placeholder until bytes arrive
- [x] 2.3 Wire slider `onChanged` → cancel debounce → 300ms Timer → `renderPreview()` async → `setState(() => _previewBytes = result)`
- [x] 2.4 Add `Image.memory(_previewBytes!)` above slider with fallback: keep previous preview on null, show `Container(height: 200, color: surfaceVariant)` placeholder on first null
- [x] 2.5 Verify "Aplicar y verificar" still calls `generateAndSetWallpaper()` at full resolution; preview stays visible during generation

## Phase 3: Tests — Unit and Widget

- [x] 3.1 Unit: `_composite()` returns PNG bytes matching specified dimensions — covers R-WG-008 Sc.1
- [x] 3.2 Unit: `_composite()` returns null for corrupt input bytes — covers R-WG-008 Sc.2
- [x] 3.3 Unit: `renderPreview()` returns ¼ resolution PNG with identical compositing to `_render()` — covers R-WG-009 Sc.1 & 2
- [x] 3.4 Widget: rapid slider changes fire one debounced preview request after 300ms — covers R-CU-001
- [x] 3.5 Widget: null preview doesn't crash, shows placeholder or retains previous — covers R-CU-003
