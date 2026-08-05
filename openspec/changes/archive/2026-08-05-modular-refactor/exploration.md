# Exploration: modular-refactor — Module Boundary Mapping

## Current State

The codebase is a single-Flutter-package monolith (36 source files, ~5,200 non-generated lines) structured in 9 subdirectories under `lib/`: `database`, `l10n`, `models`, `providers`, `screens`, `services`, `theme`, `widgets`, plus `main.dart`. The directory structure follows a superficial layer convention (`providers/`, `services/`, `screens/`), but **runtime coupling is dense**: `SettingsProvider` (348 lines) directly calls `WallpaperScheduler`, `WallpaperGenerator`, `WallpaperBackupService`, `NotificationService`, and receives `VerseProvider` as a method parameter. There is no event bus, no dependency inversion, and no modular boundaries beyond folder names.

The app architecture is a Provider-based state tree bootstrapped in `main.dart`:
```
MultiProvider
├── VerseProvider     → DatabaseService → sqflite
├── LocaleProvider    → SharedPreferences
└── SettingsProvider  → DatabaseService + WallpaperGenerator + WallpaperScheduler
                       + WallpaperBackupService + NotificationService + SharedPreferences
```

**SettingsProvider is the GOD object.** It owns wallpaper state (status, path, timestamp, permissions), layout preferences (offset, alignment, fontScale, calibratedInset), user background selection, backup tracking, scheduler orchestration, notification state, and pre-generation management — all in one class. This is the primary target for decomposition.

---

## Module Classification Matrix

### File → Module Assignment

| File | Lines | Module | Rationale |
|------|-------|--------|-----------|
| `main.dart` | 115 | `shared` | Composition root — bootstraps all providers & services |
| `database/database_service.dart` | 216 | `shared` | DB infrastructure consumed by verses + wallpaper modules |
| `database/seed_loader.dart` | 51 | `verses` | Seed data — only used at VerseProvider init |
| `l10n/generated/app_localizations.dart` | 678 | `shared` | Generated i18n (auto-generated, treated as shared) |
| `l10n/generated/app_localizations_en.dart` | 256 | `shared` | Generated i18n |
| `l10n/generated/app_localizations_es.dart` | 258 | `shared` | Generated i18n |
| `l10n/generated/app_localizations_pt.dart` | 258 | `shared` | Generated i18n |
| `models/category.dart` | 35 | `shared` | Plain data model — used by verses & wallpaper |
| `models/verse.dart` | 56 | `shared` | Plain data model — used by verses & wallpaper |
| `models/wallpaper_result.dart` | 47 | `shared` | Domain result type — used by wallpaper & settings |
| `models/wallpaper_status.dart` | 5 | `shared` | Domain enum — used by wallpaper, settings, home |
| `models/update_check_result.dart` | 62 | `settings` | Update-specific model — only used by update flow |
| `providers/locale_provider.dart` | 34 | `settings` | Language preference management |
| `providers/settings_provider.dart` | 348 | `wallpaper` | Core wallpaper state machine + settings state (GOD object) |
| `providers/verse_provider.dart` | 53 | `verses` | Verse CRUD operations |
| `screens/home_screen.dart` | 344 | `home` | Home screen + wallpaper card + FAB + navigation |
| `screens/backoffice/category_create_dialog.dart` | 60 | `verses` | Category creation dialog |
| `screens/backoffice/verse_form_screen.dart` | 181 | `verses` | Verse create/edit form |
| `screens/backoffice/verse_list_screen.dart` | 111 | `verses` | Verse list grouped by category |
| `screens/settings/settings_screen.dart` | 655 | `settings` | Settings UI (wallpaper preview, layout, scheduling, categories) |
| `screens/settings/about_screen.dart` | 387 | `settings` | About/update/version/share/contact screen |
| `services/image_cache_service.dart` | 98 | `wallpaper` | Nature image cache for wallpaper backgrounds |
| `services/notification_service.dart` | 55 | `notifications` | Local notification management |
| `services/sweep_utils.dart` | 29 | `shared` | File cleanup utility used by 2 cleanup services |
| `services/temp_cleanup_service.dart` | 55 | `wallpaper` | Temp wallpaper file cleanup |
| `services/update_cleanup_service.dart` | 44 | `settings` | APK download directory cleanup |
| `services/update_service.dart` | 314 | `settings` | App update check/download/install |
| `services/wallpaper_backup_service.dart` | 79 | `backup` | Wallpaper backup/restore |
| `services/wallpaper_generator.dart` | 878 | `wallpaper` | Core wallpaper rendering pipeline |
| `services/wallpaper_scheduler.dart` | 53 | `scheduler` | WorkManager periodic task registration |
| `theme/app_theme.dart` | 27 | `shared` | Theme constants (seed color, gold accent) |
| `widgets/app_version.dart` | 11 | `shared` | Version resolver utility |
| `widgets/async_action_button.dart` | 163 | `shared` | Reusable async button with inline loader |
| `widgets/confirm_delete_dialog.dart` | 33 | `verses` | Delete confirmation dialog (only used by verse list) |
| `widgets/section_header.dart` | 39 | `shared` | Reusable section header (used by settings & about) |
| `widgets/verse_tile.dart` | 48 | `verses` | Verse list tile with swipe-to-delete |

