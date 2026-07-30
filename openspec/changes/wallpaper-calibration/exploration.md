# Exploration: Wallpaper Calibration Setup

## Current State

The `wallpaper-offset-fix` change (already merged) resizes the nature background to **physical screen dimensions** before compositing verse text. The output PNG matches the screen exactly — `screenWidth × screenHeight` physical pixels — which should eliminate Android's need to scale or crop.

**However**: the text still appears shifted on some devices. Root cause analysis from the previous exploration identified that Android's `WallpaperManager.setStream()` applies a **horizontal scroll offset** even to screen-sized images. This offset varies by:
- Device manufacturer (Moto, Samsung, Pixel, etc.)
- Launcher (stock launcher, Nova, Action, etc.)
- Home screen count and scroll configuration

The existing workaround (`horizontalOffset` in Settings) shifts text pixels left/right before compositing. But it's trial-and-error: the user generates a wallpaper, applies it, goes back to home screen to check, returns to adjust, repeats. There's no visual feedback loop.

### What exists today:
- `lib/services/wallpaper_generator.dart` — renders wallpaper at screen dimensions, supports `horizontalOffset` (pixel shift) and `verticalAlignment`
- `lib/providers/settings_provider.dart` — stores `horizontal_offset` and `vertical_alignment` in SharedPreferences
- `lib/screens/settings/settings_screen.dart` — has a slider for horizontal offset (-20 to +20, each unit ≈ 0.5% image width)
- `lib/services/wallpaper_scheduler.dart` — background isolate reads prefs, passes values to generator
- `lib/main.dart` — caches screen dimensions on first launch

## What We're Exploring

A **one-time calibration setup screen** where the user visually adjusts a crop inset until the wallpaper fits their viewport exactly. The calibration value is stored permanently and used for all future wallpaper generations.

### How it differs from the existing offset:
- **Current**: shifts text *inside* the full image (pixel offset on composition)
- **Proposed**: crops the image *before* text compositing, then re-resizes to screen dimensions. The text stays perfectly centered on the *cropped* canvas.

This changes the approach from "shift text to match Android's crop" to "match Android's crop so centered text IS centered."

## Feasibility Analysis

### Can we show a live wallpaper preview accurate enough for calibration?

**Partially.** Here's the critical limitation:

The calibration preview would be shown **inside the app** — but the app can't replicate how the device's specific launcher displays the wallpaper. The offset is applied by Android's `WallpaperManager` at the OS level, not by Flutter's `Image` widget.

**What we CAN show**:
- A full-screen preview of the generated wallpaper with visual overlay (masked borders)
- The user adjusts a slider, the preview updates in real-time
- We can show the final image exactly as generated

**What we CANNOT accurately simulate**:
- How the launcher crops/shifts it on the actual home screen
- The parallax scrolling offset (which varies per launcher)
- The overlap with system UI elements (status bar, navigation bar)

### Key insight for calibration viability

Since we can't simulate the launcher's behavior, the calibration screen must be a **generate-apply-adjust loop** within a single screen:

1. App generates a test wallpaper with visible alignment markers
2. Applies it to the wallpaper (user sees it immediately on home screen)
3. User comes back to app, adjusts slider, generates again, applies again
4. Loop until satisfied, then save

This IS feasible and aligns with how similar apps (Muzei, Walli) handle calibration.

## Affected Areas

- `lib/services/wallpaper_generator.dart` — needs crop-before-resize pipeline when calibrated
- `lib/providers/settings_provider.dart` — add `calibrated_inset` read/write
- `lib/screens/settings/settings_screen.dart` — add "Calibrar" button, show calibration status
- `lib/services/wallpaper_scheduler.dart` — read calibrated inset, pass to generator
- `lib/main.dart` — optionally redirect to calibration screen on first launch if not calibrated
- `lib/l10n/app_es.arb`, `lib/l10n/app_pt.arb` — new strings for calibration UI
- `openspec/specs/wallpaper-gen/spec.md` — add crop requirement when calibrated
- `openspec/specs/wallpaper-set/spec.md` — maybe needs offset/scroll expectations

## Approaches

### 1. Generate-Apply-Adjust Loop (RECOMMENDED)

A dedicated calibration screen where:
- A test wallpaper is generated with a **centered crosshair** or **alignment target** (not verse text — unambiguous visual marker)
- The slider controls the crop **inset** (pixels removed from each side)
- "Aplicar y verificar" button generates, applies, and invites the user to check the home screen
- "Se ve bien" button saves the value and exits calibration
- Visual feedback: the preview shows the image with a semi-transparent border indicating the crop zone

**Calibration flow**:
```
1. Generate test image with centered crosshair → apply as wallpaper
2. User checks home screen → sees offset
3. Returns to app → adjusts slider (crop inset)
4. Generate new test (with updated crop) → apply as wallpaper
5. Repeat until crosshair appears centered on home screen
6. Save calibrated_inset value
```

**Generator change**: `calibrated_inset > 0` means:
  1. Load background, crop by `inset` px from each side
  2. Resize cropped image to screen dimensions
  3. Compose text centered (which now matches visible area)

**Storage**: `calibrated_inset` (int, SharedPreferences, 0 = no calibration)

- **Pros**: Only approach that genuinely solves the varying-offset problem. Works regardless of launcher. One-time setup. Doesn't require native code changes.
- **Cons**: Requires user to switch between app and home screen multiple times. Slightly clunky UX. Multiple wallpaper applications during calibration.
- **Effort**: Medium

### 2. Enhanced In-App Preview Only

Show the generated wallpaper in a full-screen preview with a movable/resizable "viewport rectangle" overlay. The user adjusts the crop inset visually within the app, without applying to wallpaper.

