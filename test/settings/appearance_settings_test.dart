import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/settings/application/appearance_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dbPath = 'as_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\', wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('AppearanceSettings', () {
    // ── Initial state ──
    test('init loads defaults when no prefs set', () async {
      final settings = AppearanceSettings();
      await settings.init();

      expect(settings.fontScale, 1.0);
      expect(settings.horizontalOffset, 0);
      expect(settings.verticalAlignment, 'center');
      expect(settings.calibratedInset, 0);
      expect(settings.useMyWallpaper, false);
      expect(settings.userBackgroundPath, isNull);
    });

    test('init loads persisted values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'horizontal_offset': 50,
        'vertical_alignment': 'top',
        'calibrated_inset': 20,
        'font_scale': 1.2,
        'use_my_wallpaper': true,
        'user_background_path': '/tmp/my_bg.png',
      });

      final settings = AppearanceSettings();
      await settings.init();

      expect(settings.horizontalOffset, 50);
      expect(settings.verticalAlignment, 'top');
      expect(settings.calibratedInset, 20);
      expect(settings.fontScale, 1.2);
      expect(settings.useMyWallpaper, true);
      expect(settings.userBackgroundPath, '/tmp/my_bg.png');
    });

    // ── setFontScale ──
    test('setFontScale updates value and persists', () async {
      final settings = AppearanceSettings();
      await settings.init();

      await settings.setFontScale(1.5);

      expect(settings.fontScale, 1.5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('font_scale'), 1.5);
    });

    // ── setHorizontalOffset ──
    test('setHorizontalOffset updates value and persists', () async {
      final settings = AppearanceSettings();
      await settings.init();

      await settings.setHorizontalOffset(100);

      expect(settings.horizontalOffset, 100);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('horizontal_offset'), 100);
    });

    // ── setVerticalAlignment ──
    test('setVerticalAlignment updates value and persists', () async {
      final settings = AppearanceSettings();
      await settings.init();

      await settings.setVerticalAlignment('bottom');

      expect(settings.verticalAlignment, 'bottom');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vertical_alignment'), 'bottom');
    });

    // ── setCalibratedInset ──
    test('setCalibratedInset updates value and persists', () async {
      final settings = AppearanceSettings();
      await settings.init();

      await settings.setCalibratedInset(30);

      expect(settings.calibratedInset, 30);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('calibrated_inset'), 30);
    });

    // ── setUseMyWallpaper ──
    test('setUseMyWallpaper updates value and persists', () async {
      final settings = AppearanceSettings();
      await settings.init();

      await settings.setUseMyWallpaper(true);

      expect(settings.useMyWallpaper, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_my_wallpaper'), true);
    });

    test('useMyWallpaper persists across provider recreation', () async {
      final s1 = AppearanceSettings();
      await s1.init();

      expect(s1.useMyWallpaper, false);
      await s1.setUseMyWallpaper(true);
      expect(s1.useMyWallpaper, true);

      final s2 = AppearanceSettings();
      await s2.init();
      expect(s2.useMyWallpaper, true,
          reason: 'recreated provider should load persisted true');
    });

    // ── setUserBackgroundPath ──
    test('userBackgroundPath persists across recreation', () async {
      final s1 = AppearanceSettings();
      await s1.init();

      const testPath = '/test/path/user_bg.png';
      await s1.setUserBackgroundPath(testPath);
      expect(s1.userBackgroundPath, testPath);

      final s2 = AppearanceSettings();
      await s2.init();
      expect(s2.userBackgroundPath, testPath);
    });

    test('setUserBackgroundPath with null removes key', () async {
      final settings = AppearanceSettings();
      await settings.init();

      await settings.setUserBackgroundPath('/some/path.png');
      expect(settings.userBackgroundPath, isNotNull);

      await settings.setUserBackgroundPath(null);
      expect(settings.userBackgroundPath, isNull);

      final s2 = AppearanceSettings();
      await s2.init();
      expect(s2.userBackgroundPath, isNull);
    });
  });
}
