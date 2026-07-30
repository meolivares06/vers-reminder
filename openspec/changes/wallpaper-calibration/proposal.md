# Wallpaper Calibration — Proposal

## Problem
After generating wallpapers at exact device screen resolution, some launchers (Moto G56 5G Android 16) still apply a horizontal scroll/crop offset. The offset varies per device/launcher and can't be predicted.

## Solution
One-time calibration screen accessible from Settings:
1. User adjusts a **crop inset** slider (pixels cropped from each side of the background image)
2. Pressiona "Aplicar y verificar" — generates wallpaper with current inset, sets it
3. Checks home screen → returns → adjusts → repeats
4. When satisfied → "Guardar calibración" saves permanently
5. After calibration, `horizontalOffset` remains available for fine-tuning text position

## Files affected
- NEW: `lib/screens/calibration/calibration_screen.dart`
- MODIFY: `lib/services/wallpaper_generator.dart` — add crop logic in `_render()`
- MODIFY: `lib/providers/settings_provider.dart` — add `calibratedInset`
- MODIFY: `lib/screens/settings/settings_screen.dart` — "Recalibrar" button
- MODIFY: `lib/services/wallpaper_scheduler.dart` — pass calibrated inset

## Storage
- Key: `calibrated_inset` (SharedPreferences, int, default 0)
- 0 = no calibration done yet (show prompt in Settings)
- When calibrated: read and apply on every wallpaper generation

## Generator logic (in `_render()`)
```
if (calibratedInset > 0 && calibratedInset < background.width / 2) {
  background = img.copyCrop(
    background,
    x: calibratedInset,
    y: 0,
    width: background.width - (calibratedInset * 2),
    height: background.height,
  );
}
// then continue with existing copyResize + dark overlay + text compositing
```

## Non-goals
- No in-app preview that simulates launcher (unreliable)
- No complex onboarding
- No native code changes