### Module Size Summary (non-generated lines)

| Module | Files | Lines | % |
|--------|-------|-------|---|
| `shared` | 13 (+4 l10n) | 831 (+1,450 l10n) | 16% |
| `wallpaper` | 4 | 1,379 | 26% |
| `settings` | 6 | 1,496 | 29% |
| `verses` | 7 | 537 | 10% |
| `home` | 1 | 344 | 7% |
| `scheduler` | 1 | 53 | 1% |
| `backup` | 1 | 79 | 1.5% |
| `notifications` | 1 | 55 | 1% |
| **Total** | **35 (+4)** | **~5,221** | — |

---

## Cross-Module Dependency Matrix

For each file, every import that crosses a future module boundary (→ target module):

### `main.dart` (shared → *)
| Line | Import | Target Module | Severity |
|------|--------|---------------|----------|
| 10 | `providers/settings_provider.dart` | **wallpaper** | HIGH |
| 11 | `providers/verse_provider.dart` | **verses** | MED |
| 12 | `providers/locale_provider.dart` | **settings** | MED |
| 13 | `screens/home_screen.dart` | **home** | MED |
| 14 | `services/wallpaper_scheduler.dart` | **scheduler** | MED |
| 16 | `services/image_cache_service.dart` | **wallpaper** | LOW |
| 17 | `services/notification_service.dart` | **notifications** | LOW |
| 18 | `services/temp_cleanup_service.dart` | **wallpaper** | LOW |

### `providers/settings_provider.dart` (wallpaper → *)
| Line | Import | Target Module | Severity |
|------|--------|---------------|----------|
| 10 | `services/wallpaper_backup_service.dart` | **backup** | HIGH |
| 12 | `services/wallpaper_scheduler.dart` | **scheduler** | HIGH |
| 13 | `services/notification_service.dart` | **notifications** | HIGH |
| 14 | `providers/verse_provider.dart` | **verses** | HIGH |

### `services/wallpaper_scheduler.dart` (scheduler → *)
| Line | Import | Target Module | Severity |
|------|--------|---------------|----------|
| 8 | `services/wallpaper_generator.dart` | **wallpaper** | HIGH |

### `screens/home_screen.dart` (home → *)
| Line | Import | Target Module | Severity |
|------|--------|---------------|----------|
| 8 | `providers/locale_provider.dart` | **settings** | HIGH |
| 9 | `providers/settings_provider.dart` | **wallpaper** | HIGH |
| 10 | `providers/verse_provider.dart` | **verses** | HIGH |
| 12 | `backoffice/verse_form_screen.dart` | **verses** | MED |
| 13 | `backoffice/verse_list_screen.dart` | **verses** | MED |
| 14 | `settings/settings_screen.dart` | **settings** | MED |

### `screens/backoffice/verse_list_screen.dart` (verses → *)
| Line | Import | Target Module | Severity |
|------|--------|---------------|----------|
| 6 | `providers/locale_provider.dart` | **settings** | LOW |

### `screens/settings/settings_screen.dart` (settings → *)
| Line | Import | Target Module | Severity |
|------|--------|---------------|----------|
| 13 | `providers/settings_provider.dart` | **wallpaper** | HIGH |
| 14 | `providers/verse_provider.dart` | **verses** | HIGH |
| 15 | `services/image_cache_service.dart` | **wallpaper** | MED |
| 17 | `services/wallpaper_backup_service.dart` | **backup** | MED |
| 18 | `services/wallpaper_generator.dart` | **wallpaper** | MED |

**Total cross-module dependencies: 26** (11 HIGH, 10 MED, 5 LOW)

---

## Dependency Graph

