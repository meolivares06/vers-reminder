import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/providers/locale_provider.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';
import 'package:vers_reminder/screens/home_screen.dart';

/// Channel used by `package_info_plus` — mocked so the Home About version tile
/// renders deterministically.
const MethodChannel _packageInfoChannel =
    MethodChannel('dev.fluttercommunity.plus/package_info');

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

  Future<void> pumpHome(WidgetTester tester) async {
    final localeProvider = LocaleProvider();
    await localeProvider.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
              value: SettingsProvider()),
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
  }

  testWidgets('Home About shows the dynamic installed version (no stale copy)',
      (tester) async {
    await pumpHome(tester);

    // The About section sits below the fold in the Home ListView; scroll to it
    // so its tiles are actually built.
    await tester.scrollUntilVisible(find.text('Share app'), 200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('v3.0.1+12'), findsOneWidget,
        reason: 'version tile reflects installed v{version}+{build}');
    expect(find.text('Version 1.0.0'), findsNothing,
        reason: 'stale hardcoded aboutVersion must never render');
  });

  testWidgets('Home About provides a Share tile', (tester) async {
    await pumpHome(tester);

    await tester.scrollUntilVisible(find.text('Share app'), 200);
    await tester.pump();

    expect(find.text('Share app'), findsOneWidget,
        reason: 'Share action mirrors the Settings screen');
  });
}
