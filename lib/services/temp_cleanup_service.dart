import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sweep_utils.dart';

/// Sweeps `getTemporaryDirectory()` for stale `wallpaper_*.png` files.
///
/// Singleton pattern matching [WallpaperBackupService] conventions.
///
/// On every app start this service removes temp wallpapers that were left
/// behind by foreground wallpaper generation, preserving only the file
/// referenced by the `last_wallpaper_path` SharedPreferences key. The sweep
/// is defensive: a file that vanishes between listing and deletion is handled
/// gracefully and never aborts the sweep.
class TempCleanupService {
  static final TempCleanupService instance = TempCleanupService._internal();
  TempCleanupService._internal();

  /// Deletes every temp file matching `wallpaper_*.png` except the one
  /// referenced by `last_wallpaper_path` in SharedPreferences.
  ///
  /// The [tempDirOverride] param lets tests point the sweep at a temp
  /// directory without mocking `path_provider`. Returns the number of files
  /// deleted.
  ///
  /// The documented contract is that "errors never abort the sweep": the whole
  /// setup (resolving the temp dir, reading prefs) and the file loop are
  /// wrapped so no unexpected async exception can escape and crash/abort at
  /// launch. In the unlikely event setup itself fails, 0 is returned.
  Future<int> cleanTempWallpapers({String? tempDirOverride}) async {
    try {
      final dirPath = tempDirOverride ?? (await getTemporaryDirectory()).path;
      final prefs = await SharedPreferences.getInstance();
      final keep = prefs.getString('last_wallpaper_path');
      final dir = Directory(dirPath);

      final deleted = await sweepDirectory(
        dir,
        keep: (file) {
          final name = p.basename(file.path);
          if (!name.startsWith('wallpaper_') || !name.endsWith('.png')) {
            return true; // Not a temp wallpaper — never delete.
          }
          // Absolute path comparison: the preserved file is skipped whether or
          // not it still exists (cheapest and safest — see design decision 5).
          return file.path == keep;
        },
      );

      debugPrint('TempCleanupService: deleted $deleted temp wallpaper(s)');
      return deleted;
    } catch (e) {
      debugPrint('TempCleanupService sweep aborted: $e');
      return 0;
    }
  }
}
