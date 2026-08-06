import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/wallpaper/infrastructure/temp_cleanup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    // Reset SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('temp_cleanup_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File createWallpaper(String name) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsBytesSync([1, 2, 3]);
    return file;
  }

  group('cleanTempWallpapers', () {
    test('Sc.1 deletes orphans but preserves last_wallpaper_path',
        () async {
      final keeper = createWallpaper('wallpaper_a.png');
      createWallpaper('wallpaper_b.png');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_wallpaper_path', keeper.path);

      final deleted = await TempCleanupService.instance
          .cleanTempWallpapers(tempDirOverride: tempDir.path);

      expect(deleted, 1);
      expect(keeper.existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'wallpaper_b.png')).existsSync(),
          isFalse);
    });

    test('Sc.2 with no prefs deletes all wallpaper files', () async {
      createWallpaper('wallpaper_a.png');
      createWallpaper('wallpaper_b.png');

      final deleted = await TempCleanupService.instance
          .cleanTempWallpapers(tempDirOverride: tempDir.path);

      expect(deleted, 2);
      expect(
          Directory(tempDir.path)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('wallpaper_')),
          isEmpty);
    });

    test('Sc.3 empty temp dir returns 0 without error', () async {
      final deleted = await TempCleanupService.instance
          .cleanTempWallpapers(tempDirOverride: tempDir.path);

      expect(deleted, 0);
    });

    test('Sc.4 last_wallpaper_path pointing to missing file still cleans',
        () async {
      createWallpaper('wallpaper_a.png');
      createWallpaper('wallpaper_b.png');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_wallpaper_path', p.join(tempDir.path, 'wallpaper_gone.png'));

      final deleted = await TempCleanupService.instance
          .cleanTempWallpapers(tempDirOverride: tempDir.path);

      expect(deleted, 2);
      expect(
          Directory(tempDir.path)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('wallpaper_')),
          isEmpty);
    });

    test('missing file at sweep start does not abort', () async {
      final a = createWallpaper('wallpaper_a.png');
      createWallpaper('wallpaper_b.png');

      // Delete one file BEFORE the sweep lists (not mid-listing): deletion is
      // defensive so no error propagates and the sweep continues.
      a.deleteSync();

      final deleted = await TempCleanupService.instance
          .cleanTempWallpapers(tempDirOverride: tempDir.path);

      // The already-missing file is skipped; the remaining one is cleaned.
      expect(deleted, 1);
    });

    test('non-wallpaper files are left untouched', () async {
      createWallpaper('wallpaper_a.png');
      final unrelated = File(p.join(tempDir.path, 'notes.txt'));
      unrelated.writeAsBytesSync([9]);

      await TempCleanupService.instance
          .cleanTempWallpapers(tempDirOverride: tempDir.path);

      expect(unrelated.existsSync(), isTrue);
    });
  });
}
