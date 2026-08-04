import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/models/wallpaper_status.dart';
import 'package:vers_reminder/providers/locale_provider.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';
import 'package:vers_reminder/screens/home_screen.dart';

/// A minimal valid 1x1 PNG so [Image.file] can decode the wallpaper path.
const List<int> _pngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR length + tag
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, // bit depth/color
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, // IDAT length + tag
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A, // data
  0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82, // IEND
];

void main() {
  late Directory tempDir;
  late String wallpaperPath;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('wallpaper_card_test_');
    final file = File('${tempDir.path}/wallpaper.png');
    file.writeAsBytesSync(_pngBytes);
    wallpaperPath = file.path;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<SettingsProvider> pumpHome(
    WidgetTester tester,
    SettingsProvider settings, {
    Locale locale = const Locale('en'),
  }) async {
    final localeProvider = LocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    return settings;
  }

  testWidgets(
    'UX-HOME-001 card shows Current wallpaper + Updated label when path and '
    'timestamp are set',
    (tester) async {
      final settings = SettingsProvider()
        ..setWallpaperCard(path: wallpaperPath, timestamp: DateTime.now());
      await pumpHome(tester, settings);

      expect(
        find.text('Your wallpaper'),
        findsOneWidget,
        reason: 'localized label on the card when a wallpaper exists',
      );
      expect(
        find.textContaining('ago'),
        findsOneWidget,
        reason:
            'updatedAtLabel caption is derived from the persisted timestamp',
      );
      expect(
        find.text('Tap to create your first wallpaper'),
        findsNothing,
        reason: 'empty-state prompt must not render when a wallpaper exists',
      );
    },
  );

  testWidgets('UX-HOME-002 tapping the card triggers generation', (
    tester,
  ) async {
    final settings = SettingsProvider()
      ..setWallpaperCard(
        path: wallpaperPath,
        timestamp: DateTime.now(),
        permissionGranted: true,
      );
    await pumpHome(tester, settings);
    expect(settings.status, WallpaperStatus.idle);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // FAB overlay triggers generation via the same permission-gated path.
    expect(
      settings.status,
      WallpaperStatus.noCategories,
      reason: 'tapping the card runs the permission-gated trigger',
    );
  });

  testWidgets('UX-HOME-001 empty state shows prompt and no caption', (
    tester,
  ) async {
    final settings = SettingsProvider()
      ..setWallpaperCard(path: null, timestamp: null);
    await pumpHome(tester, settings);

    expect(
      find.text('Tap to create your first wallpaper'),
      findsOneWidget,
      reason: 'empty-state prompt guides the user to generate their first',
    );
    expect(
      find.text('Your wallpaper'),
      findsNothing,
      reason: 'no caption when no wallpaper exists',
    );
    expect(
      find.textContaining('ago'),
      findsNothing,
      reason: 'no updated-time caption in the empty state',
    );
  });

  testWidgets(
    'UX-HOME-001 card fills >90% of visible home height when wallpaper '
    'exists',
    (tester) async {
      final settings = SettingsProvider()
        ..setWallpaperCard(path: wallpaperPath, timestamp: DateTime.now());
      await pumpHome(tester, settings);

      final bodyHeight = tester.getSize(find.byType(IndexedStack)).height;
      final cardHeight = tester.getSize(find.byType(Card)).height;
      final fraction = cardHeight / bodyHeight;

      expect(
        fraction,
        inInclusiveRange(0.90, 0.99),
        reason:
            'card must fill >90% of the home body height (was '
            '${fraction.toStringAsFixed(3)})',
      );
    },
  );

  testWidgets(
    'UX-HOME-001 empty-state card keeps the same height fraction',
    (tester) async {
      final settings = SettingsProvider()
        ..setWallpaperCard(path: null, timestamp: null);
      await pumpHome(tester, settings);

      final bodyHeight = tester.getSize(find.byType(IndexedStack)).height;
      final cardHeight = tester.getSize(find.byType(Card)).height;
      final fraction = cardHeight / bodyHeight;

      expect(
        fraction,
        inInclusiveRange(0.90, 0.99),
        reason:
            'empty state must occupy the same height fraction as the '
            'wallpaper-present card (was '
            '${fraction.toStringAsFixed(3)})',
      );
    },
  );

  group('relative time caption buckets', () {
    Future<void> pumpWithOffset(WidgetTester tester, Duration age) async {
      final settings = SettingsProvider()
        ..setWallpaperCard(
          path: wallpaperPath,
          timestamp: DateTime.now().subtract(age),
        );
      await pumpHome(tester, settings);
    }

    testWidgets('under one minute renders the zero-minute caption', (
      tester,
    ) async {
      await pumpWithOffset(tester, const Duration(seconds: 20));
      expect(
        find.text('0 min ago'),
        findsOneWidget,
        reason: 'sub-minute age maps to timeMinutes(0)',
      );
    });

    testWidgets('a few minutes render the exact minute count', (tester) async {
      await pumpWithOffset(tester, const Duration(minutes: 5, seconds: 5));
      expect(
        find.text('5 min ago'),
        findsOneWidget,
        reason: 'ages under one hour map to timeMinutes(n)',
      );
    });

    testWidgets('over an hour renders the hour count', (tester) async {
      await pumpWithOffset(tester, const Duration(hours: 2, minutes: 5));
      expect(
        find.text('2 h ago'),
        findsOneWidget,
        reason: 'ages over one hour map to timeHours(n)',
      );
    });
  });
}
