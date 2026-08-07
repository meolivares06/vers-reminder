import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';

/// Validates that after wallpaper generation, both [lastWallpaperPath]
/// and [lastWallpaperTimestamp] are persisted so the home card stays in
/// sync with the actual wallpaper state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    final dbPath = 'wsync_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            "CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, "
            "scheduler_enabled INTEGER NOT NULL DEFAULT 0, "
            "frequency_minutes INTEGER NOT NULL DEFAULT 360, "
            "active_category_ids TEXT NOT NULL DEFAULT '[]', "
            "wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0)",
          );
          await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('WallpaperState persistence', () {
    test('init reads both path and timestamp from SharedPreferences',
        () async {
      final prefs = await SharedPreferences.getInstance();

      // Simulate what setNextPreGenerated writes after background generation.
      await prefs.setString('last_wallpaper_path', '/tmp/wallpaper.png');
      await prefs.setString(
        'last_wallpaper_timestamp',
        '2026-08-06T10:00:00.000',
      );

      final state = WallpaperState();
      await state.init();

      // RED: before the fix, lastWallpaperPath would be null because
      // setNextPreGenerated only persisted the timestamp, not the path.
      expect(
        state.lastWallpaperPath,
        equals('/tmp/wallpaper.png'),
        reason:
            'WallpaperState must read last_wallpaper_path from '
            'SharedPreferences so the home card shows the current wallpaper '
            'after a background generation',
      );
      expect(
        state.lastWallpaperTimestamp,
        isNotNull,
        reason: 'WallpaperState must read last_wallpaper_timestamp',
      );
    });
  });
}
