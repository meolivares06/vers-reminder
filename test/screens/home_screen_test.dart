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

/// Channel used by `package_info_plus` — mocked so onboarding to AboutScreen
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

  testWidgets('Home About is now a tile that opens AboutScreen', (tester) async {
    await pumpHome(tester);

    // The About tile sits below the fold in the Home ListView; scroll to it.
    await tester.scrollUntilVisible(find.text('About'), 200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // No more inline share/version tiles — those moved to AboutScreen.
    expect(find.text('Share app'), findsNothing,
        reason: 'share tile moved to AboutScreen, not inlined on Home');

    // Tapping the About tile opens AboutScreen (which renders the update flow).
    await tester.tap(find.widgetWithText(ListTile, 'About'));
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsOneWidget,
        reason: 'About tile navigates to AboutScreen');
  });
}
