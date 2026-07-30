# Exploration: Wallpaper Offset Fix — Moto G56 5G (Android 16, API 36)

## Current State

The wallpaper generation pipeline (`wallpaper_generator.dart`) composites verse text onto a nature
background image at the **background image's native resolution** (e.g., 3512×6240 px). It then passes
the resulting PNG to `wallpaper_manager_flutter`'s `setWallpaper(file, bothScreens)`, which delegates
to Android's `WallpaperManager.setStream(stream, null, false, FLAG_SYSTEM | FLAG_LOCK)`.

The final image is never resized to match the device screen, and no `visibleCropHint` is provided.
Android's WallpaperManager must therefore scale/crop the image autonomously.

## Root Cause Analysis

### Primary Cause: Aspect Ratio Mismatch + Wallpaper Scrolling

The nature images have an aspect ratio of approximately **0.56** (width/height, e.g., 3512/6240).
The Moto G56 5G screen has an aspect ratio of approximately **0.45** (e.g., 1080/2400).

The nature images are **wider relative to their height** than the phone screen.

Android's `WallpaperManager.setStream()` performs a **fit-to-height** (or center-crop) scaling by
default. When it scales the image to match the screen height, the image width exceeds the screen
width by roughly 24%. Since the wallpaper system is designed for horizontal scrolling (spanning
multiple virtual home screens), Android crops/offsets the image, and the default horizontal
alignment pushes the visible content **to the right**.

The text, composited at the center of the full-resolution image, ends up in the cropped-away
portion — appearing shifted right to the user.

### Contributing Factors

| Factor | Impact |
|--------|--------|
| No `visibleCropHint` passed to `setStream()` (`null`) | Android has no guidance on which portion of the full image should be visible |
| No `suggestDesiredDimensions()` call | Android doesn't know the expected wallpaper size |
| `wallpaper_manager_flutter` v1.0.1 uses deprecated `setStream()` | Works on API 36 but doesn't expose modern APIs for dimension hints or custom flags |
| Wallpaper generated at arbitrary resolution (nature photo) | Dimensions vary per image (see table below), none match screen |

### Nature Image Resolutions

| File | Resolution | Aspect Ratio (W/H) |
|------|-----------|---------------------|
| nature_01.jpg | 2152×3827 | 0.562 |
| nature_02.jpg | 1574×2798 | 0.563 |
| nature_03.jpg | 2604×4624 | 0.563 |
| nature_04.jpg | 4472×7952 | 0.562 |
| nature_05.jpg | 3213×5712 | 0.562 |
| nature_06.jpg | 3213×5712 | 0.562 |
| nature_07.jpg | 3376×6000 | 0.563 |
| nature_08.jpg | 2268×4032 | 0.562 |
| nature_09.jpg | 3512×6240 | 0.563 |
| nature_10.jpg | 3512×6240 | 0.563 |

All images hover around 0.56, consistently wider relative to height than the target device (~0.45).

## Affected Areas

- `lib/services/wallpaper_generator.dart` — `_render()` method loads background at native resolution; `_setWallpaper()` calls plugin with `bothScreens`
- `lib/services/wallpaper_scheduler.dart` — background isolate calls same generator; `MediaQuery` unavailable here
- `C:\Users\mario.ferreira\AppData\Local\Pub\Cache\hosted\pub.dev\wallpaper_manager_flutter-1.0.1/` — plugin native code (`WallpaperManagerFlutterPlugin.kt`) calls `setStream()` with no crop hint and no dimension suggestion
- `pubspec.yaml` — pins `wallpaper_manager_flutter: ^1.0.1`
- `openspec/specs/wallpaper-gen/spec.md` — `Visual Composition` requirement currently says "centered vertically and horizontally" but doesn't mandate screen-size output
- `openspec/specs/wallpaper-set/spec.md` — `Set Home and Lock Screen Wallpaper` requirement may need to account for scrolling vs static behavior

## Approaches

### 1. Generate Wallpaper at Exact Screen Dimensions (RECOMMENDED)

Resize the nature background to `screenWidth × screenHeight` **before** compositing the text overlay.
The final PNG will be screen-sized, eliminating any need for Android to scale/crop. Text stays
centered because the canvas IS the screen.

- **Pros**: Root-level fix — addresses the aspect ratio mismatch directly. No plugin changes needed. Works on all devices regardless of launcher scrolling settings. Maintains centered text.
- **Cons**: Small quality loss from downscaling high-res nature photos (negligible visually). Must handle screen dimension retrieval from background isolate (`dart:ui` accessible, `MediaQuery` not).
- **Effort**: Low–Medium
- **Files changed**: `wallpaper_generator.dart` (~20-30 lines added: screen size detection, background resize in `_render()`)

