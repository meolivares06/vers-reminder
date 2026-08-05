# event-bus Specification

## Purpose

Lightweight typed event infrastructure for inter-module communication. Replaces cross-module direct imports with publish/subscribe via Dart Streams. Zero external dependencies.

## Requirements

| # | Requirement | Strength |
|---|-----------|----------|
| R1 | Typed event lifecycle: `on<T>()` subscribe, `emit<T>()` dispatch | MUST |
| R2 | Handler error isolation: one handler failure SHALL NOT prevent other handlers | MUST |
| R3 | Handlers execute in registration order within each event type | MUST |

### R1: Typed Event Lifecycle

The system MUST provide `on<T>(void Function(T) handler)` for subscription and `emit<T>(T event)` for dispatch. A handler registered for type `T` SHALL only receive events of type `T`.

#### Scenario: Happy path — emit reaches matching handler

- GIVEN a handler registered via `on<WallpaperStatusUpdated>(handler)`
- WHEN `emit(WallpaperStatusUpdated(status: "ready"))` is called
- THEN the handler receives the event with `status == "ready"`
- AND no handler registered for a different type is invoked

#### Scenario: No handler registered

- GIVEN no handler is registered for type `LocaleChanged`
- WHEN `emit(LocaleChanged(locale: "pt"))` is called
- THEN no error is thrown
- AND the emit call completes silently

### R2: Handler Error Isolation

When multiple handlers are registered for the same event type and one throws, the remaining handlers MUST still execute. The system SHALL NOT let one handler's exception abort the dispatch chain.

#### Scenario: Second handler throws, third still executes

- GIVEN three handlers registered for `SchedulerStateChanged` in order: A, B, C
- AND handler B throws a `StateError`
- WHEN `emit(SchedulerStateChanged(enabled: true))` is called
- THEN handler A executes successfully
- AND handler B's exception is caught (not propagated to caller)
- AND handler C executes successfully

#### Scenario: All handlers throw, emit does not crash

- GIVEN two handlers registered for `VersesReloaded`, both throwing
- WHEN `emit(VersesReloaded(...))` is called
- THEN both exceptions are caught
- AND emit returns normally

### R3: Registration-Order Execution

Handlers registered for a given event type MUST execute in the order they were registered. Later registrations SHALL NOT preempt earlier ones.

#### Scenario: Order preserved across registrations

- GIVEN handler A registered, then handler B registered, both for `BackupRestored`
- WHEN `emit(BackupRestored())` is called
- THEN handler A executes before handler B
