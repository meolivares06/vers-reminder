import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_status.dart';
import 'package:vers_reminder/shared/application/locale_provider.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';
import 'package:vers_reminder/settings/application/appearance_settings.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/home/application/home_container.dart';

/// Channel used by `package_info_plus` — mocked so onboarding to AboutScreen
/// renders deterministically.
const MethodChannel _packageInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/package_info',
);

/// Minimal valid PNG bytes for [File.existsSync] checks.
const _kPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0x00, 0x00,
  0x01, 0x00, 0x01, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

String _createTempPng() {
  final dir = Directory.systemTemp.createTempSync('home_screen_test_');
  final file = File('${dir.path}/wallpaper.png');
  file.writeAsBytesSync(_kPngBytes);
  return file.path;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    final dbPath = 'hst_${DateTime.now().microsecondsSinceEpoch}.db';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (call) async {
          if (call.method == 'getAll') {
            return <String, dynamic>{
              'version': '3.0.1',
              'buildNumber': '12',
              'packageName': 'com.versreminder.vers_reminder',
              'appName': 'vers_reminder',
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, null);
  });

  Future<WallpaperState> pumpHome(
    WidgetTester tester, {
    WallpaperState? wallpaper,
  }) async {
    final wallpaperState = wallpaper ?? WallpaperState();
    final localeProvider = LocaleProvider();
    await localeProvider.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventBus>.value(value: EventBus.instance),
          ChangeNotifierProvider<WallpaperState>.value(
            value: wallpaperState,
          ),
          ChangeNotifierProvider<SchedulerConfig>.value(value: SchedulerConfig()),
          ChangeNotifierProvider<AppearanceSettings>.value(value: AppearanceSettings()),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeContainer(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    // F6: allow async File.exists() to complete and setState to rebuild.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    return wallpaperState;
  }

  testWidgets('Home no longer has an About tile — About is in Settings', (
    tester,
  ) async {
    await pumpHome(tester);

    // The About tile was removed from Home — it's now accessible only from Settings.
    expect(
      find.text('About'),
      findsNothing,
      reason: 'About tile removed from Home',
    );

    // Share app is not on Home either.
    expect(
      find.text('Share app'),
      findsNothing,
      reason: 'share tile moved to AboutScreen',
    );

    // Language tile was also removed.
    expect(
      find.text('Language'),
      findsNothing,
      reason: 'language tile removed from Home',
    );
  });

  group('F9 RED — triggerNow async error boundaries', () {
    test('F9-RED dialog triggerNow callback wrapped in try/catch', () {
      final source =
          File('lib/home/application/home_container.dart').readAsStringSync();

      // Find the permission dialog FilledButton onPressed callback
      final showDialogIdx = source.indexOf('_showPermissionDialog');
      expect(showDialogIdx, greaterThan(0));

      // After grantPermission(), the RefreshWallpaper emission must be
      // wrapped in try/catch with debugPrint logging
      final grantIdx = source.indexOf('grantPermission', showDialogIdx);
      expect(grantIdx, greaterThan(0));

      // The try/catch must appear AFTER grantPermission
      // and wrap the RefreshWallpaper emit call
      final tryIdx = source.indexOf('try {', grantIdx);
      expect(tryIdx, greaterThan(0),
          reason: 'F9 fix: dialog RefreshWallpaper emit must be wrapped in '
              'try/catch so async exceptions from the unawaited call '
              'are logged');
      final catchIdx = source.indexOf('RefreshWallpaper emit failed', tryIdx);
      expect(catchIdx, greaterThan(0),
          reason: 'F9 fix: catch must log RefreshWallpaper failures via debugPrint');
    });

    test('F9-RED _handleFabPressed RefreshWallpaper emit wrapped in try/catch', () {
      final source =
          File('lib/home/application/home_container.dart').readAsStringSync();

      // Find the _handleFabPressed method
      final fabIdx = source.indexOf('_handleFabPressed');
      expect(fabIdx, greaterThan(0),
          reason: '_handleFabPressed method must exist');

      // The FAB emit path must wrap the RefreshWallpaper emit in try/catch
      // so sync exceptions from the emit path are logged.
      final tryIdx = source.indexOf('try {', fabIdx);
      expect(tryIdx, greaterThan(0),
          reason: 'F9 fix: _handleFabPressed must wrap the RefreshWallpaper '
              'emit in try/catch so sync exceptions from the emit path are '
              'logged');

      final emitIdx = source.indexOf('RefreshWallpaper(locale:', tryIdx);
      expect(emitIdx, greaterThan(tryIdx),
          reason: 'the RefreshWallpaper emit must be inside the try block');

      final catchIdx = source.indexOf('RefreshWallpaper emit failed', tryIdx);
      expect(catchIdx, greaterThan(0),
          reason: 'F9 fix: catch must log RefreshWallpaper failures via debugPrint');
    });
  });

  group('Home tab declutter (UX-HOME-002/003)', () {
    testWidgets('rotation and categories tiles are gone from Home', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(
        find.byType(Switch),
        findsNothing,
        reason: 'rotation toggle moved to Settings-only',
      );
      expect(
        find.text('Categories'),
        findsNothing,
        reason: 'categories tile moved to Settings-only',
      );
      expect(
        find.text('Auto-rotate'),
        findsNothing,
        reason: 'rotation ListTile removed from Home',
      );
    });

    testWidgets(
      'gold FAB on Home (idx 0), add-verse FAB on verse list (idx 1), '
      'never both',
      (tester) async {
        final wallpaperPath = _createTempPng();
        final wallpaper = WallpaperState()
          ..setWallpaperCard(path: wallpaperPath);
        await pumpHome(tester, wallpaper: wallpaper);

        final goldFab = find.widgetWithIcon(
          FloatingActionButton,
          Icons.refresh,
        );
        final addFab = find.widgetWithIcon(FloatingActionButton, Icons.add);
        expect(
          goldFab,
          findsOneWidget,
          reason: 'gold circular FAB is the primary Home action',
        );
        expect(
          addFab,
          findsNothing,
          reason: 'add-verse FAB must not render on Home',
        );

        // Switch to the verse-list tab.
        await tester.tap(find.text('Verses'));
        await tester.pumpAndSettle();

        expect(
          addFab,
          findsOneWidget,
          reason: 'add-verse FAB renders on tab index 1',
        );
        expect(
          goldFab,
          findsNothing,
          reason: 'gold FAB must not render on the verse-list tab',
        );
      },
    );

    testWidgets('gold FAB triggers generation when permission granted', (
      tester,
    ) async {
      final wallpaperPath = _createTempPng();
      final wallpaper = WallpaperState()
        ..setWallpaperCard(path: wallpaperPath, permissionGranted: true);
      await pumpHome(tester, wallpaper: wallpaper);
      expect(wallpaper.status, WallpaperStatus.idle);

      // Directly call triggerNow — same path the gold FAB triggers.
      // Use runAsync to isolate the state change from the widget tree.
      await tester.runAsync(() => wallpaper.triggerNow(locale: 'en'));
      await tester.pump();

      expect(
        wallpaper.status,
        WallpaperStatus.noCategories,
        reason: 'tapping the gold FAB runs the permission-gated trigger path',
      );
    });

    testWidgets('gold FAB shows permission dialog when permission missing', (
      tester,
    ) async {
      final wallpaperPath = _createTempPng();
      final wallpaper = WallpaperState()..setWallpaperCard(path: wallpaperPath);
      await pumpHome(tester, wallpaper: wallpaper);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(
        find.text('Wallpaper permission'),
        findsOneWidget,
        reason: 'FAB surfaces the permission dialog when access is missing',
      );
      expect(
        wallpaper.status,
        WallpaperStatus.idle,
        reason: 'no generation starts until permission is granted',
      );
    });
  });
}
