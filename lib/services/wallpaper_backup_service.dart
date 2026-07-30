import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

/// Orchestrates saving and restoring the user's original Android wallpaper.
///
/// Singleton pattern matching [ImageCacheService] conventions.
///
/// Saves the wallpaper as a PNG file at `{appDocDir}/wallpaper_backup/original.png`
/// and tracks state via the `has_wallpaper_backup` SharedPreferences key.
/// Restore uses the existing [WallpaperManagerFlutter.setWallpaper] path.
class WallpaperBackupService {
  static const String _backupDirName = 'wallpaper_backup';
  static const String _backupFileName = 'original.png';
  static const String backupFlagKey = 'has_wallpaper_backup';

  static final WallpaperBackupService instance = WallpaperBackupService._internal();
  WallpaperBackupService._internal();

  /// Reads the current Android wallpaper via MethodChannel and saves it as PNG.
  ///
  /// Returns `true` if the wallpaper was saved successfully, `false` if the
  /// wallpaper is a live wallpaper (getWallpaper returned null) or an error occurred.
  Future<bool> backupCurrent() async {
    try {
      const channel = MethodChannel('vers_reminder/wallpaper');
      final bytes = await channel.invokeMethod<Uint8List>('getWallpaper');

      if (bytes == null) return false; // Live wallpaper or unsupported

      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, _backupDirName));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final backupFile = File(p.join(backupDir.path, _backupFileName));
      await backupFile.writeAsBytes(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(backupFlagKey, true);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restores the saved wallpaper using [WallpaperManagerFlutter.setWallpaper].
  ///
  /// Returns `true` if the wallpaper was restored successfully.
  /// If the backup file is missing, clears the flag and returns `false`.
  Future<bool> restoreOriginal() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupFile = File(p.join(appDir.path, _backupDirName, _backupFileName));

      if (!await backupFile.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(backupFlagKey, false);
        return false;
      }

      final manager = WallpaperManagerFlutter();
      await manager.setWallpaper(backupFile, WallpaperManagerFlutter.bothScreens);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether a valid wallpaper backup exists.
  ///
  /// Checks both the SharedPreferences flag and the actual file on disk.
  /// If the flag is true but the file is missing, clears the flag and returns false.
  Future<bool> get hasBackup async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(backupFlagKey) ?? false;

    if (!flag) return false;

    final appDir = await getApplicationDocumentsDirectory();
    final backupFile = File(p.join(appDir.path, _backupDirName, _backupFileName));

    if (!await backupFile.exists()) {
      await prefs.setBool(backupFlagKey, false);
      return false;
    }

    return true;
  }
}
