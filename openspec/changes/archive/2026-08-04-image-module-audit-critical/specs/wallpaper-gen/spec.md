# Delta for Wallpaper Generation

## ADDED Requirements

### Requirement: Non-Blocking Startup Pre-Generation

The system MUST NOT block the app loading state on wallpaper pre-generation. After reading configuration and preferences, `_isLoading` MUST be set to `false` and listeners notified BEFORE launching pre-generation. Pre-generation of future wallpapers MUST execute as a fire-and-forget operation with its own `try/catch` error boundary. Pre-generation failures MUST be logged but MUST NOT prevent the app from loading or entering a usable state.

#### Scenario: Loading indicator dismissed before pre-generation completes

- GIVEN `SettingsProvider.init()` is called on first launch with scheduler enabled
- WHEN configuration and preferences are loaded
- THEN `_isLoading` MUST be set to `false` before `_preGenerateFutureWallpapers()` is launched
- AND the loading spinner MUST disappear while pre-generation runs in background

#### Scenario: Pre-generation failure does not block app

- GIVEN `_preGenerateFutureWallpapers()` is launched fire-and-forget
- WHEN pre-generation throws (e.g., no cached images, file system error)
- THEN the exception MUST be caught within the fire-and-forget error boundary
- AND the app MUST remain loaded and interactive
- AND the failure MUST be logged to console

#### Scenario: Pre-generation skipped when scheduler is disabled

- GIVEN `SettingsProvider.init()` is called AND wallpaper scheduler is disabled
- WHEN configuration is loaded
- THEN `_isLoading` MUST be set to `false` immediately after config load
- AND `_preGenerateFutureWallpapers()` MUST NOT be called
