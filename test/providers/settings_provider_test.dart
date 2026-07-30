import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/database/database_service.dart';
import 'package:vers_reminder/models/wallpaper_status.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dbPath = 'sp_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE verses (id INTEGER PRIMARY KEY AUTOINCREMENT, textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, createdAt TEXT NOT NULL)');
        await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE verse_categories (verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)');
        await db.execute('CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\')');
        await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
      }),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('SettingsProvider', () {
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
      await provider.triggerNow(
        verseProvider: VerseProvider(),
        locale: 'es',
      );

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
      await provider.triggerNow(
        verseProvider: VerseProvider(),
        locale: 'es',
      );

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

    test('setFrequency updates value', () async {
      final provider = SettingsProvider();
      await provider.init();

      await provider.setFrequency(60);
      expect(provider.frequencyMinutes, 60);

      final config = await DatabaseService.instance.getAppConfig();
      expect(config['frequency_minutes'], 60);
    });
  });
}
