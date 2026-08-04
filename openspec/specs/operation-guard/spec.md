# Operation Guard Specification

## Purpose

Concurrency guards for wallpaper trigger and pre-generation operations. Prevents race conditions on SharedPreferences, database reads, and pre-generated file I/O by ensuring single-entry execution via status checks and mutex tokens.

## Requirements

### OP-GUARD-001: Re-entrancy Guard on Wallpaper Trigger

The `triggerNow` method MUST check `_status` before executing generation logic. When `_status` is `generating`, the method MUST return immediately without proceeding. When `_status` is `error` or `noCategories`, the method SHALL proceed normally, allowing retry after failure.

- **Finding**: F4

#### Scenario: Single trigger proceeds normally

- GIVEN `_status` is not `generating`
- WHEN `triggerNow` is called
- THEN generation proceeds without early return

#### Scenario: Concurrent trigger blocked

- GIVEN a `triggerNow` call is executing with `_status = generating`
- WHEN a second `triggerNow` call arrives before the first completes
- THEN the second call returns immediately
- AND no duplicate SharedPreferences writes or notifyListeners calls occur

#### Scenario: Retry after error allowed

- GIVEN a previous `triggerNow` failed and `_status` is `error`
- WHEN `triggerNow` is called again
- THEN the guard passes and generation proceeds normally

### OP-GUARD-002: Mutual Exclusion for Pre-Generation

The `_preGenerateFutureWallpapers` method MUST use a boolean mutex token that prevents overlapping invocations. The token MUST be set to `true` on entry and reset to `false` in a `finally` block, ensuring cleanup on both success and exception paths.

- **Finding**: F5

#### Scenario: Mutex blocks concurrent call

- GIVEN `_preGenerateFutureWallpapers` is already executing
- WHEN a second invocation is triggered
- THEN the second call returns immediately without starting a new batch

#### Scenario: Mutex reset on success

- GIVEN pre-generation runs to completion
- WHEN the method exits
- THEN the mutex token is reset to `false`

#### Scenario: Mutex reset on exception

- GIVEN pre-generation throws an exception mid-execution
- WHEN the `finally` block executes
- THEN the mutex token is reset to `false`