```
        ┌─────────────────────────────────────┐
        │             shared                   │
        │  models, theme, DB, widgets, i18n   │
        └──────┬──────┬──────┬──────┬─────────┘
               │      │      │      │
    ┌──────────▼──┐ ┌─▼──────▼──┐ ┌─▼──────────┐
    │  wallpaper  │ │ scheduler │ │   verses    │
    │  (1379 loc) │ │  (53 loc) │ │  (537 loc)  │
    └──┬────┬─────┘ └────┬──────┘ └──┬──────────┘
       │    │            │           │
       │    │    ┌───────▼───┐       │
       │    └───►│  backup   │       │
       │         │  (79 loc) │       │
       │         └───────────┘       │
       │                            │
    ┌──▼───────────┐    ┌───────────▼──────────┐
    │notifications │    │       settings        │
    │  (55 loc)    │    │      (1496 loc)       │
    └──────────────┘    └──┬───────────────────┬┘
                           │                   │
                    ┌──────▼──┐          ┌─────▼────┐
                    │   home   │          │  backup   │
                    │ (344 loc)│          │  (79 loc) │
                    └──────────┘          └──────────┘

Dependencies (module → depends on):
  wallpaper   → backup, scheduler, notifications, verses
  scheduler   → wallpaper
  home        → settings, wallpaper, verses
  verses      → settings
  settings    → wallpaper, verses, backup
```

**THE NEXUS**: `settings_provider.dart` (wallpaper module) has 4 cross-module imports. The `wallpaper` module depends on every module except `home`.

---

## Hidden Coupling — Provider Ownership

### `SettingsProvider` (348 lines) — Owned by wallpaper, violates SRP
This single class manages **8 distinct concerns**:
1. Wallpaper state machine (`_status`, `_statusPayload`, `triggerNow`) — WALLPAPER
2. Wallpaper layout preferences (`horizontalOffset`, `verticalAlignment`, `fontScale`, `calibratedInset`) — SETTINGS
3. User background selection (`useMyWallpaper`, `userBackgroundPath`, `_onMioSelected`) — SETTINGS
4. Scheduler enable/disable/frequency (`isEnabled`, `frequencyMinutes`, `setFrequency`) — SCHEDULER
5. Category selection (`activeCategoryIds`, `toggleCategory`) — VERSES
6. Permission management (`wallpaperPermissionGranted`, `grantWallpaperPermission`) — SETTINGS
7. Pre-generation management (`_isPreGenerating`, `_preGenerateFutureWallpapers`) — WALLPAPER
8. Backup tracking (`hasBackup`, `WallpaperBackupService`) — BACKUP

**Recommendation**: Split into 3 classes:
- `WallpaperState` (wallpaper module): status, trigger, generation, pre-gen
- `SchedulerConfig` (scheduler module): enabled, frequency, category selection, permission
- `AppearanceSettings` (settings module): layout offsets, font scale, background source

### `VerseProvider` (53 lines) — Owned by verses, clean
Only depends on `DatabaseService` (shared) and `SeedLoader` (verses). Good candidate for staying intact.

### `LocaleProvider` (34 lines) — Owned by settings, clean
Only depends on `SharedPreferences`. Pure preference management.

---

## Widget Reuse Analysis

| Widget | Location | Consumed by | Cross-module? |
|--------|----------|-------------|---------------|
| `SectionHeader` | `shared` | `settings_screen.dart` (settings), `about_screen.dart` (settings) | No — both in settings |
| `AsyncActionButton` | `shared` | `settings_screen.dart` (settings), `about_screen.dart` (settings) | No — both in settings |
| `VerseTile` | `verses` | `verse_list_screen.dart` (verses) | No |
| `ConfirmDeleteDialog` | `verses` | `verse_list_screen.dart` (verses) | No |
| `AppVersion` (function) | `shared` | `about_screen.dart` (settings) | No — shared → settings is OK |

**Summary**: All widget reuse happens within module boundaries or from shared → specific. No widget is used across two non-shared modules. Good news — the widget layer is already modularized correctly. `SectionHeader` and `AsyncActionButton` currently only serve the settings/about screens, but are in shared/ for future reuse.

---

## Test File → Module Mapping

