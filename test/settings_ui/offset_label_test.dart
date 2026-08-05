import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/shared/locale_provider.dart';
import 'package:vers_reminder/settings/appearance_settings.dart';
import 'package:vers_reminder/wallpaper/wallpaper_state.dart';
import 'package:vers_reminder/scheduler/scheduler_config.dart';
import 'package:vers_reminder/verses/verse_provider.dart';
import 'package:vers_reminder/settings/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, AppearanceSettings appearance) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppearanceSettings>.value(value: appearance),
          ChangeNotifierProvider<WallpaperState>.value(value: WallpaperState()),
          ChangeNotifierProvider<SchedulerConfig>.value(value: SchedulerConfig()),
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

  testWidgets('slider area no longer shows offset text labels',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = AppearanceSettings();
    settings.setHorizontalOffset(-5);

    await pumpSettings(tester, settings);

    // No offset caption — the slider is self-explanatory with its value label.
    expect(find.text('Offset: Left -5'), findsNothing,
        reason: 'offset text label was removed');
    expect(find.text('Left'), findsNothing);
    expect(find.text('Right'), findsNothing);
  });

  testWidgets('positive offset also has no text label',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = AppearanceSettings();
    settings.setHorizontalOffset(5);

    await pumpSettings(tester, settings);

    expect(find.text('Offset: Right 5'), findsNothing,
        reason: 'offset text label was removed');
    expect(find.text('Left'), findsNothing);
  });

  testWidgets('zero offset has no text label',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = AppearanceSettings();
    settings.setHorizontalOffset(0);

    await pumpSettings(tester, settings);

    expect(find.text('Offset: Right 0'), findsNothing,
        reason: 'offset text label was removed');
    expect(find.text('Left'), findsNothing);
  });
}