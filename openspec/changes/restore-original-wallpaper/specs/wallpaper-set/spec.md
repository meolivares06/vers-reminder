# Delta for Wallpaper Setting

## ADDED Requirements

### Requirement: Get Current Wallpaper

The `vers_reminder/wallpaper` MethodChannel MUST support a `getWallpaper` method that returns the current Android wallpaper as PNG bytes (`Uint8List`). For live wallpapers, it MUST return null.

#### Scenario: Static wallpaper returned as PNG

- GIVEN the user has a static wallpaper set on Android
- WHEN the Dart side calls `getWallpaper` via MethodChannel
- THEN the method reads the wallpaper drawable, compresses it as PNG, and returns the bytes

#### Scenario: Live wallpaper returns null

- GIVEN the user has a live wallpaper set on Android
- WHEN the Dart side calls `getWallpaper`
- THEN the method returns null
- AND no exception is thrown
