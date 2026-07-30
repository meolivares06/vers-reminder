# Delta for Wallpaper Generation

## ADDED Requirements

### Requirement: Background Source Selection

`generateAndSetWallpaper()`, `_render()`, `renderOnly()`, `renderPreview()`, and `preGenerateWallpapers()` MUST accept a `useMyWallpaper` boolean parameter. When `false`, the system SHALL use `ImageCacheService.getNextRandomImage()` (existing behavior). When `true`, the system SHALL read wallpaper bytes via `getWallpaper` MethodChannel. The `_composite()` method SHALL be called with the resolved bytes regardless of source.

#### Scenario: Nature source selected

- GIVEN `useMyWallpaper` is `false`
- WHEN `generateAndSetWallpaper()` is called
- THEN background bytes MUST come from `ImageCacheService.getNextRandomImage()`
- AND the wallpaper MUST use a random cached nature image

#### Scenario: User wallpaper source selected

- GIVEN `useMyWallpaper` is `true` and `getWallpaper` returns valid PNG bytes
- WHEN `generateAndSetWallpaper()` is called
- THEN background bytes MUST come from `getWallpaper` MethodChannel
- AND the composited wallpaper MUST use the user's device wallpaper

#### Scenario: Preview reflects selected source

- GIVEN `useMyWallpaper` is `true`
- WHEN `renderPreview()` is called
- THEN the preview MUST use `getWallpaper` bytes as its background
- AND the returned PNG MUST visually match a full render at the same settings

### Requirement: Fallback to Nature Images

When `useMyWallpaper` is `true` and `getWallpaper` MethodChannel returns null or throws `PlatformException`, the system MUST fall back to `ImageCacheService.getNextRandomImage()`. The system MUST log the fallback reason and MUST NOT crash. The composited wallpaper SHALL use a nature image as if `useMyWallpaper` were `false`.

#### Scenario: Live wallpaper returns null

- GIVEN `useMyWallpaper` is `true` and the device has a live wallpaper
- WHEN `getWallpaper` returns null
- THEN the system MUST fall back to a nature image
- AND wallpaper generation MUST complete successfully
- AND the fallback reason MUST be logged

#### Scenario: PlatformException during wallpaper read

- GIVEN `useMyWallpaper` is `true` and `getWallpaper` throws `PlatformException`
- WHEN `generateAndSetWallpaper()` is called
- THEN the system MUST catch the exception
- AND fall back to `ImageCacheService.getNextRandomImage()`
- AND the exception details MUST be logged