| Test File | Target Module |
|-----------|---------------|
| `widget_test.dart` | `shared` (smoke test) |
| `database/database_test.dart` | `shared` (DB infrastructure) |
| `models/category_test.dart` | `shared` |
| `models/verse_test.dart` | `shared` |
| `models/wallpaper_result_test.dart` | `shared` |
| `theme/app_theme_test.dart` | `shared` |
| `theme/dark_mode_test.dart` | `shared` |
| `l10n/ar_parity_test.dart` | `shared` |
| `l10n/locale_test.dart` | `shared` |
| `widgets/app_version_test.dart` | `shared` |
| `widgets/async_action_button_test.dart` | `shared` |
| `providers/verse_provider_test.dart` | `verses` |
| `widgets/verse_list_test.dart` | `verses` |
| `screens/home_screen_test.dart` | `home` |
| `home_ux/wallpaper_card_test.dart` | `home` |
| `providers/settings_provider_test.dart` | `wallpaper` (will need re-filing after split) |
| `services/wallpaper_generator_test.dart` | `wallpaper` |
| `services/wallpaper_backup_service_test.dart` | `backup` |
| `screens/settings_about_update_test.dart` | `settings` |
| `settings_ui/about_screen_test.dart` | `settings` |
| `settings_ui/offset_label_test.dart` | `settings` |
| `settings_ui/preview_caption_test.dart` | `settings` |
| `widgets/settings_background_source_test.dart` | `settings` |
| `widgets/settings_restore_test.dart` | `settings` |
| `services/update_service_test.dart` | `settings` |
| `services/update_cleanup_service_test.dart` | `settings` |
| `services/temp_cleanup_service_test.dart` | `wallpaper` |
| `providers/locale_provider_test.dart` | `settings` |

---

## Event Candidates — For Each Cross-Module Import

Every HIGH-severity cross-module import below MUST be replaced with an event bus message. MED/LOW candidates are recommended but can be deferred.

| # | Source File (module) | Import (target module) | Proposed Event | Payload |
|---|---------------------|----------------------|----------------|---------|
| 1 | `settings_provider.dart` (wallpaper) | `wallpaper_backup_service.dart` (backup) | `BackupOriginalWallpaperRequested` | none → `BackupCompleted(bool)` |
| 2 | `settings_provider.dart` (wallpaper) | `wallpaper_scheduler.dart` (scheduler) | `SchedulerStateChanged` | `{enabled: bool, frequency: int}` |
| 3 | `settings_provider.dart` (wallpaper) | `notification_service.dart` (notifications) | `WallpaperRotationActive` / `WallpaperRotationStopped` | `{body: string}` |
| 4 | `settings_provider.dart` (wallpaper) | `verse_provider.dart` (verses) | `WallpaperGenerationRequested` | `{categoryIds: List<int>, locale: string}` |
| 5 | `wallpaper_scheduler.dart` (scheduler) | `wallpaper_generator.dart` (wallpaper) | `ScheduledWallpaperTick` | none → `NextPreGenConsumed` |
| 6 | `home_screen.dart` (home) | `locale_provider.dart` (settings) | `LocaleChanged` (listen) | `{locale: string}` |
| 7 | `home_screen.dart` (home) | `settings_provider.dart` (wallpaper) | `WallpaperStatusUpdated` (listen) | `{status, path, timestamp}` |
| 8 | `home_screen.dart` (home) | `verse_provider.dart` (verses) | `VersesReloaded` (listen) | `{groupedVerses: Map}` |
| 9 | `home_screen.dart` (home) | `verse_form_screen.dart` (verses) | Navigate via shell/router — not event | — |
| 10 | `home_screen.dart` (home) | `settings_screen.dart` (settings) | Navigate via shell/router — not event | — |
| 11 | `settings_screen.dart` (settings) | `settings_provider.dart` (wallpaper) | `WallpaperStatusUpdated` (listen) + `AppearanceConfig` (model in shared) | — |
| 12 | `settings_screen.dart` (settings) | `verse_provider.dart` (verses) | `VersesReloaded` (listen, for category list) | — |
| 13 | `main.dart` (shared) | all providers | Provider registration — composition root is OK for bootstrapping | — |

**13 cross-module dependencies total** (including MED severity). **8 require event bus replacement** (HIGH severity). **3 are screen navigation** (handled via shell router). **2 are boot-time composition** (acceptable in shared root).

### Event Bus Design Recommendations

Events should follow a **unidirectional** pattern:
- **Commands** (module → bus): `SchedulerStateChanged`, `WallpaperGenerationRequested`, `BackupOriginalWallpaperRequested`, `ScheduledWallpaperTick`
- **Events** (bus → modules): `WallpaperStatusUpdated`, `VersesReloaded`, `LocaleChanged`, `WallpaperRotationActive`, `WallpaperRotationStopped`, `BackupCompleted`, `NextPreGenConsumed`

