import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/verses/domain/verse.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_result.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_status.dart';
import 'package:vers_reminder/wallpaper/infrastructure/wallpaper_generator.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dbPath = 'ws_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE verses (id INTEGER PRIMARY KEY AUTOINCREMENT, textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, createdAt TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE verse_categories (verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)',
          );
          await db.execute(
            'CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\', wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('WallpaperState', () {
    // ── Initial state ──
    test('initial state is idle with no wallpaper', () async {
      final state = WallpaperState();
      await state.init();

      expect(state.status, WallpaperStatus.idle);
      expect(state.statusPayload, isNull);
      expect(state.lastWallpaperPath, isNull);
      expect(state.lastWallpaperTimestamp, isNull);
      expect(state.wallpaperPermissionGranted, false);
      expect(state.hasBackup, false);
      expect(state.isLoading, false);
    });

    test('init loads wallpaper path and timestamp from SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({
        'last_wallpaper_path': '/tmp/wallpaper.png',
        'last_wallpaper_timestamp': '2025-01-15T10:30:00.000',
      });

      final state = WallpaperState();
      await state.init();

      expect(state.lastWallpaperPath, '/tmp/wallpaper.png');
      expect(state.lastWallpaperTimestamp, DateTime(2025, 1, 15, 10, 30));
    });

    test('absent or malformed timestamp falls back safely', () async {
      SharedPreferences.setMockInitialValues({
        'last_wallpaper_timestamp': 'garbage-not-iso',
        'last_wallpaper_path': '/legacy/path.png',
      });

      final state = WallpaperState();
      await state.init();

      expect(state.lastWallpaperTimestamp, isNull,
          reason: 'malformed persisted timestamp must not crash init');
      expect(state.lastWallpaperPath, '/legacy/path.png',
          reason: 'legacy path key still loads independently');
    });

    // ── setWallpaperCard (test seam) ──
    test('setWallpaperCard sets path and timestamp', () {
      final state = WallpaperState();
      final now = DateTime.now();

      state.setWallpaperCard(
        path: '/foo/bar.png',
        timestamp: now,
        permissionGranted: true,
      );

      expect(state.lastWallpaperPath, '/foo/bar.png');
      expect(state.lastWallpaperTimestamp, now);
      expect(state.wallpaperPermissionGranted, true);
    });

    // ── grantPermission ──
    test('grantPermission sets permission flag', () async {
      final state = WallpaperState();
      await state.grantPermission();

      expect(state.wallpaperPermissionGranted, true);
    });

    // ── setStatusForTest ──
    test('setStatusForTest sets status and payload', () async {
      final state = WallpaperState();

      state.setStatusForTest(WallpaperStatus.error, payload: 'something broke');
      expect(state.status, WallpaperStatus.error);
      expect(state.statusPayload, 'something broke');
    });

    // ── hasBackup test seam ──
    test('setHasBackup changes backup state', () {
      final state = WallpaperState();

      expect(state.hasBackup, false);
      state.setHasBackup(true);
      expect(state.hasBackup, true);
    });

    // ── triggerNow with no categories ──
    test('triggerNow with no categories sets noCategories status', () async {
      final state = WallpaperState();
      await state.init();

      await state.triggerNow(locale: 'es');

      expect(state.status, WallpaperStatus.noCategories);
    });

    // ── triggerNow success path ──
    test('triggerNow success persists last wallpaper metadata', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      // Pre-populate scheduler config — activeCategoryIds lives on SchedulerConfig
      // and WallpaperState reads it from DB at runtime.
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final state = WallpaperState(
        wallpaperGenerator: _FakeWallpaperGenerator(),
      );
      await state.init();

      await state.triggerNow(locale: 'es');

      expect(state.status, WallpaperStatus.updated);
      expect(state.lastWallpaperPath, '/fake/wallpaper.png');
      expect(state.lastWallpaperTimestamp, isNotNull);

      // Verify persistence
      final stored =
          (await SharedPreferences.getInstance()).getString(
            'last_wallpaper_timestamp',
          );
      expect(stored, isNotNull);
    });

    // ── triggerNow error path ──
    test('triggerNow with no verses sets error status', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      // Pre-populate active_category_ids — WallpaperState reads from DB
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final state = WallpaperState();
      await state.init();

      await state.triggerNow(locale: 'es');

      expect(state.status, WallpaperStatus.error);
      expect(state.statusPayload, 'No verses for locale');
    });

    // ── useMyWallpaper ──
    test('setUseMyWallpaper updates state and persists', () async {
      final state = WallpaperState();
      await state.init();

      expect(state.useMyWallpaper, false);
      await state.setUseMyWallpaper(true);
      expect(state.useMyWallpaper, true);
    });

    // ── userBackgroundPath ──
    test('userBackgroundPath persists across provider recreation', () async {
      final s1 = WallpaperState();
      await s1.init();
      expect(s1.userBackgroundPath, isNull);

      const testPath = '/test/path/bg.png';
      await s1.setUserBackgroundPath(testPath);
      expect(s1.userBackgroundPath, testPath);

      final s2 = WallpaperState();
      await s2.init();
      expect(s2.userBackgroundPath, testPath);
    });

    test('setUserBackgroundPath with null removes key', () async {
      final state = WallpaperState();
      await state.init();

      await state.setUserBackgroundPath('/some/path.png');
      expect(state.userBackgroundPath, isNotNull);

      await state.setUserBackgroundPath(null);
      expect(state.userBackgroundPath, isNull);
    });

    // ── F4 re-entrancy guard ──
    test('F4-RED concurrent triggerNow produces exactly one generation',
        () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final fake = _CountingFakeGenerator();
      final state = WallpaperState(wallpaperGenerator: fake);
      await state.init();

      final f1 = state.triggerNow(locale: 'es');
      final f2 = state.triggerNow(locale: 'es');
      await Future.wait([f1, f2]);

      expect(fake.generateCallCount, 1,
          reason: 'only one generateAndSetWallpaper must proceed');
    });

    test('F4-RED retry after error passes the guard', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final fake = _CountingFakeGenerator();
      final state = WallpaperState(wallpaperGenerator: fake);
      await state.init();

      await state.triggerNow(locale: 'es');
      expect(fake.generateCallCount, 1);

      state.setStatusForTest(WallpaperStatus.error);

      await state.triggerNow(locale: 'es');
      expect(fake.generateCallCount, 2,
          reason: 'retry after error must pass the guard');
    });

    // ── F5 pre-gen mutex ──
    test('F5-RED mutex blocks overlapping pre-gen', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final fake = _SlowCountingPreGenGenerator();
      final state = WallpaperState(wallpaperGenerator: fake);
      await state.init();

      final f1 = state.triggerNow(locale: 'es');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final f2 = state.triggerNow(locale: 'es');
      await Future.wait([f1, f2]);

      expect(fake.preGenCallCount, 1,
          reason: 'second triggerNow must find mutex locked and skip pre-gen');
    });

    test('F5-RED mutex resets for sequential calls', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final fake = _CountingFakeGenerator();
      final state = WallpaperState(wallpaperGenerator: fake);
      await state.init();

      await state.triggerNow(locale: 'es');
      expect(fake.generateCallCount, 1);
      expect(fake.preGenCallCount, 1);

      await state.triggerNow(locale: 'es');
      expect(fake.generateCallCount, 2);
      expect(fake.preGenCallCount, 2,
          reason: 'mutex must reset after first pre-gen completes');
    });

    // ── EventBus: RefreshWallpaper listener ──
    test('RefreshWallpaper event triggers generation', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final fake = _CountingFakeGenerator();
      final state = WallpaperState(wallpaperGenerator: fake);
      await state.init();

      await EventBus.instance.emit(RefreshWallpaper(locale: 'es'));

      // Small delay for event dispatch
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fake.generateCallCount, 1,
          reason: 'RefreshWallpaper event must trigger generation');
    });

    // ── F3 non-blocking init ──
    test('init sets isLoading=false', () async {
      final state = WallpaperState();
      await state.init();

      expect(state.isLoading, false);
    });

    // ── Failed timestamp write is swallowed ──
    test('failed timestamp write is swallowed, generation succeeds',
        () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );
      await DatabaseService.instance.updateAppConfig({
        'active_category_ids': '[1]',
        'scheduler_enabled': 1,
      });

      final store = _FailingTimestampPrefsStore(
        InMemorySharedPreferencesStore.empty(),
      );
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() {
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferencesStorePlatform.instance =
            InMemorySharedPreferencesStore.empty();
      });

      final state = WallpaperState(
        wallpaperGenerator: _FakeWallpaperGenerator(),
      );
      await state.init();

      await state.triggerNow(locale: 'es');

      expect(state.status, WallpaperStatus.updated,
          reason: 'failed persistence must not fail generation');
      expect(state.lastWallpaperTimestamp, isNotNull,
          reason: 'in-memory state stays correct');
    });
  });
}

