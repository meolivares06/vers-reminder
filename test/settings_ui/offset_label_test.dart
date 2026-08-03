import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/providers/locale_provider.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';
import 'package:vers_reminder/screens/settings/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, SettingsProvider settings) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<LocaleProvider>.value(value: LocaleProvider()),
          ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets('negative offset shows a single caption with Left direction',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    settings.setHorizontalOffset(-5);

    await pumpSettings(tester, settings);

    // Exactly one offset caption, resolved to Left.
    expect(find.text('Offset: Left -5'), findsOneWidget,
        reason: 'single caption derives Left from the negative offset');
    // No duplicate static left/right Row labels remain (UX-SET-002).
    expect(find.text('Right'), findsNothing,
        reason: 'the static right Row label is removed');
    expect(find.text('Offset: Right -5'), findsNothing,
        reason: 'no right word appears in the caption for a negative offset');
  });

  testWidgets('positive offset shows a single caption with Right direction',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    settings.setHorizontalOffset(5);

    await pumpSettings(tester, settings);

    expect(find.text('Offset: Right 5'), findsOneWidget,
        reason: 'single caption derived from sign for a positive offset');
    expect(find.text('Left'), findsNothing,
        reason: 'the static left Row label is removed');
  });

  testWidgets('only one offset-related text node exists in the slider area',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    settings.setHorizontalOffset(0);

    await pumpSettings(tester, settings);

    // The caption is the single offset text node; no duplicated offset labels.
    expect(find.text('Offset: Right 0'), findsOneWidget,
        reason: 'zero offset resolves to a single Right caption');
    expect(find.text('Left'), findsNothing,
        reason: 'no duplicate Left node in the zero state');
    expect(find.text('Right'), findsNothing,
        reason: 'no standalone Right static node');
  });
}