- **Pros**: Faster feedback loop. No wallpaper switching. Simpler code.
- **Cons**: Does NOT solve the actual problem — the preview can't simulate launcher-specific scroll offset. User calibrates to a wrong target.
- **Effort**: Low-Medium

### 3. Repurpose Existing Offset Slider + Test Button

Make the existing `horizontalOffset` slider more discoverable and add a "Probar" button next to it that generates a test wallpaper with a visual marker and applies it. Same generate-apply-adjust loop but without a dedicated calibration screen.

- **Pros**: Minimal new UI. Leverages existing code.
- **Cons**: The offset shifts text, not the crop — so the text is no longer genuinely centered. Misalignment can still occur on other devices. Doesn't provide a permanent "no calibration needed" state.
- **Effort**: Low

### 4. Native MethodChannel — Attempt to Disable Wallpaper Scrolling

Write a custom MethodChannel that calls Android's `WallpaperManager` with `setWallpaperOffsetSteps(1, 1)` or uses `setBitmap()` with `FLAG_LOCK` to disable scrolling. Combined with screen-sized output, this might eliminate the offset entirely.

- **Pros**: Could fix the root cause for all users without calibration.
- **Cons**: Large native effort. `setWallpaperOffsetSteps()` is only a hint — launchers can ignore it. Different Android versions have different behavior. Still need calibration as fallback.
- **Effort**: High

## Recommendation

**Approach 1: Generate-Apply-Adjust Loop** as the primary strategy, with **Approach 3** (enhanced existing offset) as a complementary quick-win for the current screen.

Why? Because the root cause is **launcher-specific scroll offset**, which is fundamentally unpredictable from within the app. No amount of native API calls will reliably fix it across all devices. Calibration is the only guaranteed solution.

But: calibration requires a dedicated screen and a multi-step UX flow. The existing `horizontalOffset` approach (shift text, apply, check, repeat) is already working for some users — it just lacks a good UI. The proposed calibration is a *superset* of that approach, replacing pixel-shifting with crop-inset and adding structured UX.

### Implementation Plan (High-Level)

**Calibration screen** (`lib/screens/settings/wallpaper_calibration_screen.dart`):
```
┌────────────────────────────────────┐
│  Calibración de Wallpaper          │
│                                    │
│  ┌─────────────────────────────┐   │
│  │   (Preview with mask)       │   │
│  │   ┌───── visible ─────┐     │   │
│  │   │                   │     │   │
│  │   │     +  crosshair  │     │   │
│  │   │                   │     │   │
│  │   └───────────────────┘     │   │
│  └─────────────────────────────┘   │
│                                    │
│  ┌────┤ Inset ├────────────────┐   │
│  │  0px     50px     100px    │   │
│  └──────────────────────────────┘   │
│                                    │
│  [Aplicar y verificar]             │
│  [Guardar — se ve bien]            │
│                                    │
│  Instrucción: ajustá el control    │
│  hasta que el texto se vea centrado│
│  en tu pantalla de inicio.         │
└────────────────────────────────────┘
```

**Test image**: Instead of a verse, generate a centered visual target — a crosshair or a text like "— CENTRO —" — that makes misalignment immediately obvious when the user switches to the home screen.

**Crop inset pipeline** in `WallpaperGenerator._render()`:
```dart
// When calibrated_inset > 0:
// 1. Crop the background BEFORE resize
final cropped = img.copyCrop(background,
    left: inset,
    top: 0,  // vertical crop not needed (scroll is horizontal)
    width: background.width - (inset * 2),
    height: background.height);
// 2. Then resize to screen dimensions
final resized = img.copyResize(cropped, width: screenWidth, height: screenHeight);
```

Note: horizontal-only crop (top/bottom inset always 0) because the offset is horizontal. If vertical misalignment is reported later, the same mechanism extends easily.

**Integration points**:
- In `SettingsProvider`: `calibrated_inset` getter/setter, persists to SharedPreferences
- In `SettingsScreen`: "Calibrar" button visible when `calibrated_inset == 0`
- In `WallpaperGenerator`: new `cropInset` param on `generateAndSetWallpaper()` and `renderOnly()`
- In `wallpaper_scheduler.dart`: read `calibrated_inset` from prefs, pass to generator
- In `main.dart`: optional — redirect to calibration screen on first launch if not calibrated

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| User finds calibration tedious | Medium | Medium | Show clear instructions. Make it optional. Save permanently. |
| Preview accuracy vs real wallpaper | High | Medium | The preview is for guidance only. The "test" button is what actually validates. Explicitly tell the user to check the home screen. |
| Vertical offset also needed | Low | Medium | Design the crop param to support both axes from the start, even if only horizontal is used initially. |
| User changes device (new phone) | Low | Low | Calibration is per-install. Fresh install = no calibration value. User recalibrates. |
| Portrait vs landscape edge cases | Medium | Low | Lock calibration to the current orientation. If the app only supports portrait (verify), no issue. |
| Background isolate also needs calibration | Low | Medium | Scheduler reads `calibrated_inset` from SharedPreferences the same way it reads `horizontal_offset` today. No change needed in the isolate logic. |
| User upgrades from previous version without calibration | Medium | Low | Existing users keep working. No forced calibration. The "Recalibrar" button in Settings is available if they want it. |

## Ready for Proposal

**Yes.** The calibration approach is feasible, solves a real problem that the current screen-size output couldn't fully address, and follows established code patterns.

The proposal should:
1. Define the calibration screen UX flow (test → apply → check → adjust → save)
2. Specify the crop-inset pipeline change in `WallpaperGenerator`
3. Define storage schema (`calibrated_inset` in SharedPreferences)
4. Define integration with existing Settings screen
5. Address the background isolate case (it works as-is by reading prefs)
6. Define the calibration test image (crosshair or centered marker)
7. Add new l10n strings for ES and PT
