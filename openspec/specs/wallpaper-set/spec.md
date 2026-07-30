# Wallpaper Setting Specification

## Purpose

Apply a generated wallpaper image as the device home screen and lock screen wallpaper on Android. Verify the platform supports this operation before executing, and report clear errors when it does not.

## Requirements

### Requirement: Platform Verification

The system MUST verify the current platform is Android before attempting to set the wallpaper. If not Android, it MUST abort with a clear error message.

#### Scenario: Android platform — wallpaper set succeeds

- GIVEN the device is running Android
- WHEN the system receives a request to set the wallpaper
- THEN it MUST proceed to apply the wallpaper to home and lock screens

#### Scenario: Non-Android platform — wallpaper set aborts

- GIVEN the device is NOT running Android (e.g., iOS, web, desktop)
- WHEN the system receives a request to set the wallpaper
- THEN it MUST abort the operation
- AND report an error message indicating wallpaper setting is only supported on Android

### Requirement: Set Home and Lock Screen Wallpaper

On Android, the system MUST set the generated wallpaper image as both the home screen and the lock screen wallpaper simultaneously.

#### Scenario: Set both screens

- GIVEN a valid generated wallpaper image file
- WHEN the system applies the wallpaper
- THEN the home screen MUST display the wallpaper
- AND the lock screen MUST display the same wallpaper
- AND the operation MUST return a success confirmation

#### Scenario: Wallpaper file missing

- GIVEN no valid wallpaper image file exists at the expected path
- WHEN the system attempts to set the wallpaper
- THEN it MUST report an error
- AND MUST NOT attempt to apply a null or missing image

### Requirement: Operation Feedback

The system MUST report the result of the wallpaper operation to the caller, including success confirmation or failure details.

#### Scenario: Successful wallpaper set

- GIVEN the wallpaper was applied successfully
- WHEN the operation completes
- THEN the system MUST return a success status
- AND SHOULD indicate which screens were updated (home and lock)

#### Scenario: Wallpaper set fails

- GIVEN the platform API returns an error (e.g., insufficient permissions)
- WHEN the system attempts to set the wallpaper
- THEN it MUST catch the error
- AND return a failure status with the error details
