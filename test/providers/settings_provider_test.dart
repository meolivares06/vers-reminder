import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/database/database_service.dart';
import 'package:vers_reminder/models/verse.dart';
import 'package:vers_reminder/models/wallpaper_result.dart';
import 'package:vers_reminder/models/wallpaper_status.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';
import 'package:vers_reminder/services/wallpaper_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dbPath = 'sp_${DateTime.now().microsecondsSinceEpoch}.db';
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
            'CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\')',
          );
          await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('SettingsProvider', () {
    test('init loads useMyWallpaper default false when key absent', () async {
      final provider = SettingsProvider();
      await provider.init();

      expect(
        provider.useMyWallpaper,
        false,
        reason: 'default should be false when key is absent',
      );
    });

    test('useMyWallpaper persists across provider recreation', () async {
      final p1 = SettingsProvider();
      await p1.init();

      expect(p1.useMyWallpaper, false);
      await p1.setUseMyWallpaper(true);
      expect(p1.useMyWallpaper, true);

      // Recreate provider (SharedPreferences mock persists)
      final p2 = SettingsProvider();
      await p2.init();

      expect(
        p2.useMyWallpaper,
        true,
        reason: 'recreated provider should load persisted true',
      );
    });

    test('init loads defaults', () async {
      final provider = SettingsProvider();
      await provider.init();

      expect(provider.isEnabled, false);
      expect(provider.frequencyMinutes, 360);
      expect(provider.activeCategoryIds, isEmpty);
      expect(provider.isLoading, false);
    });

    test('status starts as idle', () async {
      final provider = SettingsProvider();
      await provider.init();

      expect(provider.status, WallpaperStatus.idle);
      expect(provider.statusPayload, isNull);
    });

    test('triggerNow with no categories sets noCategories status', () async {
      final provider = SettingsProvider();
      await provider.init();

      // No categories active → should set noCategories
      await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');

      expect(provider.status, WallpaperStatus.noCategories);
    });

    test('triggerNow after adding categories starts generating', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertCategory('Cat 2', isSeed: true);

      final provider = SettingsProvider();
      await provider.init();

      provider.toggleCategory(1);
      expect(provider.activeCategoryIds, {1});

      // Should start generating (will fail because no verses, but status is set)
      await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');

      // After trying to generate with no verses, status should be error
      expect(provider.status, WallpaperStatus.error);
      expect(provider.statusPayload, isNotNull);
    });

    test('toggleCategory adds and removes', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertCategory('Cat 2', isSeed: true);

      final provider = SettingsProvider();
      await provider.init();

      provider.toggleCategory(1);
      expect(provider.activeCategoryIds, {1});

      provider.toggleCategory(2);
      expect(provider.activeCategoryIds, {1, 2});

      provider.toggleCategory(1);
      expect(provider.activeCategoryIds, {2});
    });

    test('userBackgroundPath persists across provider recreation', () async {
      final p1 = SettingsProvider();
      await p1.init();

      expect(
        p1.userBackgroundPath,
        isNull,
        reason: 'default should be null when key is absent',
      );

      const testPath = '/test/path/user_background.png';
      await p1.setUserBackgroundPath(testPath);
      expect(p1.userBackgroundPath, testPath);

      // Recreate provider (SharedPreferences mock persists)
      final p2 = SettingsProvider();
      await p2.init();

      expect(
        p2.userBackgroundPath,
        testPath,
        reason: 'recreated provider should load persisted path',
      );
    });

    test('setUserBackgroundPath with null removes key', () async {
      final p1 = SettingsProvider();
      await p1.init();

      await p1.setUserBackgroundPath('/some/path.png');
      expect(p1.userBackgroundPath, isNotNull);

      await p1.setUserBackgroundPath(null);
      expect(p1.userBackgroundPath, isNull);

      // Recreate and verify removal persisted
      final p2 = SettingsProvider();
      await p2.init();

      expect(
        p2.userBackgroundPath,
        isNull,
        reason: 'null path should be persisted as removed',
      );
    });

    test('setFrequency updates value', () async {
      final provider = SettingsProvider();
      await provider.init();

      await provider.setFrequency(60);
      expect(provider.frequencyMinutes, 60);

      final config = await DatabaseService.instance.getAppConfig();
      expect(config['frequency_minutes'], 60);
    });

    test(
      'triggerNow success persists last wallpaper metadata across recreation',
      () async {
        await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
        await DatabaseService.instance.insertVerse(
          Verse(textEs: 'Texto', citation: 'Juan 3:16'),
          [1],
        );

        final p1 = SettingsProvider(
          wallpaperGenerator: _FakeWallpaperGenerator(),
        );
        await p1.init();
        await p1.toggleCategory(1);

        await p1.triggerNow(verseProvider: VerseProvider(), locale: 'es');

        expect(p1.status, WallpaperStatus.updated);
        expect(p1.lastWallpaperPath, '/fake/wallpaper.png');
        expect(p1.lastWallpaperTimestamp, isNotNull);

        final stored = (await SharedPreferences.getInstance()).getString(
          'last_wallpaper_timestamp',
        );
        expect(
          stored,
          isNotNull,
          reason: 'timestamp must be awaited before triggerNow returns',
        );
        expect(DateTime.parse(stored!), p1.lastWallpaperTimestamp);

        // Recreated provider restores the persisted timestamp + path.
        final p2 = SettingsProvider(
          wallpaperGenerator: _FakeWallpaperGenerator(),
        );
        await p2.init();
        expect(p2.lastWallpaperPath, '/fake/wallpaper.png');
        expect(
          p2.lastWallpaperTimestamp,
          p1.lastWallpaperTimestamp,
          reason: 'recreated provider restores the persisted timestamp',
        );
      },
    );

    test(
      'a failed timestamp write is swallowed and generation still succeeds',
      () async {
        final store = _FailingTimestampPrefsStore(
          InMemorySharedPreferencesStore.empty(),
        );
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(() {
          SharedPreferencesStorePlatform.instance =
              InMemorySharedPreferencesStore.empty();
        });

        await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
        await DatabaseService.instance.insertVerse(
          Verse(textEs: 'Texto', citation: 'Juan 3:16'),
          [1],
        );

        final provider = SettingsProvider(
          wallpaperGenerator: _FakeWallpaperGenerator(),
        );
        await provider.init();
        await provider.toggleCategory(1);

        await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');

        expect(
          provider.status,
          WallpaperStatus.updated,
          reason: 'a failed persistence write must not fail the generation',
        );
        expect(
          provider.lastWallpaperTimestamp,
          isNotNull,
          reason: 'in-memory state stays correct even when persistence fails',
        );

        final persisted = await store.backing.getAll();
        expect(
          persisted['flutter.last_wallpaper_path'],
          '/fake/wallpaper.png',
          reason: 'non-failing writes still reach the store',
        );
        expect(
          persisted.containsKey('flutter.last_wallpaper_timestamp'),
          isFalse,
          reason: 'the failing timestamp write never reaches the store',
        );
      },
    );

    test('absent or malformed persisted timestamp falls back safely', () async {
      final p1 = SettingsProvider();
      await p1.init();
      expect(
        p1.lastWallpaperTimestamp,
        isNull,
        reason: 'absent key loads a null timestamp',
      );
      expect(p1.lastWallpaperPath, isNull);

      SharedPreferences.setMockInitialValues({
        'last_wallpaper_timestamp': 'garbage-not-iso',
        'last_wallpaper_path': '/legacy/path.png',
      });
      final p2 = SettingsProvider();
      await p2.init();
      expect(
        p2.lastWallpaperTimestamp,
        isNull,
        reason: 'malformed persisted timestamp must not crash init',
      );
      expect(
        p2.lastWallpaperPath,
        '/legacy/path.png',
        reason: 'the legacy path key still loads independently',
      );
    });
  });
}

/// A [WallpaperGenerator] double that reports success without touching any
/// platform channel, filesystem, or the real rendering pipeline.
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

/// A prefs store that fails writes to `last_wallpaper_timestamp` while
/// delegating everything else to an in-memory backing. Simulates the
/// fire-and-forget write failing in the old triggerNow flow.
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
