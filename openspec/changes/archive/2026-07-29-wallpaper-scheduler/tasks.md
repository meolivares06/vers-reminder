# Tasks: Wallpaper Scheduler

**Delivery Strategy**: exception-ok (size:exception accepted by user)
**400-line budget risk**: High — 7 files created/modified across DB, services, providers, and UI

## Phase 1: Database Layer

- [x] 1.1 Add `workmanager` to pubspec.yaml dependencies
- [x] 1.2 Bump database version to 2 in `_initDatabase()`
- [x] 1.3 Add `_onUpgrade` handler: CREATE TABLE IF NOT EXISTS app_config + INSERT OR IGNORE default row
- [x] 1.4 Rename `_onCreate` references to include app_config table for fresh installs
- [x] 1.5 Implement `getAppConfig()` — returns map with enabled, frequency, categories
- [x] 1.6 Implement `updateAppConfig()` — INSERT OR REPLACE with provided fields
- [x] 1.7 Implement `getVersesByCategoryIds(List<int> ids)` — JOIN with verse_categories, ORDER BY RANDOM() LIMIT 1

## Phase 2: WallpaperScheduler Service

- [x] 2.1 Create `lib/services/wallpaper_scheduler.dart` with `registerPeriodic()` using `Workmanager().registerPeriodicTask`
- [x] 2.2 Implement `cancel()` — `Workmanager().cancelByUniqueName("wallpaperChange")`
- [x] 2.3 Implement `callbackDispatcher()` — top-level function with `@pragma('vm:entry-point')`:
  - Initialize Flutter bindings
  - Open DB, load config
  - If not enabled or no categories → exit
  - Get random verse in active categories
  - Get locale from SharedPreferences
  - Call `WallpaperGenerator.generateAndSetWallpaper()`

## Phase 3: SettingsProvider

- [x] 3.1 Create `lib/providers/settings_provider.dart`:
  - Fields: `_isEnabled`, `_frequencyMinutes`, `_activeCategoryIds`
  - `init()`: load from DB
  - `setEnabled(bool)`: persist + WorkManager register/cancel
  - `setFrequency(int)`: persist + re-register if enabled
  - `toggleCategory(int)`: persist only (no WorkManager side-effect)
  - `triggerNow()`: immediate wallpaper via WallpaperGenerator

## Phase 4: Settings Screen UI

- [x] 4.1 Create `lib/screens/settings/settings_screen.dart`:
  - AppBar with title "Settings" (localized)
  - SwitchListTile for enable/disable
  - RadioListTile group for frequency (disabled when scheduling OFF)
  - CheckboxListTile list for categories
  - ElevatedButton "Change Now"
  - Snackbar when no categories selected on "Change Now"
- [x] 4.2 Add ES/PT strings to ARB files for settings UI

## Phase 5: Integration

- [x] 5.1 Add `SettingsProvider` to `MultiProvider` in `main.dart`
- [x] 5.2 Init `SettingsProvider` in `_initialize()` after locale/verse providers
- [x] 5.3 Initialize WorkManager in `main()`: `Workmanager().initialize(callbackDispatcher, isInDebugMode: false)`
- [x] 5.4 Add navigation entry to Settings screen (e.g., IconButton in VerseListScreen appBar)
- [x] 5.5 Set delivery-strategy metadata in `.opencode/`: `delivery_strategy: exception-ok`

## Verification

- [x] 6.1 Run `flutter analyze` — zero errors
- [x] 6.2 Run `flutter build apk --debug` — builds successfully
- [x] 6.3 Manual smoke test: toggle ON, verify task registered (logcat), verify wallpaper changes
- [x] 6.4 Manual smoke test: toggle OFF, verify task cancelled
- [x] 6.5 Manual smoke test: Change Now with and without categories
