import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/providers/locale_provider.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';
import 'package:vers_reminder/screens/home_screen.dart';
import 'package:vers_reminder/screens/settings/settings_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHome(
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
  }

  testWidgets('UX-HOME-003 localized active-categories count renders in EN',
      (tester) async {
    final settings = SettingsProvider()
      ..setActiveCategoriesForTest({1, 2, 3});
    await pumpHome(tester, settings, locale: const Locale('en'));

    expect(find.text('Active: 3'), findsOneWidget,
        reason: 'localized pluralized count for 3 active categories');
  });

  testWidgets('UX-HOME-003 localized active-categories count renders in ES',
      (tester) async {
    final settings = SettingsProvider()
      ..setActiveCategoriesForTest({1, 2, 3});
    await pumpHome(tester, settings, locale: const Locale('es'));

    expect(find.text('Activas: 3'), findsOneWidget,
        reason: 'Spanish l10n for the active-categories count');
  });

  testWidgets('UX-HOME-003 tapping the tile navigates to Settings',
      (tester) async {
    final settings = SettingsProvider()
      ..setActiveCategoriesForTest({1, 2, 3});
    await pumpHome(tester, settings);

    // The categories tile sits below the fold in the Home ListView; scroll so
    // its tap target is actually hittable.
    await tester.scrollUntilVisible(find.text('Categories'), 200);
    await tester.pump();

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget,
        reason: 'tapping the tile opens the Settings screen');
  });
}
