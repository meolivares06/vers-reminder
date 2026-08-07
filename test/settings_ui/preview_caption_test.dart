import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/shared/application/locale_provider.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';
import 'package:vers_reminder/settings/application/appearance_settings.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/home/application/home_container.dart';
import 'package:vers_reminder/settings/infrastructure/settings_screen.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperState>.value(
              value: WallpaperState()),
          ChangeNotifierProvider<SchedulerConfig>.value(value: SchedulerConfig()),
          ChangeNotifierProvider<AppearanceSettings>.value(value: AppearanceSettings()),
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

  testWidgets('Settings Appearance preview no longer shows a Preview caption',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await pumpSettings(tester);

    expect(find.text('Preview'), findsNothing,
        reason: 'Preview badge was removed — preview is self-explanatory');
  });

  testWidgets('Home shows Current wallpaper caption (not Preview)',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final localeProvider = LocaleProvider();
    await localeProvider.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperState>.value(
              value: WallpaperState()),
          ChangeNotifierProvider<SchedulerConfig>.value(value: SchedulerConfig()),
          ChangeNotifierProvider<AppearanceSettings>.value(value: AppearanceSettings()),
          ChangeNotifierProvider<LocaleProvider>.value(
              value: localeProvider),
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

    // Home wallpaper card carries the live-caption, not the composition one.
    expect(find.text('Preview'), findsNothing,
        reason: 'Home uses Current wallpaper, not Preview');
  });
}