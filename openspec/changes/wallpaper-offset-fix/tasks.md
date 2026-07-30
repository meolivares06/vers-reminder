
# Tasks: Wallpaper Screen-Size Output

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 25-30 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes (resolved — single PR, under budget)
Chained PRs recommended: No
Chain strategy: none
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Background resize + dimension plumbing | Single PR | 3 files, ~30 lines, well under budget |

## Phase 1: Core Resize Logic

- [x] 1.1 In `lib/services/wallpaper_generator.dart`, add optional `int? screenWidth` and `int? screenHeight` params to `generateAndSetWallpaper()`, `renderOnly()`, and `_render()` signatures
- [x] 1.2 In `_render()`, after `img.decodeImage(bytes)`: if both dimensions non-null, call `img.copyResize(background, width: screenWidth!, height: screenHeight!)` before `_applyDarkOverlay()`

## Phase 2: Dimension Plumbing

- [x] 2.1 In `lib/main.dart`, add `PlatformDispatcher` and `SharedPreferences` imports; in `main()`, read `physicalSize / devicePixelRatio`, write-once to `screen_width`/`screen_height` SharedPreferences keys (use `containsKey` guard)
- [x] 2.2 In `lib/services/wallpaper_scheduler.dart`, in `callbackDispatcher`: read `screen_width`/`screen_height` from existing `SharedPreferences` instance, pass to `generateAndSetWallpaper(screenWidth: ..., screenHeight: ...)` with `?? 1080`/`?? 1920` fallbacks

## Phase 3: Verification

- [x] 3.1 Unit: verify `_render()` with `screenWidth=1080, screenHeight=2340` produces a 1080×2340 output PNG
- [x] 3.2 Unit: verify `_render()` without screen params preserves native image dimensions (backward compat)
- [x] 3.3 Unit: verify `?? 1080` / `?? 1920` fallback expressions when SharedPreferences returns null
- [x] 3.4 Integration: verify `callbackDispatcher` reads cached prefs and forwards values to generator (set SharedPreferences manually before call)
