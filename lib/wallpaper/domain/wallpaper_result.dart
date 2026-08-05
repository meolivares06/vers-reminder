/// Domain reason codes for wallpaper generation failures.
///
/// The UI maps each reason to a generic localized error message.
/// Specific details are logged to console, never displayed directly.
enum WallpaperErrorReason {
  /// No verses found for the active locale.
  noVersesForLocale,

  /// No nature background images available in cache.
  backgroundMissing,

  /// File system or storage operation failed.
  storageFailure,

  /// Rendering the composited wallpaper failed.
  renderFailed,
}

/// Sealed result type for wallpaper generation outcomes.
///
/// Use pattern matching to handle each variant:
/// ```dart
/// switch (result) {
///   case WallpaperResultSuccess(:final wallpaperPath):
///     // handle success
///   case WallpaperResultError(:final reason):
///     // handle error
/// }
/// ```
sealed class WallpaperResult {
  const WallpaperResult();
}

/// Wallpaper was generated (and optionally set) successfully.
class WallpaperResultSuccess extends WallpaperResult {
  /// Absolute path to the generated PNG wallpaper file.
  final String wallpaperPath;

  /// The verse text rendered on the wallpaper (locale-specific).
  final String? verseText;

  /// The verse citation (e.g. "Juan 3:16").
  final String? citation;

  const WallpaperResultSuccess(
    this.wallpaperPath, [
    this.verseText,
    this.citation,
  ]);
}

/// Wallpaper generation failed with a domain reason code.
class WallpaperResultError extends WallpaperResult {
  final WallpaperErrorReason reason;

  const WallpaperResultError(this.reason);
}
