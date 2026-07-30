# Delta for Wallpaper Scheduler

## ADDED Requirements

### Requirement: Consistent Background Snapshot for Pre-generation

When `_preGenerateFutureWallpapers()` is called with `useMyWallpaper == true`, the system MUST read the device wallpaper ONCE via `getWallpaper` MethodChannel and reuse those bytes for all 5 pre-generated PNGs in the batch. When `useMyWallpaper` is `false`, the system SHALL use `ImageCacheService.getNextRandomImage()` per wallpaper (existing behavior). `setNextPreGenerated()` MUST NOT be modified.

#### Scenario: Pre-generation with user wallpaper

- GIVEN `useMyWallpaper` is `true` and `getWallpaper` returns valid bytes
- WHEN `_preGenerateFutureWallpapers()` executes
- THEN `getWallpaper` MUST be called exactly once
- AND all 5 pre-generated PNGs MUST share the same background snapshot
- AND each PNG MUST have a different random verse

#### Scenario: Pre-generation with nature images unchanged

- GIVEN `useMyWallpaper` is `false`
- WHEN `_preGenerateFutureWallpapers()` executes
- THEN each pre-generated wallpaper MUST use a random nature image
- AND existing behavior MUST be fully preserved

#### Scenario: Pre-generation fallback on null wallpaper

- GIVEN `useMyWallpaper` is `true` and `getWallpaper` returns null
- WHEN `_preGenerateFutureWallpapers()` executes
- THEN the system MUST fall back to nature images for all 5 PNGs
- AND the fallback reason MUST be logged
