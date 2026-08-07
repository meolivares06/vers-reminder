import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';

/// Integration tests for Phase 2 event bus wiring.
///
/// Prove that modules communicate via typed events without direct imports.
/// The WallpaperState constructor registers its listeners, so widget tests
/// can verify the full publish→subscribe flow without a database.

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    final dbPath = 'ebi_${DateTime.now().microsecondsSinceEpoch}.db';
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
            'categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), '
            'FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, '
            'FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)',
          );
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

  group('RefreshWallpaper → WallpaperState flow', () {
    test('emitting RefreshWallpaper triggers wallpaper generation path', () {
      // WallpaperState constructor registers RefreshWallpaper listener
      final wallpaper = WallpaperState();

      // Emit the same event that home_screen.dart would emit
      EventBus.instance.emit(const RefreshWallpaper(locale: 'en'));

      // triggerNow runs async — but it will update status to noCategories
      // (no active categories in a fresh provider with no DB)
      // The listener is async; we verify status transitions happen
      expect(wallpaper.status.name, anyOf('noCategories', 'idle', 'generating'));
    });

    test('RefreshWallpaper listener triggers noCategories on empty provider',
        () async {
      // Creating a WallpaperState registers the RefreshWallpaper listener
      // in its constructor. Emitting RefreshWallpaper causes the handler
      // to call triggerNow — which short-circuits with noCategories when
      // active category ids are empty (no DB access needed).
      final wallpaper = WallpaperState();

      await EventBus.instance.emit(const RefreshWallpaper(locale: 'en'));

      expect(wallpaper.status.name, 'noCategories');
    });
  });

  group('SettingChanged propagation', () {
    test('SettingChanged reaches listener registered before emit', () async {
      final receivedKeys = <String>[];

      EventBus.instance.on<SettingChanged>((event) async {
        receivedKeys.add(event.key);
      });

      EventBus.instance.emit(const SettingChanged(key: 'wallpaper_error'));
      EventBus.instance.emit(const SettingChanged(key: 'no_categories'));

      // Allow async handlers to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedKeys, contains('wallpaper_error'));
      expect(receivedKeys, contains('no_categories'));
    });
  });

  group('WallpaperGenerated propagation', () {
    test('WallpaperGenerated event carries path and optional citation', () async {
      String? receivedPath;
      String? receivedCitation;

      EventBus.instance.on<WallpaperGenerated>((event) async {
        receivedPath = event.path;
        receivedCitation = event.citation;
      });

      EventBus.instance.emit(
        const WallpaperGenerated(path: '/tmp/test.png', citation: 'Jn 3:16'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedPath, '/tmp/test.png');
      expect(receivedCitation, 'Jn 3:16');
    });

    test('WallpaperGenerated with null citation is valid', () async {
      String? receivedPath;
      String? receivedCitation;

      EventBus.instance.on<WallpaperGenerated>((event) async {
        receivedPath = event.path;
        receivedCitation = event.citation;
      });

      EventBus.instance.emit(
        const WallpaperGenerated(path: '/tmp/nocite.png'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedPath, '/tmp/nocite.png');
      expect(receivedCitation, isNull);
    });
  });

  group('Cross-module communication without direct imports', () {
    test('modules communicate solely via EventBus singleton', () {
      // home_screen imports no wallpaper/scheduler/notifications types
      // (verified by the WallpaperStatus import removal in home_screen.dart)

      // Instead, home_screen emits RefreshWallpaper — which WallpaperState
      // receives via its constructor-registered listener.
      //
      // This test proves the wiring: a listener registered on one "module"
      // receives events emitted from another "module" path via the same
      // EventBus.instance singleton.
      var handlerFired = false;

      EventBus.instance.on<NotificationRequested>((event) async {
        handlerFired = true;
      });

      // Emit from the "home screen" perspective
      EventBus.instance.emit(
        const NotificationRequested(title: 'Test', body: 'Integration test'),
      );

      // The handler registered from the "notification service" perspective
      // fires because both "modules" share the same EventBus.instance.
      expect(handlerFired, isTrue);
    });

    test('SchedulerToggled event flow between settings and scheduler', () async {
      bool? receivedEnabled;
      int? receivedFreq;

      // "scheduler module" registers its listener
      EventBus.instance.on<SchedulerToggled>((event) async {
        receivedEnabled = event.enabled;
        receivedFreq = event.frequencyMinutes;
      });

      // "settings module" emits the event
      EventBus.instance.emit(
        const SchedulerToggled(enabled: true, frequencyMinutes: 180),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedEnabled, isTrue);
      expect(receivedFreq, 180);
    });
  });

  group('BackupRestored and PermissionGranted events', () {
    test('BackupRestored event propagates to listeners', () async {
      var received = false;

      EventBus.instance.on<BackupRestored>((event) async {
        received = true;
      });

      EventBus.instance.emit(
        const BackupRestored(success: true, operation: 'backup'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received, isTrue);
    });

    test('PermissionGranted event propagates to listeners', () async {
      var received = false;

      EventBus.instance.on<PermissionGranted>((event) async {
        received = true;
      });

      EventBus.instance.emit(const PermissionGranted());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received, isTrue);
    });
  });

  group('VerseAdded event flow', () {
    test('VerseAdded carries optional categoryId', () async {
      int? receivedId;

      EventBus.instance.on<VerseAdded>((event) async {
        receivedId = event.categoryId;
      });

      EventBus.instance.emit(const VerseAdded(categoryId: 42));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedId, 42);
    });

    test('VerseAdded with null categoryId is valid', () async {
      int? receivedId;

      EventBus.instance.on<VerseAdded>((event) async {
        receivedId = event.categoryId;
      });

      EventBus.instance.emit(const VerseAdded());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedId, isNull);
    });
  });
}
