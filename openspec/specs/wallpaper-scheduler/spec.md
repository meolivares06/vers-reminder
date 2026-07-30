# Wallpaper Scheduler

## Description
Background scheduling service that periodically changes the device wallpaper to a random verse. Uses `workmanager` for reliable periodic execution respecting Android battery policies.

## Requirements

### R-WS-001: Periodic Execution
The system SHALL register a periodic WorkManager task that executes at the user-configured frequency.

### R-WS-002: Frequency Options
The system SHALL support these fixed frequencies: 30min, 1h, 3h, 6h, 12h, 24h. Default SHALL be 6 hours (360 minutes).

### R-WS-003: Task Execution Flow
When the WorkManager callback fires, the system SHALL:
1. Load app configuration from SQLite
2. If `scheduler_enabled` is false, SHALL exit without action
3. If no active categories are configured, SHALL exit without action
4. Query a random verse that belongs to at least one active category
5. Generate wallpaper via `WallpaperGenerator`
6. Set the wallpaper

### R-WS-004: Cancel on Disable
When the user disables scheduling, the system SHALL cancel ALL registered WorkManager tasks immediately.

### R-WS-005: Re-register on Frequency Change
When the user changes frequency while enabled, the system SHALL cancel the existing task and register a new one with the updated interval.

### R-WS-006: Startup Initialization
On app startup, if scheduling is enabled in SQLite config, the system SHALL re-register the WorkManager task with the persisted frequency. This ensures tasks survive device reboot.

### R-WS-007: No Categories — Auto-Pause
If all categories are deselected while scheduling is enabled, the periodic task SHALL still fire but exit early (no wallpaper change). The user does NOT need to manually disable scheduling.

### R-WS-008: Single Instance Row
The `app_config` table SHALL contain exactly one row (`id = 1`). Inserts MUST use `INSERT OR REPLACE` or equivalent to enforce the singleton constraint.

## Scenarios

### Scenario WS-01: Enable scheduling
Given the user is on Settings screen
When the user toggles scheduling ON
Then a periodic WorkManager task is registered with the selected frequency
And `scheduler_enabled` is persisted as `1` in `app_config`

### Scenario WS-02: Disable scheduling
Given scheduling is active
When the user toggles scheduling OFF
Then all WorkManager tasks are cancelled
And `scheduler_enabled` is persisted as `0` in `app_config`

### Scenario WS-03: Change frequency while active
Given scheduling is ON at 6h frequency
When the user selects 1h frequency
Then the existing WorkManager task is cancelled
And a new task is registered with 60-minute interval
And `frequency_minutes` is persisted as `60`

### Scenario WS-04: WorkManager callback with categories
Given scheduling is ON with active categories [1, 3]
When the WorkManager callback fires
Then a random verse in categories [1, 3] is selected
And a wallpaper is generated and set

### Scenario WS-05: WorkManager callback without categories
Given scheduling is ON but all categories are deselected
When the WorkManager callback fires
Then the callback exits without changing the wallpaper

### Scenario WS-06: App restart with enabled scheduling
Given scheduling was ON before app close
When the app starts
Then the WorkManager task is re-registered with the persisted frequency

### Scenario WS-07: "Change Now" with categories
Given scheduling may be ON or OFF
When the user taps "Change Now"
And at least one category is active
Then a random verse in active categories is selected
And a wallpaper is generated and set immediately
And scheduling state is NOT modified

### Scenario WS-08: "Change Now" without categories
Given no categories are active
When the user taps "Change Now"
Then a message is shown: "Select at least one category first"
