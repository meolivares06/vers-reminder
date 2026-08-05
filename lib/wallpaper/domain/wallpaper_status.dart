/// Domain enum for wallpaper generation status.
///
/// Simple enum without payloads. The UI reads [SettingsProvider.statusPayload]
/// for any dynamic content (citation, error detail).
enum WallpaperStatus { idle, generating, updated, error, noCategories }
