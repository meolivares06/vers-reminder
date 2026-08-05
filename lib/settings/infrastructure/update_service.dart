import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import 'package:vers_reminder/settings/infrastructure/update_check_result.dart';
import 'package:vers_reminder/settings/infrastructure/update_cleanup_service.dart';

/// Compares a GitHub release tag against the installed app version.
///
/// The remote tag is expected to look like `v1.2.0+1` (leading `v`, optional
/// `+build` suffix). The local version/build come from `package_info_plus`
/// (`version` = "1.2.0", `buildNumber` = "1").
///
/// Returns:
/// - `> 0` when the remote release is newer,
/// - `0` when they are equal (or indeterminate),
/// - `< 0` when the remote release is older.
int compareVersions(String remoteTag, String localVersion, String localBuild) {
  final tagNoV = remoteTag.startsWith('v') ? remoteTag.substring(1) : remoteTag;
  final remoteParts = tagNoV.split('+');
  final remoteVer =
      remoteParts[0].split('.').map((s) => int.tryParse(s)).toList();
  final remoteBuild =
      remoteParts.length > 1 ? int.tryParse(remoteParts[1]) ?? 0 : 0;

  final localVer = localVersion.split('.').map((s) => int.tryParse(s)).toList();
  final localBuildNum = int.tryParse(localBuild) ?? 0;

  for (var i = 0; i < 3; i++) {
    final r = (remoteVer.length > i ? remoteVer[i] : 0) ?? 0;
    final l = (localVer.length > i ? localVer[i] : 0) ?? 0;
    if (r != l) return r - l;
  }

  return remoteBuild - localBuildNum;
}

