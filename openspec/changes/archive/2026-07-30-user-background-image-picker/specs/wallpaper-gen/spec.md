# Delta for wallpaper-gen

## MODIFIED Requirements

### Requirement: Background Source Selection

`generateAndSetWallpaper()`, `_render()`, `renderOnly()`, `renderPreview()`, and `preGenerateWallpapers()` MUST accept a `useMyWallpaper` boolean parameter. When `false`, the system SHALL use `ImageCacheService.getNextRandomImage()` (unchanged). When `true`, the system SHALL read background bytes from `{appDir}/user_background.png` via `File.readAsBytes()`. The `_composite()` method SHALL be called with the resolved bytes regardless of source.

(Previously: read wallpaper bytes via `getWallpaper` MethodChannel when `useMyWallpaper == true`)

#### Scenario: Nature source selected

- GIVEN `useMyWallpaper` is `false`
- WHEN `generateAndSetWallpaper()` is called
- THEN background bytes MUST come from `ImageCacheService.getNextRandomImage()`
- AND the wallpaper MUST use a random cached nature image

#### Scenario: User background file source selected

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` exists
- WHEN `generateAndSetWallpaper()` is called
- THEN background bytes MUST come from `{appDir}/user_background.png`
- AND the composited wallpaper MUST use the user's picked photo

#### Scenario: Preview from user background file

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` exists
- WHEN `renderPreview()` is called
- THEN the preview MUST read bytes from `{appDir}/user_background.png`
- AND the returned PNG MUST visually match a full render at the same settings

### Requirement: Fallback to Nature Images

When `useMyWallpaper` is `true` and `{appDir}/user_background.png` does NOT exist or `File.readAsBytes()` fails, the system MUST fall back to `ImageCacheService.getNextRandomImage()`. The system MUST log the fallback reason and MUST NOT crash. The composited wallpaper SHALL use a nature image as if `useMyWallpaper` were `false`.

(Previously: fall back when `getWallpaper` MethodChannel returns null or throws `PlatformException`)

#### Scenario: User background file missing

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` does not exist
- WHEN `_getBackgroundBytes()` is called
- THEN the system MUST fall back to a nature image
- AND wallpaper generation MUST complete successfully
- AND the fallback reason MUST be logged

#### Scenario: File read fails

- GIVEN `useMyWallpaper` is `true` AND `File.readAsBytes()` throws an exception
- WHEN `_getBackgroundBytes()` is called
- THEN the system MUST catch the exception
- AND fall back to `ImageCacheService.getNextRandomImage()`
- AND the exception details MUST be logged

## REMOVED Requirements

### Requirement: getWallpaper MethodChannel

(Reason: `getWallpaper` MethodChannel is no longer called — Android 13+ blocks `WallpaperManager.getDrawable()` on API 33+. Replaced by file-based read from `{appDir}/user_background.png`.)
(Migration: Remove `getWallpaper` block from `MainActivity.kt` MethodChannel handler. Keep `suggestDesiredDimensions` in the channel.)
