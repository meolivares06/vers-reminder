import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/backup/wallpaper_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String tempDir;

  setUp(() async {
    // Reset SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});

    // Use a temp directory for file operations
    tempDir = Directory.systemTemp.createTempSync('backup_test_').path;

    // Override path_provider to return our temp dir
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir;
        }
        return null;
      },
    );

    // Clean any leftover backup files
    final backupDir = Directory(p.join(tempDir, 'wallpaper_backup'));
    if (backupDir.existsSync()) {
      backupDir.deleteSync(recursive: true);
    }
  });

  tearDown(() async {
    // Clean up temp dir
    Directory(tempDir).deleteSync(recursive: true);
  });

  group('hasBackup', () {
    test('returns false when no flag in SharedPreferences', () async {
      final result = await WallpaperBackupService.instance.hasBackup;
      expect(result, isFalse);
    });

    test('returns false and clears flag when flag is true but file missing',
        () async {
      // Set the flag but don't create the file
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(WallpaperBackupService.backupFlagKey, true);

      final result = await WallpaperBackupService.instance.hasBackup;
      expect(result, isFalse);

      // Verify the flag was cleared
      final postPrefs = await SharedPreferences.getInstance();
      expect(postPrefs.getBool(WallpaperBackupService.backupFlagKey), isFalse);
    });

    test('returns true when both flag and file exist', () async {
      // Set the flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(WallpaperBackupService.backupFlagKey, true);

      // Create the backup file
      final backupDir = Directory(p.join(tempDir, 'wallpaper_backup'));
      backupDir.createSync(recursive: true);
      File(p.join(backupDir.path, 'original.png'))
          .writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final result = await WallpaperBackupService.instance.hasBackup;
      expect(result, isTrue);
    });
  });

  group('backupCurrent', () {
    test('saves file and sets flag when channel returns bytes', () async {
      // Mock the getWallpaper channel to return fake PNG bytes
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('vers_reminder/wallpaper'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getWallpaper') {
            return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
          }
          return null;
        },
      );

      final result = await WallpaperBackupService.instance.backupCurrent();
      expect(result, isTrue);

      // Verify file was saved
      final backupFile =
          File(p.join(tempDir, 'wallpaper_backup', 'original.png'));
      expect(backupFile.existsSync(), isTrue);

      // Verify flag was set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(WallpaperBackupService.backupFlagKey), isTrue);

      // Clean up mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('vers_reminder/wallpaper'),
        null,
      );
    });

    test('returns false when channel returns null (live wallpaper)', () async {
      // Mock the channel to return null
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('vers_reminder/wallpaper'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getWallpaper') {
            return null;
          }
          return null;
        },
      );

      final result = await WallpaperBackupService.instance.backupCurrent();
      expect(result, isFalse);

      // Verify flag was NOT set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(WallpaperBackupService.backupFlagKey), isFalse);

      // Clean up mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('vers_reminder/wallpaper'),
        null,
      );
    });
  });
}
