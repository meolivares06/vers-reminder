# Error Handling Specification

## Purpose

Defensive error observability for image module operations. Guarantees exceptions in wallpaper rendering, async callback execution, isolate compute, and post-dispose widget notifications are logged rather than silently swallowed.

## Requirements

### Requirement: renderOnly Error Logging

The `renderOnly` method MUST catch exceptions from `picture.toImage()` and `image.toByteData()` and pass them to `debugPrint` before returning null. The method SHALL NOT throw — null is the safe fallback.

- **Finding**: F8

#### Scenario: Successful render returns image bytes

- GIVEN a valid `PictureRecorder` and `Size`
- WHEN `renderOnly` is called
- THEN `picture.toImage()` produces a `ui.Image`
- AND `image.toByteData()` returns raw PNG bytes
- AND the method returns `Uint8List`

#### Scenario: Render failure logs error and returns null

- GIVEN `picture.toImage()` throws a rendering exception
- WHEN `renderOnly` catches the exception
- THEN `debugPrint` logs the error type, message, and stack trace
- AND the method returns `null`

#### Scenario: Null safety — no throw on failure

- GIVEN any exception during `renderOnly` execution
- WHEN the catch block executes
- THEN the method MUST NOT throw an unhandled exception
- AND callers receive `null` as the safe signal

### Requirement: triggerNow Async Error Boundary

Unawaited `triggerNow` calls initiated from dialog callbacks and UI event handlers MUST wrap the async body in `try/catch`. Exceptions from wallpaper generation, SharedPreferences writes, or `notifyListeners` SHALL be caught and logged via `debugPrint` rather than becoming unhandled async exceptions.

- **Finding**: F9

#### Scenario: Dialog-triggered generation exception logged

- GIVEN a settings dialog triggers `settings.triggerNow(...)`
- WHEN wallpaper generation throws inside the async body
- THEN the exception MUST be caught by a surrounding `try/catch`
- AND `debugPrint` logs the error type and message
- AND no unhandled exception reaches the zone error handler

#### Scenario: _triggerNow body always catches

- GIVEN the `_triggerNow` VoidCallback fires a generation event
- WHEN the VoidCallback body throws synchronously
- THEN `debugPrint` logs the exception with stack trace
- AND the callback does not crash the widget tree

#### Scenario: Normal execution produces no error log

- GIVEN wallpaper generation completes successfully
- WHEN the `triggerNow` callback body finishes without exception
- THEN no error is logged
- AND `notifyListeners` fires normally

### Requirement: Compute Fallback Error Logging

The PNG encode `compute` call MUST catch isolate failures and pass the original exception to `debugPrint` before falling back to the synchronous `_encodePngWorker`. The fallback SHALL preserve caller-visible behavior — return a valid `Uint8List` from the sync path.

- **Finding**: F10

#### Scenario: Isolate failure logged before sync fallback

- GIVEN the `compute(_encodePngWorker, image)` isolate invocation throws
- WHEN the catch block executes
- THEN `debugPrint` logs the original isolate error and stack trace
- AND `_encodePngWorker(image)` is called synchronously as fallback
- AND the caller receives the sync-encoded PNG bytes

#### Scenario: Successful isolate encode skips log and fallback

- GIVEN `compute(_encodePngWorker, image)` completes successfully
- WHEN the result is returned
- THEN no error is logged
- AND the sync fallback path is never entered

### Requirement: Dispose Guard on notifyListeners

`ChangeNotifier` subclasses that call `notifyListeners()` after asynchronous gaps MUST check a `_disposed` flag before notifying. The flag MUST be set to `true` in `dispose()` before calling `super.dispose()`.

- **Finding**: F11

#### Scenario: notifyListeners skipped after dispose

- GIVEN a provider has `_disposed = false`
- WHEN `dispose()` is called and `_disposed` is set to `true`
- AND an in-flight async operation completes and calls `notifyListeners()`
- THEN the `if (!_disposed)` guard prevents the notification
- AND no framework assertion fires

#### Scenario: notifyListeners proceeds when alive

- GIVEN `_disposed` is `false`
- WHEN an async operation completes and calls `notifyListeners()`
- THEN the guard allows `super.notifyListeners()` to execute
- AND registered listeners receive the update

#### Scenario: dispose sets flag before super.dispose

- GIVEN a provider is being disposed
- WHEN `dispose()` executes
- THEN `_disposed = true` MUST be set before `super.dispose()`
- AND any subsequent `notifyListeners()` call is blocked
