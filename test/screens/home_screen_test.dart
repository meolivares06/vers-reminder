import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_status.dart';
import 'package:vers_reminder/shared/locale_provider.dart';
import 'package:vers_reminder/shared/settings_provider.dart';
import 'package:vers_reminder/verses/verse_provider.dart';
import 'package:vers_reminder/home/home_screen.dart';

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
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
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

  Future<SettingsProvider> pumpHome(
    WidgetTester tester, {
    SettingsProvider? settings,
  }) async {
    final settingsProvider = settings ?? SettingsProvider();
    final localeProvider = LocaleProvider();
    await localeProvider.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    // F6: allow async File.exists() to complete and setState to rebuild.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    return settingsProvider;
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
          File('lib/home/home_screen.dart').readAsStringSync();

      // Find the permission dialog FilledButton onPressed callback
      final showDialogIdx = source.indexOf('_showPermissionDialog');
      expect(showDialogIdx, greaterThan(0));

      // After grantWallpaperPermission(), the triggerNow call at ~L84
      // must be wrapped in try/catch with debugPrint logging
      final grantIdx = source.indexOf('grantWallpaperPermission',
          showDialogIdx);
      expect(grantIdx, greaterThan(0));

      // The try/catch must appear AFTER grantWallpaperPermission
      // and wrap the triggerNow call
      final tryIdx = source.indexOf('try {', grantIdx);
      expect(tryIdx, greaterThan(0),
          reason: 'F9 fix: dialog triggerNow must be wrapped in try/catch '
              'at ~L84 so async exceptions from the unawaited call are logged');
      final catchIdx = source.indexOf('triggerNow failed', tryIdx);
      expect(catchIdx, greaterThan(0),
          reason: 'F9 fix: catch must log triggerNow failures via debugPrint');
    });

    test('F9-RED _triggerNow VoidCallback body wrapped in try/catch', () {
      final source =
          File('lib/home/home_screen.dart').readAsStringSync();

      // Find the _triggerNow method
      final triggerNowIdx = source.indexOf('VoidCallback _triggerNow(');
      expect(triggerNowIdx, greaterThan(0),
          reason: '_triggerNow method must exist');

      // The body of _triggerNow (the anonymous VoidCallback at ~L342)
      // must wrap settings.triggerNow in try/catch
      final tryIdx = source.indexOf('try {', triggerNowIdx);
      expect(tryIdx, greaterThan(0),
          reason: 'F9 fix: _triggerNow body at ~L342 must wrap '
              'triggerNow in try/catch so sync exceptions are caught');

      final triggerNowCallIdx = source.indexOf('settings.triggerNow',
          tryIdx);
      expect(triggerNowCallIdx, greaterThan(tryIdx),
          reason: 'the triggerNow call must be inside the try block');

      final catchIdx = source.indexOf('triggerNow failed', tryIdx);
      expect(catchIdx, greaterThan(0),
          reason: 'F9 fix: catch must log triggerNow failures via debugPrint');
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
        final settings = SettingsProvider()
          ..setWallpaperCard(path: wallpaperPath);
        await pumpHome(tester, settings: settings);

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
      final settings = SettingsProvider()
        ..setWallpaperCard(path: wallpaperPath, permissionGranted: true);
      await pumpHome(tester, settings: settings);
      expect(settings.status, WallpaperStatus.idle);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(
        settings.status,
        WallpaperStatus.noCategories,
        reason: 'tapping the gold FAB runs the permission-gated trigger path',
      );
    });

    testWidgets('gold FAB shows permission dialog when permission missing', (
      tester,
    ) async {
      final wallpaperPath = _createTempPng();
      final settings = SettingsProvider()..setWallpaperCard(path: wallpaperPath);
      await pumpHome(tester, settings: settings);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(
        find.text('Wallpaper permission'),
        findsOneWidget,
        reason: 'FAB surfaces the permission dialog when access is missing',
      );
      expect(
        settings.status,
        WallpaperStatus.idle,
        reason: 'no generation starts until permission is granted',
      );
    });
  });
}
