# Delta for update-install

## ADDED Requirements

### Requirement: Install trigger via FileProvider and intent

**PR 2 — auto-update.** The system MUST declare the FileProvider and install permission in `AndroidManifest.xml`: a `<provider>` using `androidx.core.content.FileProvider` with authority `${applicationId}.fileprovider`, and `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />`. The system MUST expose the updates dir via `res/xml/file_paths.xml`.

When an APK is downloaded and the user taps Install, the system MUST launch an `ACTION_VIEW` intent on the APK via `android_intent_plus` with MIME `application/vnd.android.package-archive` and `FLAG_GRANT_READ_URI_PERMISSION`. If no activity resolves the install intent (no installer available), the system MUST fall back to launching a browser to the release page. If the APK is missing, the system MUST return a failure state WITHOUT launching any intent.

Install updates the app in place and MUST NOT touch `/data/data/{pkg}` — DB, SharedPreferences, `user_background.png`, and `wallpaper_backup/` survive untouched.

#### Scenario: APK present and installer available

- GIVEN the APK exists in the updates dir
- AND an activity resolves the install intent
- WHEN the user taps Install
- THEN the install intent fires
- AND the system installer opens for the APK

#### Scenario: Installer not resolvable

- GIVEN the APK exists in the updates dir
- AND no activity resolves the install intent
- WHEN the user taps Install
- THEN the system opens the release page in a browser instead

#### Scenario: APK missing

- GIVEN the APK does not exist in the updates dir
- WHEN install is attempted
- THEN a failure state is returned
- AND no intent is launched
