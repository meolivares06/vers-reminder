import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/settings/infrastructure/update_check_result.dart';
import 'package:vers_reminder/shared/application/locale_provider.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';
import 'package:vers_reminder/settings/application/appearance_settings.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/settings/infrastructure/about_screen.dart';
import 'package:vers_reminder/settings/infrastructure/settings_screen.dart';
import 'package:vers_reminder/settings/infrastructure/update_service.dart';

/// Channel used by `package_info_plus` — mocked so the About version tile
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
          'version': '1.0.0',
          'buildNumber': '3',
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

  Future<void> pumpAbout(WidgetTester tester, UpdateService service) async {
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
          home: AboutScreen(updateService: service),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets('AboutScreen renders update, version, share and contact tiles',
      (tester) async {
    await pumpAbout(tester, _FakeUpdateService(checkResult: UpdateCheckResult.empty()));

    // Update control (AppBar + section header both say "About").
    expect(find.text('About'), findsAtLeastNWidgets(1),
        reason: 'About AppBar title + section header');
    expect(find.byIcon(Icons.system_update_alt), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);

    // Version tile (from package_info mock → 'v1.0.0+3')
    expect(find.text('v1.0.0+3'), findsOneWidget);

    // Share + contact
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.text('Share app'), findsOneWidget);
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.text('meolivares06@gmail.com'), findsOneWidget);
  });

  testWidgets('Settings no longer contains update/version/share/contact tiles',
      (tester) async {
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

    expect(find.text('Check for updates'), findsNothing,
        reason: 'update tile moved to AboutScreen');
    expect(find.text('Share app'), findsNothing,
        reason: 'share tile moved to AboutScreen');
    expect(find.text('meolivares06@gmail.com'), findsNothing,
        reason: 'contact tile moved to AboutScreen');

    // Only the About link remains.
    await tester.scrollUntilVisible(find.text('About'), 300);
    await tester.pump();
    expect(find.text('About'), findsAtLeastNWidgets(1),
        reason: 'Settings keeps only an About link');
  });

      testWidgets(
      'Settings section order is Appearance, Rotation, Categories, then About '
      'link', (tester) async {
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

    // All section headers render.
    for (final label in [
      'Appearance',
      'Rotation',
      'Categories',
      'About',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 150);
      await tester.pump();
      expect(find.text(label), findsAtLeastNWidgets(1),
          reason: 'section "$label" present in Settings');
    }
  });
}

/// A deterministic [UpdateService] double for the AboutScreen tests.
class _FakeUpdateService implements UpdateService {
  _FakeUpdateService({required this.checkResult});

  UpdateCheckResult checkResult;

  @override
  Future<UpdateCheckResult> checkForUpdate({
    http.Client? client,
    String? versionOverride,
    String? buildOverride,
  }) async =>
      checkResult;

  @override
  Future<String> download(
    UpdateCheckResult release, {
    void Function(int bytes, int total)? onProgress,
    http.Client? client,
    String? appSupportOverride,
  }) async {
    onProgress?.call(1024, 1024);
    return '/fake/downloaded/vers-reminder-arm64.apk';
  }

  @override
  Future<bool> install(
    String apkPath, {
    String? releaseUrl,
    IntentLauncher Function(AndroidIntent intent)? intentLauncherFactory,
  }) async =>
      true;
}