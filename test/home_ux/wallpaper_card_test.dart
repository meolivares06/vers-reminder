import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_status.dart';
import 'package:vers_reminder/shared/application/locale_provider.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';
import 'package:vers_reminder/settings/application/appearance_settings.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/home/application/home_container.dart';

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

  Future<WallpaperState> pumpHome(
    WidgetTester tester,
    WallpaperState wallpaper, {
    Locale locale = const Locale('es'),
  }) async {
    final localeProvider = LocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventBus>.value(value: EventBus.instance),
          ChangeNotifierProvider<WallpaperState>.value(value: wallpaper),
          ChangeNotifierProvider<SchedulerConfig>.value(
            value: SchedulerConfig(),
          ),
          ChangeNotifierProvider<AppearanceSettings>.value(
            value: AppearanceSettings(),
          ),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
          ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
        ],
        child: MaterialApp(
          locale: locale,
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
    // Extra settle for localization to load and text to render.
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    return wallpaper;
  }

  testWidgets(
    'UX-HOME-001 card shows Current wallpaper + Updated label when path and '
    'timestamp are set',
    (tester) async {
      final wallpaper = WallpaperState()
        ..setWallpaperCard(path: wallpaperPath, timestamp: DateTime.now());
      await pumpHome(tester, wallpaper);

      expect(
        find.text('Current wallpaper'),
        findsOneWidget,
        reason: 'localized label on the card when a wallpaper exists',
      );
      expect(
        find.textContaining('Updated'),
        findsOneWidget,
        reason:
            'updatedAtLabel caption is derived from the persisted timestamp',
      );
      expect(
        find.text('No wallpaper yet. Tap to generate your first one.'),
        findsNothing,
        reason: 'empty-state prompt must not render when a wallpaper exists',
      );
    },
  );

  testWidgets('UX-HOME-002 tapping the card triggers generation', (
    tester,
  ) async {
    final wallpaper = WallpaperState()
      ..setWallpaperCard(
        path: wallpaperPath,
        timestamp: DateTime.now(),
        permissionGranted: true,
      );
    await pumpHome(tester, wallpaper);
    expect(wallpaper.status, WallpaperStatus.idle);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // FAB overlay triggers generation via the same permission-gated path.
    expect(
      wallpaper.status,
      WallpaperStatus.noCategories,
      reason: 'tapping the card runs the permission-gated trigger',
    );
  });

  testWidgets('UX-HOME-001 empty state shows prompt and no caption', (
    tester,
  ) async {
    final wallpaper = WallpaperState()
      ..setWallpaperCard(path: null, timestamp: null);
    await pumpHome(tester, wallpaper);

    expect(
      find.text('No wallpaper yet. Tap to generate your first one.'),
      findsOneWidget,
      reason: 'empty-state prompt guides the user to generate their first',
    );
    expect(
      find.text('Current wallpaper'),
      findsNothing,
      reason: 'no caption when no wallpaper exists',
    );
    expect(
      find.textContaining('Updated'),
      findsNothing,
      reason: 'no updated-time caption in the empty state',
    );
  });

  testWidgets(
    'UX-HOME-001 card fills >90% of visible home height when wallpaper '
    'exists',
    (tester) async {
      final wallpaper = WallpaperState()
        ..setWallpaperCard(path: wallpaperPath, timestamp: DateTime.now());
      await pumpHome(tester, wallpaper);

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
      final wallpaper = WallpaperState()
        ..setWallpaperCard(path: null, timestamp: null);
      await pumpHome(tester, wallpaper);

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
      final wallpaper = WallpaperState()
        ..setWallpaperCard(
          path: wallpaperPath,
          timestamp: DateTime.now().subtract(age),
        );
      await pumpHome(tester, wallpaper);
    }

    testWidgets('under one minute renders the zero-minute caption', (
      tester,
    ) async {
      await pumpWithOffset(tester, const Duration(seconds: 20));
      expect(
        find.text('Updated 0 min'),
        findsOneWidget,
        reason: 'sub-minute age maps to timeMinutes(0)',
      );
    });

    testWidgets('a few minutes render the exact minute count', (tester) async {
      await pumpWithOffset(tester, const Duration(minutes: 5, seconds: 5));
      expect(
        find.text('Updated 5 min'),
        findsOneWidget,
        reason: 'ages under one hour map to timeMinutes(n)',
      );
    });

    testWidgets('over an hour renders the hour count', (tester) async {
      await pumpWithOffset(tester, const Duration(hours: 2, minutes: 5));
      expect(
        find.text('Updated 2 h'),
        findsOneWidget,
        reason: 'ages over one hour map to timeHours(n)',
      );
    });
  });

  // ── F6 RED: Async file check replaces existsSync in build ──

  group('F6 async file check (UX-HOME-001)', () {
    test('F6-RED existsSync absent from _HomeTabState.build', () {
      final source =
          File('lib/home/home_screen.dart').readAsStringSync();

      // Locate the _HomeTabState.build() method.
      final buildStart = source.indexOf('Widget build(BuildContext context) {',
          source.indexOf('class _HomeTabState'));
      expect(buildStart, greaterThan(0),
          reason: '_HomeTabState.build method must exist');

      // Find the closing brace of build() (scan forward from the method body).
      final buildEnd = _findMethodEnd(source, buildStart);
      final buildBody = source.substring(buildStart, buildEnd);

      // RED: existsSync must NOT appear inside _HomeTabState.build().
      expect(buildBody.contains('existsSync'), isFalse,
          reason: '_HomeTabState.build() must not call File.existsSync() — '
              'the existence check must use the cached _wallpaperFileExists '
              'flag updated asynchronously');
    });

    testWidgets(
      'F6-GREEN card renders with cached _wallpaperFileExists flag after '
      'existsSync removal',
      (tester) async {
        final wallpaper = WallpaperState()
          ..setWallpaperCard(path: wallpaperPath, timestamp: DateTime.now());
        await pumpHome(tester, wallpaper);
        // Allow the async file-existence check to settle.
        await tester.pump(const Duration(milliseconds: 200));

        // Card must render the wallpaper — the optimistic flag (true when
        // path is non-null) holds because the temp file exists.
        expect(find.byType(Card), findsOneWidget);
        expect(
          find.byType(Image),
          findsOneWidget,
          reason: 'cached _wallpaperFileExists flag allows the Image widget '
              'to render without sync existsSync in build',
        );
      },
    );
  });
}

/// Returns the index of the closing brace that matches the opening at
/// [start] (which should point to the `{` after a method/class signature).
int _findMethodEnd(String source, int start) {
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    if (source[i] == '{') {
      depth++;
    } else if (source[i] == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return source.length;
}