/// Fetches, downloads and installs app updates from GitHub Releases.
///
/// Singleton pattern matching other services in the app. The [http.Client]
/// and version values are injectable so tests can stub the network and the
/// current version without platform channels.
class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  static const String _apiUrl =
      'https://api.github.com/repos/meolivares06/vers-reminder/releases/latest';
  static const String _authority = 'com.versreminder.vers_reminder.fileprovider';
  static const String _installMime = 'application/vnd.android.package-archive';

  /// Checks GitHub for a newer release than the installed version.
  ///
  /// Returns an [UpdateCheckResult]. Network errors, malformed tags and
  /// missing assets are reported as a failure state (never thrown).
  Future<UpdateCheckResult> checkForUpdate({
    http.Client? client,
    String? versionOverride,
    String? buildOverride,
  }) async {
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.get(Uri.parse(_apiUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return UpdateCheckResult.failure(
            'GitHub API returned HTTP ${response.statusCode}');
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) {
        return UpdateCheckResult.failure('Unexpected GitHub API payload');
      }
      final release = GithubRelease.fromJson(json);

      final tag = release.tagName;
      if (tag == null || tag.trim().isEmpty) {
        return UpdateCheckResult.failure('Release has no tag_name');
      }

      // Parse tag semantically — a malformed tag (e.g. "latest") is a failure.
      // NOTE: this validation mirrors the tag parsing inside [compareVersions];
      // the two must stay in sync (same `v`-strip and `+`-build split) so the
      // pre-flight check and the actual comparison agree on what a valid tag
      // looks like.
      final tagNoV =
          tag.startsWith('v') ? tag.substring(1) : tag;
      final major =
          int.tryParse(tagNoV.split('+').first.split('.').firstOrNull ?? '');
      if (major == null) {
        return UpdateCheckResult.failure('Malformed release tag: $tag');
      }

      // Find the arm64 APK asset.
      final arm64 = release.assets
          .where(
            (a) =>
                a.browserDownloadUrl != null &&
                a.browserDownloadUrl!.toLowerCase().contains('arm64') &&
                (a.name?.toLowerCase().endsWith('.apk') ?? false),
          )
          .firstOrNull;
      if (arm64 == null || arm64.browserDownloadUrl == null) {
        return UpdateCheckResult.failure('Release has no arm64 APK asset');
      }

      String version = versionOverride ?? '';
      String buildNumber = buildOverride ?? '';
      if (version.isEmpty || buildNumber.isEmpty) {
        final (currentVersion, currentBuild) = await _currentVersion();
        if (version.isEmpty) version = currentVersion;
        if (buildNumber.isEmpty) buildNumber = currentBuild;
      }

      if (compareVersions(tag, version, buildNumber) <= 0) {
        return UpdateCheckResult.empty();
      }

      return UpdateCheckResult(
        available: true,
        tagName: tag,
        downloadUrl: arm64.browserDownloadUrl,
        assetName: arm64.name,
        sizeBytes: arm64.size,
      );
    } catch (e) {
      return UpdateCheckResult.failure('Update check failed: $e');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Downloads the release APK into the dedicated updates dir (streaming).
  ///
  /// Stale APKs are cleared first via [UpdateCleanupService]. Reports
  /// [onProgress] with bytes/total while streaming. On failure the partial
  /// file is deleted and the error is rethrown. Returns the local APK path.
  Future<String> download(
    UpdateCheckResult release, {
    void Function(int bytes, int total)? onProgress,
    http.Client? client,
    String? appSupportOverride,
  }) async {
    final url = release.downloadUrl;
    final assetName = release.assetName;
    if (url == null || assetName == null) {
      throw StateError('UpdateCheckResult has no download URL or asset name');
    }

    // assetName comes from the untrusted release JSON; only the basename is
    // used so a crafted value (e.g. "../../escape.apk") cannot traverse out of
    // the dedicated updates dir. `.` and `..` (and empty) resolve to the dir
    // itself or its parent, so they are rejected outright.
    final safeName = p.basename(assetName);
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      throw StateError('Release asset name is not a file: "$assetName"');
    }

    final httpClient = client ?? http.Client();
    final updatesDir = await UpdateCleanupService.instance
        .updatesDir(appSupportOverride: appSupportOverride);
    // Clear stale APKs before writing.
    await UpdateCleanupService.instance
        .cleanUpdatesDir(appSupportOverride: appSupportOverride);

    final destPath = p.join(updatesDir, safeName);
    final dest = File(destPath);

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await httpClient.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Download failed with status ${response.statusCode}');
      }

      final total = response.contentLength ?? release.sizeBytes ?? 0;
      final sink = dest.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress(received, total);
          }
        }
        await sink.flush();
        // The GitHub CDN URL encodes `+` in the tag as `%2B`. The final
        // progress callback guards against total == 0 (a zero-length or
        // unknown-length response) by reporting 1/1 so callers never divide
        // by zero when normalizing `bytes / total`.
        if (onProgress != null) onProgress(received, received == 0 ? 1 : received);
      } finally {
        await sink.close();
      }

      return destPath;
    } catch (e) {
      // Write happened via writeSink; delete any partial file defensively.
      // The real cause is logged so a failed download is distinguishable in
      // debug logs, but it is never surfaced verbatim to the user (the UI
      // shows a clean localized message).
      debugPrint('UpdateService.download failed: $e');
      if (await dest.exists()) {
        try {
          await dest.delete();
        } catch (_) {
          // Ignore — defensive delete.
        }
      }
      rethrow;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Triggers the Android install flow for a downloaded APK.
  ///
  /// Returns `true` when the system install flow was handed off to an activity
  /// that will install the APK (i.e. the system installer opened, or the
  /// browser opened against [releaseUrl]). Returns `false` when nothing will
  /// install: the APK is missing, no activity resolves any intent, or an
  /// unexpected error interrupted the flow.
  ///
  /// NOTE: "an intent fired" is NOT equivalent to "returned true". When the
  /// installer launch fails (e.g. missing "Install unknown apps" permission),
  /// a deep-link to the `MANAGE_UNKNOWN_APP_SOURCES` settings screen IS
  /// launched, but the method still returns `false` because the install will
  /// not proceed without the user granting the permission there. Callers must
  /// treat a `false` return as "no install happened" and show a recovery path
  /// (e.g. a Retry action), not necessarily "nothing was shown".
  ///
  /// Falls back to opening [releaseUrl] (the release page, not the APK URL) in
  /// a browser when no system installer resolves the install intent. When the
  /// installer is present but its launch throws, the deep-link above is tried.
  ///
  /// Any exception thrown by the platform plumbing (including
  /// `canResolveActivity`) is converted into a `false` return — this method
  /// never throws, so callers always reach a recoverable state.
  ///
  /// [intentLauncherFactory] is a test-only seam: it lets tests stub
  /// resolve/launch without a real Android platform (`android_intent_plus`
  /// hard-codes a local platform check, so its intents are inert off-device).
  /// When omitted, intents are resolved/launched through `android_intent_plus`
  /// as usual.
  Future<bool> install(
    String apkPath, {
    String? releaseUrl,
    @visibleForTesting
    IntentLauncher Function(AndroidIntent intent)? intentLauncherFactory,
  }) async {
    try {
      if (!await File(apkPath).exists()) return false;

      final launcherOf = intentLauncherFactory ?? AndroidIntentLauncher.new;

      final fileName = p.basename(apkPath);
      final contentUri = 'content://$_authority/updates/$fileName';

      final installIntent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: contentUri,
        type: _installMime,
        flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION],
      );

      final canHandle = await launcherOf(installIntent).canResolveActivity();
      if (canHandle != true) {
        // No installer available — open the release page in a browser.
        final browser = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: releaseUrl ??
              'https://github.com/meolivares06/vers-reminder/releases/latest',
        );
        final browserLauncher = launcherOf(browser);
        if (await browserLauncher.canResolveActivity() != true) return false;
        try {
          await browserLauncher.launch();
          return true;
        } catch (e) {
          debugPrint('UpdateService.browser fallback launch failed: $e');
          return false;
        }
      }

      try {
        await launcherOf(installIntent).launch();
        return true;
      } catch (e) {
        // Launch failed — likely missing "Install unknown apps" permission.
        // Log the real cause but keep user copy clean.
        debugPrint('UpdateService.install launch failed: $e');
        final settingsIntent = AndroidIntent(
          action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
          data: 'package:com.versreminder.vers_reminder',
        );
        try {
          await launcherOf(settingsIntent).launch();
        } catch (e2) {
          debugPrint('UpdateService.unknown-app-sources launch failed: $e2');
        }
        return false;
      }
    } catch (e) {
      debugPrint('UpdateService.install failed: $e');
      return false;
    }
  }

  Future<(String, String)> _currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (info.version, info.buildNumber);
  }
}

/// Seam over [AndroidIntent]'s resolve/launch so the install flow can be
/// exercised on non-Android test hosts.
///
/// `android_intent_plus` hard-codes a local-platform check internally — off
/// Android `canResolveActivity()` always reports `false` and `launch()` is a
/// no-op — so the install paths cannot be driven by mocking the platform
/// channel. Production always uses [AndroidIntentLauncher]; tests inject fakes
/// through [UpdateService.install]'s `intentLauncherFactory`.
@visibleForTesting
abstract class IntentLauncher {
  Future<bool> canResolveActivity();
  Future<void> launch();
}

/// [AndroidIntent]-backed [IntentLauncher].
@visibleForTesting
class AndroidIntentLauncher implements IntentLauncher {
  AndroidIntentLauncher(this._intent);

  final AndroidIntent _intent;

  @override
  Future<bool> canResolveActivity() async =>
      (await _intent.canResolveActivity()) ?? false;

  @override
  Future<void> launch() => _intent.launch();
}
