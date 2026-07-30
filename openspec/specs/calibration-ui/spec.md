# Calibration UI Specification

## Purpose

Provide a real-time wallpaper preview inside the calibration screen so users see compositing changes immediately as they adjust the crop inset slider, eliminating the generate→apply→check→adjust loop.

## Requirements

### Requirement: Live Preview on Slider Change

The calibration screen MUST display a real-time preview image that updates as the user drags the crop inset slider. The preview MUST render at approximately one-quarter screen resolution via `WallpaperGenerator.renderPreview()`. Slider changes MUST be debounced by 300ms before a new preview is requested. The preview MUST appear within 500ms of the last slider movement on typical devices.

#### Scenario: Preview updates after slider drag

- GIVEN the calibration screen is displayed with a verse selected
- WHEN the user drags the inset slider to a new value and stops
- THEN after 300ms of no slider movement, a new preview MUST be requested
- AND the preview image MUST update to reflect the new inset value
- AND the preview MUST complete within 500ms of the last slider movement

#### Scenario: Rapid slider changes debounce correctly

- GIVEN the user is rapidly dragging the slider back and forth
- WHEN multiple `onChanged` events fire within 300ms
- THEN only ONE preview request SHALL be made after the last event
- AND no stale intermediate previews SHALL appear

#### Scenario: Preview requests a first render on screen open

- GIVEN the calibration screen has just opened
- WHEN `_previewBytes` is null after build
- THEN a preview SHALL be automatically requested with the current inset value
- AND a loading indicator or placeholder SHALL be shown until the preview bytes arrive

### Requirement: Full-Resolution Apply Preserved

The "Aplicar y verificar" button MUST generate and set the wallpaper at full screen resolution using the existing `generateAndSetWallpaper()` pipeline. Full-resolution generation MUST NOT block the preview from updating. The preview SHALL remain visible during generation.

#### Scenario: Full-res generate while preview is shown

- GIVEN a preview is currently displayed
- WHEN the user taps "Aplicar y verificar"
- THEN the full-resolution wallpaper generation MUST proceed
- AND the preview SHALL remain visible during generation
- AND the status card SHALL show the generation progress as before

### Requirement: Preview Error Resilience

If `renderPreview()` returns null, the existing preview image SHALL remain unchanged. If no preview has ever been rendered, a placeholder SHALL be shown instead of a broken image. Preview errors MUST NOT affect the full-resolution generation path.

#### Scenario: Preview fails mid-session

- GIVEN a preview was previously displayed
- WHEN `renderPreview()` returns null
- THEN the previous preview SHALL remain on screen
- AND a warning SHALL be logged to console
- AND the "Aplicar y verificar" button MUST remain functional

#### Scenario: Initial preview unavailable

- GIVEN the calibration screen just opened
- WHEN the first `renderPreview()` call returns null
- THEN a placeholder container or loading indicator SHALL be displayed
- AND no error state must propagate to the user
