import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_status.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';
import 'package:vers_reminder/scheduler/infrastructure/wallpaper_scheduler.dart';

/// Integration tests validating end-to-end flows across modules wired
/// through the event bus and providers — no mocks, real wiring.
void main() {
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    WallpaperScheduler.resetForTesting();
    final dbPath = 'home_int_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE verses (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, '
            'createdAt TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE verse_categories (verseId INTEGER NOT NULL, '
            'categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId))',
          );
          await db.execute(
            "CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, "
            "scheduler_enabled INTEGER NOT NULL DEFAULT 0, "
            "frequency_minutes INTEGER NOT NULL DEFAULT 360, "
            "active_category_ids TEXT NOT NULL DEFAULT '[]', "
            "wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0)",
          );
          await db.execute(
            "INSERT INTO app_config (id, scheduler_enabled, "
            "frequency_minutes, active_category_ids, "
            "wallpaper_permission_granted) "
            "VALUES (1, 1, 15, '[1]', 1)",
          );
          await db.execute(
            "INSERT INTO categories (id, name) VALUES (1, 'Test')",
          );
          await db.execute(
            "INSERT INTO verses (id, textEs, citation, createdAt) "
            "VALUES (1, 'Test verse', 'John 3:16', '2026-01-01')",
          );
          await db.execute(
            "INSERT INTO verse_categories (verseId, categoryId) VALUES (1, 1)",
          );
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  setUp(() {
    WallpaperScheduler.resetForTesting();
  });

  // ── Event bus flows (plain tests — no widget tree needed) ──

  group('Event bus integration flows', () {
    test('RefreshWallpaper event triggers wallpaper generation', () async {
      final wallpaper = WallpaperState();
      await wallpaper.init();
      final bus = EventBus.instance;

      expect(wallpaper.status, WallpaperStatus.idle);

      bus.emit(RefreshWallpaper(locale: 'en'));
      // Allow async triggerNow to complete.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // triggerNow should have moved past idle.
      expect(
        wallpaper.status,
        isNot(WallpaperStatus.idle),
        reason:
            'RefreshWallpaper event must trigger generation via '
            'WallpaperState.on<RefreshWallpaper> subscription',
      );
    });

    test('SchedulerToggled enables and disables periodic registration',
        () async {
      await WallpaperScheduler.init();
      final scheduler = SchedulerConfig();
      await scheduler.init();

      // Cold start: DB has scheduler_enabled=1, frequency=15.
      expect(
        WallpaperScheduler.lastRegisteredFrequency,
        equals(15),
        reason: 'Scheduler must register periodic task on cold start',
      );

      // Change frequency → SchedulerToggled → re-register.
      WallpaperScheduler.resetForTesting();
      await scheduler.setFrequency(30);
      expect(
        WallpaperScheduler.lastRegisteredFrequency,
        equals(30),
        reason: 'Frequency change must emit SchedulerToggled and re-register',
      );

      // Disable → cancel.
      WallpaperScheduler.resetForTesting();
      await scheduler.setEnabled(false);
      expect(
        WallpaperScheduler.lastRegisteredFrequency,
        isNull,
        reason: 'Disabling the scheduler must cancel the periodic task',
      );
    });

    test('WallpaperGenerated event clears error state', () async {
      final wallpaper = WallpaperState();
      await wallpaper.init();
      final bus = EventBus.instance;

      bus.emit(SettingChanged(key: 'wallpaper_error'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bus.emit(WallpaperGenerated(path: '/tmp/test.png', citation: 'John 3:16'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Contract: WallpaperGenerated must not leave the system in error.
      expect(
        wallpaper.status,
        isNot(WallpaperStatus.error),
        reason: 'WallpaperGenerated must reset generation state',
      );
    });

    test('BackupRestored event propagates to listeners', () async {
      final bus = EventBus.instance;
      bool received = false;
      bool receivedSuccess = false;
      bool receivedOperation = false;

      bus.on<BackupRestored>((event) async {
        received = true;
        receivedSuccess = event.success;
        receivedOperation = event.operation == 'restore';
      });

      bus.emit(BackupRestored(success: true, operation: 'restore'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received, isTrue);
      expect(receivedSuccess, isTrue);
      expect(receivedOperation, isTrue);
    });
  });
}