// ── Fakes (same pattern as settings_provider_test.dart) ──

class _FakeWallpaperGenerator implements WallpaperGenerator {
  @override
  Future<WallpaperResult> generateAndSetWallpaper({
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async =>
      const WallpaperResultSuccess('/fake/wallpaper.png', 'verse', 'citation');

  @override
  Future<int> preGenerateWallpapers({
    required List<Verse> verses,
    required String locale,
    required int screenWidth,
    required int screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async => 0;

  @override
  Future<Uint8List?> compositeFromBytes({
    required Uint8List backgroundBytes,
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
  }) async => null;

  @override
  Future<String?> renderFromPath({
    required String backgroundPath,
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
  }) async => null;

  @override
  Future<String?> renderOnly({
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async => null;

  @override
  Future<Uint8List?> renderPreview({
    required Verse verse,
    required String locale,
    int previewWidth = 270,
    int previewHeight = 480,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    String? previewImagePath,
    bool useMyWallpaper = false,
  }) async => null;

  @override
  Future<bool> setNextPreGenerated(int screenWidth, int screenHeight) async =>
      false;

  @override
  TextStyle verseMeasureStyle(double size) => TextStyle();

  @override
  TextStyle citationMeasureStyle(double size) => TextStyle();

  @override
  String citationDisplayText(String citation) => citation.toUpperCase();

  @override
  double resolveFontSizeForTest({
    required String text,
    required String citation,
    required double maxTextWidth,
    required double availableHeight,
    required int screenWidth,
    double fontScale = 1.0,
    bool legacyStyles = false,
  }) => 24.0;
}

class _CountingFakeGenerator extends _FakeWallpaperGenerator {
  int generateCallCount = 0;
  int preGenCallCount = 0;

  @override
  Future<WallpaperResult> generateAndSetWallpaper({
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    generateCallCount++;
    return super.generateAndSetWallpaper(
      verse: verse,
      locale: locale,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      horizontalOffset: horizontalOffset,
      verticalAlignment: verticalAlignment,
      fontScale: fontScale,
      calibratedInset: calibratedInset,
      useMyWallpaper: useMyWallpaper,
    );
  }

  @override
  Future<int> preGenerateWallpapers({
    required List<Verse> verses,
    required String locale,
    required int screenWidth,
    required int screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    preGenCallCount++;
    return super.preGenerateWallpapers(
      verses: verses,
      locale: locale,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      horizontalOffset: horizontalOffset,
      verticalAlignment: verticalAlignment,
      fontScale: fontScale,
      calibratedInset: calibratedInset,
      useMyWallpaper: useMyWallpaper,
    );
  }
}

class _SlowCountingPreGenGenerator extends _CountingFakeGenerator {
  @override
  Future<int> preGenerateWallpapers({
    required List<Verse> verses,
    required String locale,
    required int screenWidth,
    required int screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    preGenCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 0;
  }
}

/// A prefs store that fails writes to `last_wallpaper_timestamp` while
/// delegating everything else to an in-memory backing.
class _FailingTimestampPrefsStore extends SharedPreferencesStorePlatform {
  _FailingTimestampPrefsStore(this.backing);

  final InMemorySharedPreferencesStore backing;

  @override
  Future<bool> clear() => backing.clear();

  @override
  Future<Map<String, Object>> getAll() => backing.getAll();

  @override
  Future<bool> remove(String key) => backing.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key.endsWith('last_wallpaper_timestamp')) {
      throw StateError('simulated SharedPreferences write failure');
    }
    return backing.setValue(valueType, key, value);
  }
}
