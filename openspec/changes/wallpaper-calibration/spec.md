# Wallpaper Calibration — Spec

## REQ-CALIBRATION-001: Calibration Screen
The app MUST provide a calibration screen accessible from Settings ("Calibrar pantalla") that shows:
- Current crop inset value (number)
- A slider (0 to max where max = half the smaller image dimension)
- "Aplicar y verificar" button to generate + set wallpaper with current inset
- "Guardar calibración" button to persist the value
- Hint text explaining the process

## REQ-CALIBRATION-002: Crop Inset
The generator MUST horizontally crop the background image by `inset` pixels from each side BEFORE resizing to screen dimensions. The crop MUST preserve the vertical center (crop y=0, full height).

## REQ-CALIBRATION-003: Persistence
The calibrated inset MUST be saved in SharedPreferences as `calibrated_inset` (int). Default 0 = not calibrated. Once saved, it's used for ALL wallpaper generations (UI thread and background isolate).

## REQ-CALIBRATION-004: Settings Integration
The Settings screen MUST show:
- "Calibrar pantalla" button (if not calibrated: prominent, if calibrated: "Recalibrar")
- The current calibrated inset value when calibrated

## REQ-CALIBRATION-005: Existing offset preserved
The existing `horizontalOffset` setting MUST continue to work alongside `calibratedInset`. Calibration adjusts the image, offset adjusts the text position.

## Scenarios

1. User opens calibration screen, slider at 0 → generates → offset visible (same as before)
2. User adjusts to 50 → generates → wallpaper generated with 50px crop each side
3. User checks home screen → text more centered → saves
4. User returns later → "Recalibrar" → adjusts → saves again
5. Background scheduler generates wallpaper using saved calibrated inset
