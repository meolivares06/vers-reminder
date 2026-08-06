import 'dart:async';

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
import 'package:vers_reminder/shared/widgets/async_action_button.dart';

/// Channel used by `package_info_plus` — mocked so `_loadVersion` does not
/// hit a real platform channel in tests.
const MethodChannel _packageInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/package_info',
);

/// An update the screen reports as available (mirrors the fixture used by the
/// service tests).
///
/// The tag keeps the `%2B` encoding (`+` in `v1.2.0+1`) — GitHub's download
/// URLs encode the tag's `+` as `%2B`. Reviewers must NOT "fix" this.
const UpdateCheckResult _availableResult = UpdateCheckResult(
  available: true,
  tagName: 'v1.2.0+1',
  downloadUrl:
      'https://github.com/meolivares06/vers-reminder/releases/download/'
      'v1.2.0%2B1/vers-reminder-arm64.apk',
  assetName: 'vers-reminder-arm64.apk',
  sizeBytes: 1024,
);

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

  testWidgets('Sc.1 check finds an update available: tile subtitle and confirm '
      'dialog with Download/Cancel', (tester) async {
    final service = _FakeUpdateService(checkResult: _availableResult);
    await _pumpAboutScreen(tester, service);

    expect(find.text('Check for updates'), findsOneWidget);
    expect(
      find.text('Update available: v1.2.0+1'),
      findsNothing,
      reason: 'no subtitle before the check runs',
    );

    await tester.tap(find.text('Check for updates'));
    await _pumpAndPause(tester);

    // The tile subtitle and the confirmation dialog title share the same
    // l10n string ("Update available: v1.2.0+1").
    expect(
      find.text('Update available: v1.2.0+1'),
      findsAtLeastNWidgets(2),
      reason: 'tile subtitle + confirm dialog title',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(
        'A new version (v1.2.0+1) is available. Download '
        '(approx. 1 KB)? It preserves your wallpapers and settings.',
      ),
      findsOneWidget,
    );
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Sc.2 cancel dismisses the confirm dialog without downloading', (
    tester,
  ) async {
    final service = _FakeUpdateService(checkResult: _availableResult);
    await _pumpAboutScreen(tester, service);

    await tester.tap(find.text('Check for updates'));
    await _pumpAndPause(tester);

    await tester.tap(find.text('Cancel'));
    await _pumpAndPause(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      service.downloadCalls,
      isEmpty,
      reason: 'cancelling the confirm dialog must not start a download',
    );
  });

  testWidgets(
    'Sc.2 confirming download shows a progress dialog that updates live as '
    'the stream advances and can be canceled',
    (tester) async {
      // Progress and completion are driven by the test through these controllers
      // so the dialog's live updates are asserted frame by frame (not drawn once
      // from a synchronous pre-frame report).
      final progress = StreamController<(int, int)>.broadcast(sync: true);
      final completion = Completer<String>();
      final service = _FakeUpdateService(
        checkResult: _availableResult,
        progressController: progress,
        downloadController: completion,
      );
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      await tester.tap(find.text('Download'));
      await _pumpAndPause(tester);

      expect(
        service.downloadCalls,
        hasLength(1),
        reason: 'Download starts the download',
      );
      expect(find.text('Downloading update...'), findsOneWidget);
      expect(
        find.text('Downloading update... 0%'),
        findsOneWidget,
        reason: 'no progress reported before the stream advances',
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Advance the stream → the dialog renders the new percentage live.
      progress.add((512, 1024));
      await tester.pump();
      expect(
        find.text('Downloading update... 50%'),
        findsOneWidget,
        reason: 'dialog updates live as the stream advances',
      );

      progress.add((768, 1024));
      await tester.pump();
      expect(find.text('Downloading update... 75%'), findsOneWidget);

      // The progress dialog is barrier-dismissible (cancelable).
      await tester.tapAt(const Offset(10, 10));
      await _pumpAndPause(tester);
      expect(find.byType(AlertDialog), findsNothing);

      // Teardown: release the driving stream. The download is left in-flight on
      // purpose (the screen awaits its completer) — an in-flight future is not a
      // pending timer, so it will not fail the test. NOT awaited: a pending
      // close() would hang the fake-async test zone.
      progress.close();
    },
  );

  testWidgets(
    'Sc.3 download completes: progress closes, Install action shown',
    (tester) async {
      final controller = Completer<String>();
      final service = _FakeUpdateService(
        checkResult: _availableResult,
        downloadController: controller,
      );
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      await tester.tap(find.text('Download'));
      await _pumpAndPause(tester);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      controller.complete('/fake/downloaded/vers-reminder-arm64.apk');
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);

      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: 'progress dialog closes on completion',
      );
      expect(
        find.text('Download complete. Install the update now?'),
        findsOneWidget,
      );
      expect(find.text('Install'), findsOneWidget);
    },
  );

  testWidgets(
    'Sc.3b barrier-dismissing the progress dialog then completing the '
    'download does not pop Settings and still shows the Install action',
    (tester) async {
      final controller = Completer<String>();
      final service = _FakeUpdateService(
        checkResult: _availableResult,
        downloadController: controller,
      );
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      await tester.tap(find.text('Download'));
      await _pumpAndPause(tester);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // User taps the barrier to dismiss the progress dialog mid-download.
      await tester.tapAt(const Offset(10, 10));
      await _pumpAndPause(tester);
      expect(find.byType(AlertDialog), findsNothing);

      // Settings is still on screen, not popped by the dismissal.
      expect(
        find.text('Check for updates'),
        findsOneWidget,
        reason: 'dismissing the progress dialog must not leave Settings',
      );

      // Download completes after the dialog was dismissed: the guarded pop must
      // no-op and the Install action must still surface, all within Settings.
      controller.complete('/fake/downloaded/vers-reminder-arm64.apk');
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text('Download complete. Install the update now?'),
        findsOneWidget,
        reason: 'install action still shows after barrier-dismiss + completion',
      );
      expect(find.text('Install'), findsOneWidget);
      expect(
        find.text('Check for updates'),
        findsOneWidget,
        reason: 'Settings route was not popped',
      );
    },
  );

  testWidgets(
    'Sc.4 installing fires the install flow with the downloaded APK',
    (tester) async {
      final service = _FakeUpdateService(
        checkResult: _availableResult,
        installResult: true,
      );
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      await tester.tap(find.text('Download'));
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);
      await tester.tap(find.text('Install'));
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);

      expect(
        service.installCalls,
        ['/fake/downloaded/vers-reminder-arm64.apk'],
        reason: 'Install triggers the service install flow with the APK',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text("Couldn't install the update"),
        findsNothing,
        reason: 'no failure feedback on a successful install',
      );
    },
  );

  testWidgets(
    'Sc.4b install hands back the release page URL (not the APK URL)',
    (tester) async {
      final service = _FakeUpdateService(
        checkResult: _availableResult,
        installResult: false,
      );
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      await tester.tap(find.text('Download'));
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);
      await tester.tap(find.text('Install'));
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);

      expect(
        service.installReleaseUrls,
        ['https://github.com/meolivares06/vers-reminder/releases/tag/v1.2.0+1'],
        reason:
            'the browser fallback must land on the release page, not the '
            'raw APK download URL',
      );
      expect(
        find.text("Couldn't install the update"),
        findsOneWidget,
        reason: 'a false install return surfaces the install failure copy',
      );
    },
  );

  testWidgets('Sc.5 no update available: up-to-date snackbar, no dialog', (
    tester,
  ) async {
    final service = _FakeUpdateService(checkResult: UpdateCheckResult.empty());
    await _pumpAboutScreen(tester, service);

    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Update available: v1.2.0+1'), findsNothing);
  });

  testWidgets('Sc.6 check fails on network error: error snackbar with Retry', (
    tester,
  ) async {
    final service = _FakeUpdateService(
      checkResult: UpdateCheckResult.failure('boom'),
    );
    await _pumpAboutScreen(tester, service);

    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't check for updates"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // Retry re-runs the check instead of crashing.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.checkCalls, 2);
  });

  testWidgets(
    'C2 cancel on the confirm dialog returns to idle and re-enables the '
    'tile (can re-trigger a check)',
    (tester) async {
      final service = _FakeUpdateService(checkResult: _availableResult);
      await _pumpAboutScreen(tester, service);

      // First check surfaces the confirm dialog.
      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(service.checkCalls, 1);

      // Cancel: the dialog closes and the tile must return to idle.
      await tester.tap(find.text('Cancel'));
      await _pumpAndPause(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Update available: v1.2.0+1'),
        findsNothing,
        reason:
            'cancelling the dialog clears the "available" subtitle and '
            'returns the state machine to idle',
      );

      // The tile is tappable again → triggers a fresh check.
      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      expect(
        service.checkCalls,
        2,
        reason: 'cancel must not leave the tile disabled forever',
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets(
    'C2 download failure shows Retry that re-runs the download and leaves '
    'the tile re-triggerable',
    (tester) async {
      final service = _FakeUpdateService(
        checkResult: _availableResult,
        downloadError: StateError('network'),
      );
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      await tester.tap(find.text('Download'));
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);

      // Distinct download-failure copy + a Retry action.
      expect(find.text("Couldn't download the update"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(service.downloadCalls, hasLength(1));

      // Retry re-runs the download with the same release.
      await tester.tap(find.text('Retry'));
      await _pumpAndPause(tester);
      await _pumpAndPause(tester);
      expect(
        service.downloadCalls,
        hasLength(2),
        reason: 'Retry re-runs the download',
      );
      expect(
        find.text("Couldn't download the update"),
        findsOneWidget,
        reason: 'second attempt also fails deterministically',
      );

      // The failure also returns to `idle`, so the tile re-check path is open.
      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      expect(
        service.checkCalls,
        2,
        reason: 'after a download failure the tile can still trigger a check',
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets(
    'confirm dialog is not barrier-dismissible and cannot strand the tile',
    (tester) async {
      final service = _FakeUpdateService(checkResult: _availableResult);
      await _pumpAboutScreen(tester, service);

      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      // A barrier tap must NOT dismiss the confirm dialog — otherwise the state
      // machine stays in `available` and the tile stays disabled forever.
      await tester.tapAt(const Offset(10, 10));
      await _pumpAndPause(tester);
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'confirm dialog must not be dismissible via the barrier',
      );

      // The only exits are explicit buttons: Cancel returns to idle.
      await tester.tap(find.text('Cancel'));
      await _pumpAndPause(tester);
      expect(find.byType(AlertDialog), findsNothing);

      // The tile is tappable again → a fresh check can be triggered.
      await tester.tap(find.text('Check for updates'));
      await _pumpAndPause(tester);
      expect(
        service.checkCalls,
        2,
        reason: 'dismissing the confirm dialog must not strand the tile',
      );
    },
  );

  testWidgets('install action dialog is not barrier-dismissible', (
    tester,
  ) async {
    final controller = Completer<String>();
    final service = _FakeUpdateService(
      checkResult: _availableResult,
      downloadController: controller,
    );
    await _pumpAboutScreen(tester, service);

    await tester.tap(find.text('Check for updates'));
    await _pumpAndPause(tester);
    await tester.tap(find.text('Download'));
    await _pumpAndPause(tester);
    controller.complete('/fake/downloaded/vers-reminder-arm64.apk');
    await _pumpAndPause(tester);
    await _pumpAndPause(tester);
    expect(
      find.text('Download complete. Install the update now?'),
      findsOneWidget,
    );

    // A barrier tap must not dismiss the install action dialog either.
    await tester.tapAt(const Offset(10, 10));
    await _pumpAndPause(tester);
    expect(
      find.text('Download complete. Install the update now?'),
      findsOneWidget,
      reason: 'install action dialog must not be dismissible via the barrier',
    );

    // Cancel returns to idle and the tile re-enables.
    await tester.tap(find.text('Cancel'));
    await _pumpAndPause(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Check for updates'));
    await _pumpAndPause(tester);
    expect(
      service.checkCalls,
      2,
      reason: 'tile re-enabled after dismissing the install action',
    );
  });

  testWidgets(
    'Settings shows the four sections plus an About link, with no update '
    'tiles inlined',
    (tester) async {
      final service = _FakeUpdateService(
        checkResult: UpdateCheckResult.empty(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WallpaperState>.value(
              value: WallpaperState(),
            ),
            ChangeNotifierProvider<SchedulerConfig>.value(
              value: SchedulerConfig(),
            ),
            ChangeNotifierProvider<AppearanceSettings>.value(
              value: AppearanceSettings(),
            ),
            ChangeNotifierProvider<LocaleProvider>.value(
              value: LocaleProvider(),
            ),
            ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: SettingsScreen(updateService: service),
          ),
        ),
      );
      // Advance past the preview timer + post-frame work.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // The update-check tile must NOT be present in Settings — it lives in
      // AboutScreen now.
      expect(
        find.text('Check for updates'),
        findsNothing,
        reason: 'update content moved out of Settings into AboutScreen',
      );

      // Section order is browsable in order: Appearance, Rotation, Categories,
      // Actions, then the About link (scrolling reveals each below the fold).
      for (final section in ['Appearance', 'Rotation', 'Actions']) {
        await tester.scrollUntilVisible(find.text(section), 150);
        await tester.pump();
        expect(
          find.text(section),
          findsWidgets,
          reason: 'section "$section" present in Settings',
        );
      }

      // The About link opens AboutScreen.
      await tester.scrollUntilVisible(find.text('About'), 300);
      await tester.pump();
      expect(
        find.text('About'),
        findsAtLeastNWidgets(1),
        reason: 'About link present in Settings',
      );
      await tester.tap(find.byIcon(Icons.info_outline).last);
      await _pumpAndPause(tester);
      expect(
        find.text('Check for updates'),
        findsOneWidget,
        reason: 'About tile opens AboutScreen with the update action',
      );
    },
  );

  testWidgets('Change now renders via the shared loader button', (
    tester,
  ) async {
    final service = _FakeUpdateService(checkResult: UpdateCheckResult.empty());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperState>.value(
            value: WallpaperState(),
          ),
          ChangeNotifierProvider<SchedulerConfig>.value(
            value: SchedulerConfig(),
          ),
          ChangeNotifierProvider<AppearanceSettings>.value(
            value: AppearanceSettings(),
          ),
          ChangeNotifierProvider<LocaleProvider>.value(value: LocaleProvider()),
          ChangeNotifierProvider<VerseProvider>.value(value: VerseProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SettingsScreen(updateService: service),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // Change now lives in the Actions section; scroll to it.
    await tester.scrollUntilVisible(find.text('Change now'), 300);
    await tester.pump();

    expect(
      find.byType(AsyncActionButton),
      findsWidgets,
      reason: 'Change now now uses the shared inline blocking loader',
    );
  });
}

/// Pumps the real [AboutScreen] with a stubbed [UpdateService] and all
/// providers it reads.
Future<void> _pumpAboutScreen(
  WidgetTester tester,
  _FakeUpdateService service,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperState>.value(
          value: WallpaperState(),
        ),
        ChangeNotifierProvider<SchedulerConfig>.value(
          value: SchedulerConfig(),
        ),
        ChangeNotifierProvider<AppearanceSettings>.value(
          value: AppearanceSettings(),
        ),
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

/// Pumps one frame plus a fixed pause.
///
/// Route animations and snackbars are driven with explicit durations so the
/// tests remain deterministic.
Future<void> _pumpAndPause(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 300),
]) async {
  await tester.pump();
  await tester.pump(duration);
}

/// A deterministic [UpdateService] double driving the About update flow.
///
/// `checkForUpdate` returns a fixed result, `download` can report progress via
/// a test-driven [progressController] and be gated on a [downloadController]
/// (or fail immediately via [downloadError]), and `install` records its calls
/// (including the release URL) and returns a fixed outcome. No network,
/// platform channels, or filesystem are touched.
class _FakeUpdateService implements UpdateService {
  _FakeUpdateService({
    required this.checkResult,
    this.downloadController,
    this.installResult = true,
    this.downloadError,
    this.progressController,
  });

  UpdateCheckResult checkResult;
  Completer<String>? downloadController;
  bool installResult;
  Object? downloadError;
  StreamController<(int, int)>? progressController;

  int checkCalls = 0;
  final List<UpdateCheckResult> downloadCalls = [];
  final List<String> installCalls = [];
  final List<String?> installReleaseUrls = [];

  @override
  Future<UpdateCheckResult> checkForUpdate({
    http.Client? client,
    String? versionOverride,
    String? buildOverride,
  }) async {
    checkCalls++;
    return checkResult;
  }

  @override
  Future<String> download(
    UpdateCheckResult release, {
    void Function(int bytes, int total)? onProgress,
    http.Client? client,
    String? appSupportOverride,
  }) {
    downloadCalls.add(release);

    if (downloadError != null) {
      // Report nothing; fail immediately after entry so the screen's catch
      // path (Retry) is exercised.
      return Future.error(downloadError!);
    }

    final progress = progressController;
    final completer = downloadController;
    if (progress != null) {
      // Progress is driven by the test through the controller; completion is
      // driven by completing [downloadController].
      progress.stream.listen((e) => onProgress?.call(e.$1, e.$2));
      return completer!.future;
    }

    onProgress?.call(512, 1024); // start + progress
    if (completer != null) {
      return completer.future.then((path) {
        onProgress?.call(1024, 1024); // finish
        return path;
      });
    }
    onProgress?.call(1024, 1024); // finish
    return Future.value('/fake/downloaded/vers-reminder-arm64.apk');
  }

  @override
  Future<bool> install(
    String apkPath, {
    String? releaseUrl,
    IntentLauncher Function(AndroidIntent intent)? intentLauncherFactory,
  }) async {
    installCalls.add(apkPath);
    installReleaseUrls.add(releaseUrl);
    return installResult;
  }
}