### 2. Set Wallpaper to Lock Screen Only

Change `bothScreens` → `lockScreen` (constant value 2). Lock screens don't scroll, so the image
is displayed as-is with no horizontal offset.

- **Pros**: Trivially simple — one-line change. Immediate relief for the user.
- **Cons**: Home screen wallpaper is lost. Violates current spec (`bothScreens` requirement). May not be acceptable to user.
- **Effort**: Trivial (1 line + spec change)

### 3. Fork/Modify `wallpaper_manager_flutter` Plugin

Add `suggestDesiredDimensions(screenWidth, screenHeight)` call before `setStream()` in the Kotlin
plugin code. Optionally provide a `visibleCropHint` Rect matching the screen.

- **Pros**: Tells Android the expected dimensions, reducing guesswork.
- **Cons**: Requires maintaining a forked plugin. `suggestDesiredDimensions()` is a hint, not a guarantee — launchers may ignore it. Doesn't fix the root dimension mismatch; Android still scales the image. Higher maintenance burden.
- **Effort**: Medium–High

### 4. Replace Plugin with Custom MethodChannel / Native Code

Write a custom MethodChannel that calls `WallpaperManager.setBitmap()` (the modern, non-deprecated
API) with explicit `setWallpaperOffsetSteps()` to disable scrolling, plus dimension hints.

- **Pros**: Full control over the Android wallpaper API. Can disable scrolling programmatically. Uses modern non-deprecated APIs suitable for API 35+.
- **Cons**: Largest effort. Must write and maintain native Kotlin code. Risk of platform-specific bugs. Overkill if approach 1 works.
- **Effort**: High

### 5. Use Alternative Pub Package (`android_wallpaper_manager`)

Switch to a different package that exposes more flags/control.

- **Pros**: Potentially no native code to write.
- **Cons**: No viable alternative identified in pub.dev at time of exploration. Most wallpaper packages are similarly limited or abandoned. Dependency risk.
- **Effort**: Unknown (likely Medium–High, depending on package quality)

## Recommendation

**Approach 1: Generate wallpaper at exact screen dimensions.**

This is the most direct fix — it eliminates the root cause (aspect ratio mismatch) rather than
working around Android's cropping behavior. The implementation is straightforward:

1. **Detect screen dimensions**: Use `PlatformDispatcher.instance.views.first.physicalSize` divided
   by `devicePixelRatio` to get logical screen dimensions. This works from both the main isolate
   and the Workmanager background isolate (unlike `MediaQuery`).

2. **Resize background before compositing**: In the `_render()` method, after decoding the nature
   image, call `img.copyResize(background, width: screenWidth, height: screenHeight)` to produce a
   screen-sized canvas. Apply the dark overlay and text compositing to this resized image.

3. **Preserve aspect ratio with center-crop**: If the nature image aspect ratio differs from the
   screen, apply a center-crop (`copyResizeCropSquare` or manual crop + `copyResize`) to maintain
   visual quality without stretching.

**Fallback**: If the user strongly prefers to keep both home AND lock screen wallpaper (not just
lock screen), approach 1 is the only viable option. If they're willing to accept lock-screen-only,
approach 2 is a viable quick-fix while approach 1 is implemented.

## Risks

- **Background isolate dimension access**: `PlatformDispatcher.instance.views.first` may behave
  differently in a Workmanager isolate. Mitigation: verify during implementation and fall back to
  a stored screen size in SharedPreferences if needed.
- **Different launchers, different behavior**: Some launchers (e.g., third-party launchers) may
  still apply custom wallpaper cropping even with screen-sized images. Mitigation: approach 1
  minimizes but may not eliminate the issue on all launchers. The Moto default launcher should
  behave correctly with screen-sized wallpapers.
- **Image quality**: Downscaling from ~3500px to ~1080px width is lossy. Mitigation: this is
  imperceptible on a phone screen; the text overlay is the primary visual element and will render
  at full sharpness post-resize.
- **API deprecation**: `WallpaperManager.setStream()` is deprecated since API 34 (still functional
  on API 36). Future Android versions may remove it. Mitigation: not urgent, but tracking for a
  future change to migrate to `setBitmap()`.

## Ready for Proposal

**Yes.** The root cause is clearly identified (aspect ratio mismatch + wallpaper scrolling crop),
and the recommended approach (generate at screen dimensions) is low-risk, well-understood, and
scoped to a single file. A proposal should:

1. Define the spec delta for `wallpaper-gen`: require screen-size output
2. Define the implementation plan: detect screen dimensions, resize background, re-composite
3. Address the background isolate case explicitly (`dart:ui` vs fallback)
4. Update `wallpaper-set` spec if scrolling behavior expectations change
