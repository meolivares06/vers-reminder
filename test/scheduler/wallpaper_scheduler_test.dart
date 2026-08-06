import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/scheduler/infrastructure/wallpaper_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() {
    WallpaperScheduler.resetForTesting();
  });

  Future<void> seedDb({
    required bool schedulerEnabled,
    int frequencyMinutes = 360,
  }) async {
    final dbPath = 'ws_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            "CREATE TABLE app_config ("
            "id INTEGER PRIMARY KEY DEFAULT 1, "
            "scheduler_enabled INTEGER NOT NULL DEFAULT 0, "
            "frequency_minutes INTEGER NOT NULL DEFAULT 360, "
            "active_category_ids TEXT NOT NULL DEFAULT '[]', "
            "wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0)",
          );
          await db.execute(
            "INSERT INTO app_config (id, scheduler_enabled, frequency_minutes) "
            "VALUES (1, ${schedulerEnabled ? 1 : 0}, $frequencyMinutes)",
          );
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  }

  group('WallpaperScheduler cold-start registration', () {
    test('registers periodic task when DB has scheduler_enabled = 1', () async {
      // RED would have failed here before the fix — init() read from
      // SharedPreferences (always null) instead of the database.
      await seedDb(schedulerEnabled: true, frequencyMinutes: 30);

      try {
        await WallpaperScheduler.init();
      } catch (_) {
        // Workmanager platform channel unavailable in test — expected.
      }

      expect(
        WallpaperScheduler.lastRegisteredFrequency,
        equals(30),
        reason:
            'init() must read scheduler_enabled=1 from the database and '
            'call registerPeriodic with the stored frequency (30 min)',
      );
    });

    test('does NOT register when DB has scheduler_enabled = 0', () async {
      await seedDb(schedulerEnabled: false);

      try {
        await WallpaperScheduler.init();
      } catch (_) {
        // Workmanager unavailable — expected.
      }

      expect(
        WallpaperScheduler.lastRegisteredFrequency,
        isNull,
        reason:
            'init() must NOT register a periodic task when the database '
            'has scheduler_enabled = 0',
      );
    });
  });
}
