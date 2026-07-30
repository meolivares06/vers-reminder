# Design: Wallpaper Scheduler

## Technical Approach

A `SettingsProvider` (ChangeNotifier) mediates between UI and persistence — reads/writes `app_config` in SQLite and delegates WorkManager lifecycle to a `WallpaperScheduler` service. The WorkManager callback is a top-level function that re-initializes minimal Flutter bindings, loads config from SQLite, and calls `WallpaperGenerator.generateAndSetWallpaper()` with a filtered random verse. All decisions follow the project's existing singleton + ChangeNotifier + SQLite patterns.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|----------|---------|----------|--------|
| **Schedule engine** | `android_alarm_manager` vs `workmanager` | WorkManager survives Doze/App Standby, is the PRD-recommended choice, and handles re-registration after reboot. | `workmanager` |
| **Config persistence** | SharedPreferences vs SQLite | SQLite keeps scheduler config alongside verse data — one DB, one backup story, consistent migration path. | SQLite `app_config` table |
| **Provider for settings** | Separate provider vs merge into VerseProvider | Single-responsibility: SettingsProvider owns scheduling state, avoids coupling verse CRUD with scheduler lifecycle. | New `SettingsProvider` |
| **WorkManager callback location** | Separate file vs inline in main.dart | Top-level function in a dedicated file (`wallpaper_scheduler.dart`) keeps main.dart clean and allows tree-shaking. | `static callbackDispatcher` in WallpaperScheduler |
| **Category filtering** | SQL WHERE IN vs in-memory filter | SQL is more efficient — single query with randomized sort and category filter. | `db.rawQuery` with JOIN and `ORDER BY RANDOM() LIMIT 1` |

## Data Flow

```
User taps toggle/radio/checkbox
  │
  ▼
SettingsProvider.setEnabled() / setFrequency() / toggleCategory()
  │
  ├── SQLite: app_config (INSERT OR REPLACE)
  │
  └── WallpaperScheduler.registerPeriodic() / cancel()
        │
        ▼
      WorkManager (OS-level periodic task)
        │
        ▼ [on fire]
      callbackDispatcher()
        │
        ├── WidgetsFlutterBinding.ensureInitialized()
        ├── DB: load config + random verse filtered by active categories
        ├── WallpaperGenerator.generateAndSetWallpaper(verse, locale)
        └── Exit
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/providers/settings_provider.dart` | Create | ChangeNotifier managing scheduler state and WorkManager lifecycle |
| `lib/services/wallpaper_scheduler.dart` | Create | Static service wrapping WorkManager register/cancel/callback |
| `lib/screens/settings/settings_screen.dart` | Create | Full settings UI with toggle, frequency, categories, Change Now |
| `lib/main.dart` | Modify | Add SettingsProvider to MultiProvider, init WorkManager |
| `lib/database/database_service.dart` | Modify | Add `_onUpgrade` for v2, `getAppConfig()`, `updateAppConfig()`, `getRandomVerseInCategories()` |
| `pubspec.yaml` | Modify | Add `workmanager` dependency |
| `lib/l10n/app_es.arb` | Modify | Add settings-related strings |
| `lib/l10n/app_pt.arb` | Modify | Add settings-related strings |

## Interfaces / Contracts

```dart
// app_config table (singleton row, id=1)
// { id: 1, scheduler_enabled: 0|1, frequency_minutes: 360, active_category_ids: "[1,3,5]" }

// DatabaseService additions:
Future<Map<String, dynamic>> getAppConfig();
Future<void> updateAppConfig({bool? enabled, int? frequency, List<int>? categoryIds});
Future<Verse?> getRandomVerseInCategories(List<int> categoryIds);

// SettingsProvider
class SettingsProvider extends ChangeNotifier {
  bool isEnabled;
  int frequencyMinutes;
  Set<int> activeCategoryIds;

  Future<void> init();
  Future<void> setEnabled(bool v);      // + WorkManager lifecycle
  Future<void> setFrequency(int min);    // + WorkManager re-register
  Future<void> toggleCategory(int id);   // + SQLite persist
  Future<void> triggerNow();             // immediate wallpaper
}

// WallpaperScheduler
class WallpaperScheduler {
  static Future<void> registerPeriodic(int freqMinutes);
  static Future<void> cancel();
  @pragma('vm:entry-point')
  static Future<void> callbackDispatcher();  // WorkManager entry
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `SettingsProvider` state transitions | Mock DB + Workmanager, verify notifyListeners and side-effects |
| Unit | `DatabaseService.getAppConfig/updateAppConfig` | SQLite in-memory DB, insert + read + update cycle |
| Unit | `getRandomVerseInCategories` filtering | Seed verses in multiple categories, verify filtered random result |
| Widget | `SettingsScreen` rendering | Pump with mock `SettingsProvider`, verify toggle/radio/checkbox states |
| Integration | Full cycle: toggle ON → callback fires → wallpaper set | Requires device/emulator (workmanager needs real OS). Smoke-test only. |

## Migration / Rollout

Database v1 → v2: `onUpgrade` adds the `app_config` table. Since this is development with seed data, an `onUpgrade` is sufficient — no production data to preserve.

## Open Questions

None.