Each module:
1. Publishes commands to the event bus
2. Subscribes to events from the event bus
3. Never imports another module's internals

---

## Approaches

### 1. **Full Event Bus + Provider Split** (Recommended)
- Split `SettingsProvider` into `WallpaperState`, `SchedulerConfig`, `AppearanceSettings`
- Introduce a lightweight `EventBus` (Stream-based, no external dependency)
- Each module publishes/subscribes to typed events
- Main.dart composes the bus and registers subscribers
- **Pros**: Clean boundaries, testable in isolation, backward-compatible with existing Provider consumers during migration, no new dependencies
- **Cons**: More files (3× providers), event schema must be maintained, migration has intermediate state where old imports coexist with new events
- **Effort**: High (~40 files affected, ~300 lines new event infrastructure, ~500 lines migration)

### 2. **Minimal Module Folders Only**
- Reorganize files into 7 folders + shared without changing imports
- No event bus, no provider split — just folder discipline
- **Pros**: Fast (~2 hours), zero risk, good as first step
- **Cons**: Doesn't reduce coupling, `SettingsProvider` stays the GOD object, no regression protection gain
- **Effort**: Low

### 3. **Phased: Folders First, Events Second**
- Phase 1: Reorganize folders (approach 2)
- Phase 2: Introduce event bus for HIGH-severity cross-module imports only (8 events)
- Phase 3: Split `SettingsProvider` into 3 classes
- **Pros**: Low-risk incremental delivery, each phase is independently shippable and under 400-line review budget
- **Cons**: Takes 3 SDD cycles, folders-only phase doesn't add immediate regression protection
- **Effort**: Medium per phase

---

## Recommendation

**Approach 3: Phased delivery.** Start with folder reorganization (Phase 1) to establish the module boundaries as code. Then introduce the event bus (Phase 2) targeting the 8 HIGH-severity cross-module imports. Finally split `SettingsProvider` (Phase 3). This keeps each PR under 400 lines and lets each phase be verified independently with strict TDD.

Phase breakdown:
1. **Phase 1 — Folder Reorg**: Move files into `modules/{wallpaper,scheduler,verses,home,settings,backup,notifications}/` + `shared/`. Update all import paths. No behavior change. Zero risk.
2. **Phase 2 — Event Bus**: Create `lib/shared/event_bus.dart` (~50 lines). Wire 8 events replacing HIGH cross-module imports. Keep old imports as fallback during transition.
3. **Phase 3 — Provider Split**: Split `SettingsProvider` into `WallpaperState`, `SchedulerConfig`, `AppearanceSettings`. This is the biggest risk but also the biggest gain.

---

## Risks

- **Risk 1 — `wallpaper_scheduler.dart` imports `wallpaper_generator.dart` directly in a background callback**: The WorkManager callback (`callbackDispatcher`) runs in a separate isolate and calls `WallpaperGenerator.instance.setNextPreGenerated()`. This path CANNOT go through an event bus because isolates don't share memory. This coupling is **unavoidable by design** — the scheduler MUST import the generator's static method. Mitigation: keep this one import as a documented exception, or extract `setNextPreGenerated` into a standalone function both modules can import from `shared/`.
- **Risk 2 — Provider tree in main.dart depends on provider types**: Splitting `SettingsProvider` means all `context.watch<SettingsProvider>()` calls break. Migration requires a dual-provider period where old and new providers coexist.
- **Risk 3 — Test files import providers directly**: 27 test files will need import path updates in Phase 1, and provider type changes in Phase 3.
- **Risk 4 — OpenSpec specs are at module level**: The 18 existing spec domains (`wallpaper-gen`, `wallpaper-scheduler`, `verse-storage`, etc.) will need realignment with the new module structure. This is low effort but must be planned.

---

## Ready for Proposal

**Yes** — module boundaries are clearly defined, cross-module imports are fully mapped with line-level precision, and the phased approach provides a safe delivery path. The orchestrator should tell the user:
1. 8 HIGH-severity cross-module imports found across 6 files
2. `SettingsProvider` is the GOD object — must be split into 3 classes
3. 1 unavoidable coupling (scheduler → wallpaper generator via background isolate) requires special treatment
4. Recommend phased delivery: folders first, events second, provider split third
5. Each phase stays under 400-line review budget
