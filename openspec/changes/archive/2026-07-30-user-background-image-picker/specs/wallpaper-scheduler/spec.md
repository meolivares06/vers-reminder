# Delta for wallpaper-scheduler

## MODIFIED Requirements

### Requirement: Consistent Background Snapshot for Pre-generation

When `_preGenerateFutureWallpapers()` is called with `useMyWallpaper == true`, the system MUST read `{appDir}/user_background.png` ONCE via `File.readAsBytes()` and reuse those bytes for all 5 pre-generated PNGs in the batch. When `useMyWallpaper` is `false`, the system SHALL use `ImageCacheService.getNextRandomImage()` per wallpaper (unchanged). `setNextPreGenerated()` MUST NOT be modified.

(Previously: read device wallpaper ONCE via `getWallpaper` MethodChannel)

#### Scenario: Pre-generation with user background file

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` exists
- WHEN `_preGenerateFutureWallpapers()` executes
- THEN `{appDir}/user_background.png` MUST be read exactly once
- AND all 5 pre-generated PNGs MUST share the same background photo
- AND each PNG MUST have a different random verse

#### Scenario: Pre-generation with nature images unchanged

- GIVEN `useMyWallpaper` is `false`
- WHEN `_preGenerateFutureWallpapers()` executes
- THEN each pre-generated wallpaper MUST use a random nature image
- AND existing behavior MUST be fully preserved

#### Scenario: Pre-generation fallback on missing file

- GIVEN `useMyWallpaper` is `true` AND `{appDir}/user_background.png` does NOT exist
- WHEN `_preGenerateFutureWallpapers()` executes
- THEN the system MUST fall back to nature images for all 5 PNGs
- AND the fallback reason MUST be logged
