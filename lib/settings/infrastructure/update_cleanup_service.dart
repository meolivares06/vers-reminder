import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:vers_reminder/shared/application/sweep_utils.dart';

/// Manages the dedicated APK download directory for the auto-update flow.
///
/// Singleton pattern matching [WallpaperBackupService] conventions.
///
/// This service owns `{getApplicationSupportDirectory()}/updates/`. It is
/// consumed by [UpdateService.download] to clear stale APKs before a new
/// download and to remove partial files on failure.
class UpdateCleanupService {
  static final UpdateCleanupService instance = UpdateCleanupService._internal();
  UpdateCleanupService._internal();

  /// Returns the path of the updates directory, creating it (recursively) if
  /// it does not yet exist.
  ///
  /// The [appSupportOverride] param lets tests point the directory at a temp
  /// location without mocking `path_provider`.
  Future<String> updatesDir({String? appSupportOverride}) async {
    final appSupport =
        appSupportOverride ?? (await getApplicationSupportDirectory()).path;
    final dir = Directory(p.join(appSupport, 'updates'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Deletes every `*.apk` file in the updates directory (defensively).
  ///
  /// The [appSupportOverride] param mirrors [updatesDir]. Returns the number of
  /// files deleted. The sweep never aborts on individual failures.
  Future<int> cleanUpdatesDir({String? appSupportOverride}) async {
    final dirPath = await updatesDir(appSupportOverride: appSupportOverride);
    final dir = Directory(dirPath);

    final deleted = await sweepDirectory(
      dir,
      keep: (file) => !file.path.toLowerCase().endsWith('.apk'),
    );

    debugPrint('UpdateCleanupService: deleted $deleted stale APK(s)');
    return deleted;
  }
}
