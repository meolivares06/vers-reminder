/// Result of a version check against GitHub Releases.
///
/// Models the outcomes the [UpdateService] can surface to the UI:
/// - an update is available (with the info needed to download/install it),
/// - the app is already up to date,
/// - or the check failed (network error, malformed tag, missing asset).
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.available,
    this.tagName,
    this.downloadUrl,
    this.assetName,
    this.sizeBytes,
    this.error,
  });

  /// Whether a newer release exists and can be downloaded.
  final bool available;

  /// The remote tag, e.g. `v1.2.0+1` (null when not available).
  final String? tagName;

  /// The arm64 asset `browser_download_url` from the release JSON.
  final String? downloadUrl;

  /// The arm64 asset file name, e.g. `vers-reminder-arm64-v1.2.0.apk`.
  final String? assetName;

  /// The asset size in bytes, when reported by the release JSON.
  final int? sizeBytes;

  /// Human-readable failure message when [available] is false due to an error.
  final String? error;

  factory UpdateCheckResult.empty() => const UpdateCheckResult(available: false);

  factory UpdateCheckResult.failure(String message) =>
      UpdateCheckResult(available: false, error: message);
}

/// Lightweight parse model for the GitHub `/releases/latest` response.
///
/// Only the fields the update flow needs are kept; unknown JSON keys are
/// ignored. The `#fromJson` factories are defensive — a missing or malformed
/// field yields null rather than throwing, so the caller can report a clean
/// failure state.
class GithubRelease {
  final String? tagName;
  final List<GithubAsset> assets;

  const GithubRelease({this.tagName, this.assets = const []});

  factory GithubRelease.fromJson(Map<String, dynamic> json) => GithubRelease(
        tagName: json['tag_name'] as String?,
        assets: (json['assets'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(GithubAsset.fromJson)
                .toList() ??
            const [],
      );
}

/// A single release asset from the GitHub API.
class GithubAsset {
  final String? name;
  final String? browserDownloadUrl;
  final int? size;

  const GithubAsset({this.name, this.browserDownloadUrl, this.size});

  factory GithubAsset.fromJson(Map<String, dynamic> json) => GithubAsset(
        name: json['name'] as String?,
        browserDownloadUrl: json['browser_download_url'] as String?,
        size: json['size'] as int?,
      );
}
