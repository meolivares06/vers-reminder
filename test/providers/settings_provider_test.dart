import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
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

    // ── F11 RED: notifyListeners post-async safety comment ──
    test('F11-RED notifyListeners sites have Flutter 3.7+ dispose comment', () {
      final source =
          File('lib/providers/settings_provider.dart').readAsStringSync();

      // The triggerNow method has two post-async notifyListeners() calls
      // (L289 after getVersesByCategoryIds, L344 after generateAndSetWallpaper).
      // Both must document that Flutter 3.7+ handles dispose safely.
      final triggerNowIdx = source.indexOf('Future<void> triggerNow(');
      expect(triggerNowIdx, greaterThan(0),
          reason: 'triggerNow method must exist');

      final commentIdx = source.indexOf(
        'Flutter 3.7+ notifies are safe',
        triggerNowIdx,
      );
      expect(commentIdx, greaterThan(0),
          reason: 'F11 fix: post-async notifyListeners() calls in triggerNow '
              'must document Flutter 3.7+ dispose safety — '
              'no runtime _disposed guard needed');

      // Verify the comment appears BEFORE a notifyListeners call
      // immediately after the async gap (the no-verses path).
      final notifyAfterComment = source.indexOf(
        'notifyListeners();',
        commentIdx,
      );
      expect(notifyAfterComment, greaterThan(commentIdx),
          reason: 'comment must appear immediately before a post-async '
              'notifyListeners() call');

      // Verify there's a second occurrence of the comment (or at least that
      // the final notifyListeners is also guarded) — search past the first.
      final commentIdx2 = source.indexOf(
        'Flutter 3.7+ notifies are safe',
        commentIdx + 1,
      );
      expect(commentIdx2, greaterThan(0),
          reason: 'at least one more occurrence of the dispose-safety comment '
              'must exist near the final notifyListeners() in triggerNow');
    });

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
    // ── F3 RED: Non-blocking init ──
    test('init() sets isLoading=false before fire-and-forget pre-gen', () {
      final source =
          File('lib/providers/settings_provider.dart').readAsStringSync();

      // Scope search to init() method body (after 'Future<void> init()')
      final initStart = source.indexOf('Future<void> init()');
      expect(initStart, greaterThan(0),
          reason: 'init() method must exist');

      // Find _isLoading = false AFTER init() starts (not the field declaration)
      final loadingFalseIdx = source.indexOf(
        '_isLoading = false;',
        initStart,
      );
      expect(loadingFalseIdx, greaterThan(0),
          reason: '_isLoading must be set to false in init()');

      final preGenCallIdx = source.indexOf(
        '_preGenerateFutureWallpapers',
        initStart,
      );
      expect(preGenCallIdx, greaterThan(0),
          reason: '_preGenerateFutureWallpapers call must exist in init()');

      // RED: current code sets _isLoading=false AFTER pre-gen completes
      // GREEN: _isLoading=false BEFORE the fire-and-forget pre-gen call
      expect(loadingFalseIdx < preGenCallIdx, isTrue,
          reason: '_isLoading = false must appear before the '
              '_preGenerateFutureWallpapers call in init(), not after it');
    });

    test('pre-gen launched as fire-and-forget with catchError in init()', () {
      final source =
          File('lib/providers/settings_provider.dart').readAsStringSync();

      final initStart = source.indexOf('Future<void> init()');
      final initEnd = source.indexOf('Future<void> setHorizontalOffset',
          initStart + 1);

      // After fix: pre-gen in init() is wrapped in unawaited(...catchError(...))
      expect(source.contains('unawaited'), isTrue,
          reason: 'dart:async unawaited required for fire-and-forget pre-gen');
      expect(source.contains('catchError'), isTrue,
          reason: 'catchError required so pre-gen failures are logged, '
              'not propagated through init()');
    });

    test('isLoading is false after init() when scheduler disabled', () async {
      // Behavioral regression: existing behavior must NOT change
      final provider = SettingsProvider();
      await provider.init();

      expect(provider.isLoading, isFalse,
          reason: 'init() must always set isLoading to false when complete');
      expect(provider.isEnabled, isFalse,
          reason: 'scheduler disabled by default in test config');
    });

    // Task 2.3 REFACTOR: setEnabled() fire-and-forget pattern
    test('setEnabled() uses fire-and-forget pre-gen when enabled', () async {
      final source =
          File('lib/providers/settings_provider.dart').readAsStringSync();

      // setEnabled(true) at L194 (approximately) should use the same
      // unawaited + catchError pattern as init() for pre-gen
      final setEnabledIdx = source.indexOf('Future<void> setEnabled');
      expect(setEnabledIdx, greaterThan(0));

      // Search for pre-gen call within setEnabled's body
      final preGenInSetEnabled = source.indexOf(
        '_preGenerateFutureWallpapers',
        setEnabledIdx,
      );
      expect(preGenInSetEnabled, greaterThan(0),
          reason: 'setEnabled() must call pre-gen when enabled');

      // After fix: same fire-and-forget pattern as init
      final unawaitedInSetEnabled = source.indexOf(
        'unawaited',
        setEnabledIdx,
      );
      expect(unawaitedInSetEnabled, greaterThan(0),
          reason: 'setEnabled() pre-gen must use unawaited (non-blocking)');
      expect(unawaitedInSetEnabled < preGenInSetEnabled, isTrue,
          reason: 'unawaited must wrap the pre-gen call in setEnabled()');
    });

    // ── F4 / F5 RED: Re-entrancy guard + pre-gen mutex ──

    test('F4-RED concurrent triggerNow produces exactly one generation',
        () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );

      final fake = _CountingFakeGenerator();
      final provider = SettingsProvider(wallpaperGenerator: fake);
      await provider.init();
      await provider.toggleCategory(1);

      // Fire two triggerNow calls concurrently — the guard must block
      // the second one from reaching generateAndSetWallpaper.
      final f1 =
          provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      final f2 =
          provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      await Future.wait([f1, f2]);

      expect(fake.generateCallCount, 1,
          reason: 'only one generateAndSetWallpaper call must proceed; '
              'the second triggerNow must return early via the re-entrancy '
              'guard');
    });

    test('F4-RED retry after error is allowed by the guard', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );

      final fake = _CountingFakeGenerator();
      final provider = SettingsProvider(wallpaperGenerator: fake);
      await provider.init();
      await provider.toggleCategory(1);

      // Simulate a failed generation: the guard must NOT block retries.
      await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      expect(fake.generateCallCount, 1);
      expect(provider.status, WallpaperStatus.updated);

      // Artificially set status to error so we can test the retry path.
      // (The guard must only skip when status == generating, not error.)
      provider.setStatusForTest(WallpaperStatus.error);

      await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');

      expect(fake.generateCallCount, 2,
          reason: 'retry after error must pass the guard and '
              'call generateAndSetWallpaper again');
    });

    test('F5-RED mutex blocks overlapping pre-gen in triggerNow path',
        () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );

      // A generator whose preGenerateWallpapers is slow enough that a
      // second triggerNow can reach the mutex while the first is still
      // inside pre-gen.
      final fake = _SlowCountingPreGenGenerator();
      final provider = SettingsProvider(wallpaperGenerator: fake);
      await provider.init();
      await provider.toggleCategory(1);

      // First triggerNow: generates + calls slow pre-gen (starts delay).
      final f1 =
          provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      // Give pre-gen enough time to enter the mutex before the second
      // triggerNow finishes its own generateAndSetWallpaper step.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Second triggerNow: generation succeeds, then calls pre-gen —
      // the mutex should skip it because the first pre-gen is still running.
      final f2 =
          provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      await Future.wait([f1, f2]);

      expect(fake.preGenCallCount, 1,
          reason: 'the second triggerNow must find the mutex locked '
              'and skip its pre-gen call entirely');
    });

    test('F5-RED mutex resets so a sequential pre-gen call succeeds', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertVerse(
        Verse(textEs: 'Texto', citation: 'Juan 3:16'),
        [1],
      );

      final fake = _CountingFakeGenerator();
      final provider = SettingsProvider(wallpaperGenerator: fake);
      await provider.init();
      await provider.toggleCategory(1);

      // First full triggerNow: generates + pre-gen completes.
      await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      expect(fake.generateCallCount, 1);
      expect(fake.preGenCallCount, 1);

      // Second triggerNow — the mutex must have been reset so pre-gen
      // runs again.
      await provider.triggerNow(verseProvider: VerseProvider(), locale: 'es');
      expect(fake.generateCallCount, 2);
      expect(fake.preGenCallCount, 2,
          reason: 'the mutex must be reset after the first pre-gen '
              'completes so sequential calls are not blocked');
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

/// A generator whose [preGenerateWallpapers] takes a deliberate delay,
/// used to prove that [SettingsProvider.init] returns before pre-gen
/// completes (non-blocking F3 fix).
class _SlowPreGenGenerator extends _FakeWallpaperGenerator {
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 0;
  }
}

/// A generator that counts calls to both [generateAndSetWallpaper] and
/// [preGenerateWallpapers], used to prove re-entrancy (F4) and mutex (F5)
/// guards.
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

/// A generator whose [preGenerateWallpapers] is slow (300 ms) and counted,
/// used to prove the F5 mutex blocks overlapping pre-gen calls.
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

/// A generator whose [preGenerateWallpapers] always throws,
/// used to prove that init recovers gracefully (fire-and-forget
/// with catchError) and the app stays loaded.
class _ThrowingPreGenGenerator extends _FakeWallpaperGenerator {
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
    throw Exception('simulated pre-gen failure');
  }
}
