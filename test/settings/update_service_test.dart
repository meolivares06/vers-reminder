import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:vers_reminder/settings/infrastructure/update_check_result.dart';
import 'package:vers_reminder/settings/infrastructure/update_service.dart';

/// A GitHub `/releases/latest`-shaped JSON body with a single arm64 APK asset.
///
/// Fixtures keep the `%2B` in the tag (`+`) — GitHub CDN/API URLs encode `+`
/// as `%2B`. Tests and reviewers must NOT "fix" this; it mirrors the real
/// download URL the app receives.
String _releaseJson({
  String tag = 'v1.2.0+1',
  String url =
      'https://github.com/meolivares06/vers-reminder/releases/download/v1.2.0%2B1/vers-reminder-arm64.apk',
  String name = 'vers-reminder-arm64.apk',
  int size = 1024,
}) {
  return jsonEncode({
    'tag_name': tag,
    'assets': [
      {
        'name': name,
        'browser_download_url': url,
        'size': size,
        'content_type': 'application/vnd.android.package-archive',
      }
    ],
  });
}

void main() {
  group('compareVersions', () {
    test('remote major higher > 0', () {
      expect(compareVersions('v2.0.0+1', '1.0.0', '3'), greaterThan(0));
    });

    test('remote minor higher > 0', () {
      expect(compareVersions('v1.2.0+1', '1.0.0', '3'), greaterThan(0));
    });

    test('remote patch higher > 0', () {
      expect(compareVersions('v1.0.1+1', '1.0.0', '3'), greaterThan(0));
    });

    test('equal version and build == 0', () {
      expect(compareVersions('v1.0.0+3', '1.0.0', '3'), 0);
    });

    test('same version higher build > 0 (update available)', () {
      expect(compareVersions('v1.0.0+4', '1.0.0', '3'), greaterThan(0));
    });

    test('same version lower build < 0', () {
      expect(compareVersions('v1.0.0+2', '1.0.0', '3'), lessThan(0));
    });

    test('remote lower major < 0', () {
      expect(compareVersions('v0.9.0+5', '1.0.0', '3'), lessThan(0));
    });

    test('v prefix is stripped', () {
      expect(compareVersions('v1.0.0+3', '1.0.0', '3'), 0);
      expect(compareVersions('1.0.0+3', '1.0.0', '3'), 0);
    });

    test('remote without build is treated as build 0', () {
      expect(compareVersions('v1.0.0', '1.0.0', '3'), lessThan(0));
    });

    test('build compared numerically not lexically', () {
      // "10" must be > "9" even though "10" < "9" as strings.
      expect(compareVersions('v1.0.0+10', '1.0.0', '9'), greaterThan(0));
    });
  });

  group('checkForUpdate', () {
    test('available: remote higher returns available with asset info', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://api.github.com/repos/meolivares06/vers-reminder/releases/latest');
        return http.Response(_releaseJson(tag: 'v1.2.0+1', size: 2048),
            200,
            headers: {'content-type': 'application/json'});
      });

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isTrue);
      expect(result.tagName, 'v1.2.0+1');
      expect(result.assetName, 'vers-reminder-arm64.apk');
      expect(result.sizeBytes, 2048);
      expect(
        result.downloadUrl,
        'https://github.com/meolivares06/vers-reminder/releases/download/v1.2.0%2B1/vers-reminder-arm64.apk',
      );
    });

    test('equal version returns no update', () async {
      final client = MockClient((request) async {
        return http.Response(_releaseJson(tag: 'v1.0.0+3'), 200);
      });

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isFalse);
      expect(result.error, isNull);
    });

    test('lower version returns no update', () async {
      final client = MockClient((request) async {
        return http.Response(_releaseJson(tag: 'v0.9.0+5'), 200);
      });

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isFalse);
      expect(result.error, isNull);
    });

    test('network error (non-2xx) returns failure without throwing',
        () async {
      final client = MockClient((request) async => http.Response('nope', 500));

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isFalse);
      expect(result.error, isNotNull);
    });

    test('malformed tag_name returns failure without throwing', () async {
      final client = MockClient((request) async {
        return http.Response(_releaseJson(tag: 'latest'), 200);
      });

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isFalse);
      expect(result.error, isNotNull);
    });

    test('malformed JSON returns failure without throwing', () async {
      final client = MockClient((request) async {
        return http.Response('{ not valid json', 200);
      });

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isFalse);
      expect(result.error, isNotNull);
    });

    test('missing arm64 asset returns failure without throwing', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.2.0+1',
            'assets': [
              {
                'name': 'vers-reminder-x86.apk',
                'browser_download_url': 'https://example.com/x86.apk',
                'size': 100,
              }
            ],
          }),
          200,
        );
      });

      final result = await UpdateService.instance.checkForUpdate(
        client: client,
        versionOverride: '1.0.0',
        buildOverride: '3',
      );

      expect(result.available, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('download', () {
    late Directory appSupport;

    setUp(() {
      appSupport = Directory.systemTemp.createTempSync('update_service_test_');
    });

    tearDown(() {
      if (appSupport.existsSync()) {
        appSupport.deleteSync(recursive: true);
      }
    });

    UpdateCheckResult release({String? name, String? url}) => UpdateCheckResult(
          available: true,
          tagName: 'v1.2.0+1',
          downloadUrl: url ?? 'https://example.com/vers-reminder-arm64.apk',
          assetName: name ?? 'vers-reminder-arm64.apk',
          sizeBytes: 1024,
        );

    test('writes APK file to updates dir and reports progress', () async {
      final bytes = List<int>.generate(512, (i) => i % 256);
      final body = Stream<List<int>>.fromIterable(
          [bytes.sublist(0, 256), bytes.sublist(256)]);

      final client = _StreamClient(
        http.StreamedResponse(body, 200, contentLength: bytes.length),
      );

      final path = await UpdateService.instance.download(
        release(),
        client: client,
        appSupportOverride: appSupport.path,
      );

      expect(path,
          p.join(appSupport.path, 'updates', 'vers-reminder-arm64.apk'));
      final written = File(path);
      expect(written.existsSync(), isTrue);
      expect(written.readAsBytesSync(), bytes);
    });

    test(
        'a malicious asset name (path traversal) is confined to the updates '
        'dir', () async {
      final bytes = List<int>.generate(8, (i) => i);
      final body = Stream<List<int>>.fromIterable([bytes]);
      final client = _StreamClient(
        http.StreamedResponse(body, 200, contentLength: bytes.length),
      );

      final path = await UpdateService.instance.download(
        // The "../../" prefix is the hostile part of the name.
        release(name: '../../escape.apk'),
        client: client,
        appSupportOverride: appSupport.path,
      );

      // `p.join(updatesDir, p.basename(assetName))` confines the write to the
      // updates dir — the traversal prefix is stripped, so the file lands at
      // `updates/escape.apk`, never outside it.
      expect(path, p.join(appSupport.path, 'updates', 'escape.apk'));
      expect(File(path).existsSync(), isTrue);
      expect(File(p.join(appSupport.path, 'escape.apk')).existsSync(), isFalse,
          reason: 'no file is written outside the updates dir');
      // A name whose basename is empty or "." is rejected outright.
      await expectLater(
        () => UpdateService.instance.download(
          release(name: '..'),
          client: client,
          appSupportOverride: appSupport.path,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => UpdateService.instance.download(
          release(name: '.'),
          client: client,
          appSupportOverride: appSupport.path,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'stale APKs in the updates dir are cleared before the new download '
        'is written', () async {
      final updatesDir = Directory(p.join(appSupport.path, 'updates'))
        ..createSync(recursive: true);
      final stale = File(p.join(updatesDir.path, 'vers-reminder-1.0.0.apk'))
        ..writeAsBytesSync([9, 9, 9]);

      final bytes = List<int>.generate(512, (i) => i % 256);
      final body = Stream<List<int>>.fromIterable([bytes]);
      final client = _StreamClient(
        http.StreamedResponse(body, 200, contentLength: bytes.length),
      );

      final path = await UpdateService.instance.download(
        release(),
        client: client,
        appSupportOverride: appSupport.path,
      );

      expect(stale.existsSync(), isFalse,
          reason: 'stale APK is removed before the new file is written');
      expect(File(path).existsSync(), isTrue);
      final apks = updatesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.apk'))
          .toList();
      expect(apks, hasLength(1),
          reason: 'only the in-flight download remains in the updates dir');
      expect(apks.single.path, path);
    });

    test('download reports progress via onProgress (start and finish)',
        () async {
      final bytes = List<int>.generate(512, (i) => i % 256);
      final body = Stream<List<int>>.fromIterable(
          [bytes.sublist(0, 256), bytes.sublist(256)]);
      final client = _StreamClient(
        http.StreamedResponse(body, 200, contentLength: bytes.length),
      );
      final progress = <(int, int)>[];

      await UpdateService.instance.download(
        release(),
        client: client,
        appSupportOverride: appSupport.path,
        onProgress: (bytesReceived, total) => progress.add((bytesReceived, total)),
      );

      expect(progress, isNotEmpty);
      expect(progress.first.$2, bytes.length,
          reason: 'start reports the expected total');
      expect(progress.last, (bytes.length, bytes.length),
          reason: 'finish reports the full size received');
    });

    test('download failure mid-transfer deletes partial file and rethrows',
        () async {
      final chunk = List<int>.generate(64, (i) => i);
      // A stream that yields one chunk then throws.
      final controller = StreamController<List<int>>();
      controller.add(chunk);
      controller.addError(Exception('boom'));

      final client = _StreamClient(
        http.StreamedResponse(controller.stream, 200, contentLength: 128),
      );

      await expectLater(
        UpdateService.instance.download(
          release(),
          client: client,
          appSupportOverride: appSupport.path,
        ),
        throwsA(isA<Exception>()),
      );

      final dir = Directory(p.join(appSupport.path, 'updates'));
      final apks = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.apk'))
          .toList();
      expect(apks, isEmpty);
    });
  });

  group('install', () {
    late Directory installDir;

    setUp(() {
      installDir = Directory.systemTemp.createTempSync('install_test_');
    });

    tearDown(() {
      if (installDir.existsSync()) {
        installDir.deleteSync(recursive: true);
      }
    });

    test('missing APK returns false without launching an intent', () async {
      final missing = p.join(installDir.path, 'does-not-exist.apk');

      final fired = await UpdateService.instance.install(missing);

      expect(fired, isFalse);
    });

    test(
        'install fires the system installer when it resolves the intent '
        '(FileProvider URI + package-archive MIME)', () async {
      final apk = File(p.join(installDir.path, 'vers-reminder-arm64.apk'))
        ..writeAsBytesSync([1, 2, 3]);
      final launched = <AndroidIntent>[];

      final fired = await UpdateService.instance.install(
        apk.path,
        releaseUrl:
            'https://github.com/meolivares06/vers-reminder/releases/latest',
        intentLauncherFactory: (intent) => _FakeIntentLauncher(
          intent,
          canResolve: (i) =>
              i.action == 'android.intent.action.VIEW' &&
              i.type == 'application/vnd.android.package-archive',
          onLaunch: launched.add,
        ),
      );

      expect(fired, isTrue);
      expect(launched, hasLength(1));
      expect(launched.single.action, 'android.intent.action.VIEW');
      expect(
        launched.single.data,
        'content://com.versreminder.vers_reminder.fileprovider/updates/'
        'vers-reminder-arm64.apk',
      );
      expect(launched.single.type, 'application/vnd.android.package-archive');
      expect(launched.single.flags, [Flag.FLAG_GRANT_READ_URI_PERMISSION]);
    });

    test(
        'install falls back to the browser when no installer resolves the '
        'intent', () async {
      final apk = File(p.join(installDir.path, 'vers-reminder-arm64.apk'))
        ..writeAsBytesSync([1, 2, 3]);
      final resolved = <String>[];
      final launched = <AndroidIntent>[];
      const releaseUrl =
          'https://github.com/meolivares06/vers-reminder/releases/latest';

      final fired = await UpdateService.instance.install(
        apk.path,
        releaseUrl: releaseUrl,
        intentLauncherFactory: (intent) {
          resolved.add('${intent.action}|${intent.type}');
          // Only the browser VIEW intent (no MIME type) resolves.
          return _FakeIntentLauncher(
            intent,
            canResolve: (i) => i.type == null,
            onLaunch: launched.add,
          );
        },
      );

      // The install intent is probed first, then the browser fallback
      // resolves against the release URL and actually launches it.
      expect(
        resolved,
        [
          'android.intent.action.VIEW|application/vnd.android.package-archive',
          'android.intent.action.VIEW|null',
        ],
      );
      expect(fired, isTrue);
      expect(launched, hasLength(1));
      expect(launched.single.action, 'android.intent.action.VIEW');
      expect(launched.single.data, releaseUrl);
      expect(launched.single.type, isNull);
    });

    test(
        'install returns false without launching when the browser fallback '
        'does not resolve either', () async {
      final apk = File(p.join(installDir.path, 'vers-reminder-arm64.apk'))
        ..writeAsBytesSync([1, 2, 3]);
      final launched = <AndroidIntent>[];

      final fired = await UpdateService.instance.install(
        apk.path,
        releaseUrl:
            'https://github.com/meolivares06/vers-reminder/releases/latest',
        intentLauncherFactory: (intent) => _FakeIntentLauncher(
          intent,
          // Nothing resolves — no installer and no browser.
          canResolve: (_) => false,
          onLaunch: launched.add,
        ),
      );

      expect(fired, isFalse);
      expect(launched, isEmpty);
    });

    test(
        'install never throws when platform plumbing fails: a canResolveActivity '
        'exception is converted to a false return', () async {
      final apk = File(p.join(installDir.path, 'vers-reminder-arm64.apk'))
        ..writeAsBytesSync([1, 2, 3]);

      final fired = await UpdateService.instance.install(
        apk.path,
        intentLauncherFactory: (intent) => _FakeIntentLauncher(
          intent,
          // Simulate an unexpected platform failure during resolution.
          canResolve: (_) => throw StateError('platform died'),
          onLaunch: (_) {},
        ),
      );

      expect(fired, isFalse,
          reason: 'a resolve/launch throw must surface as false, never throw');
    });

    test(
        'install deep-links to unknown-app-sources when the installer launch '
        'fails', () async {
      final apk = File(p.join(installDir.path, 'vers-reminder-arm64.apk'))
        ..writeAsBytesSync([1, 2, 3]);
      final launched = <String>[];

      final fired = await UpdateService.instance.install(
        apk.path,
        intentLauncherFactory: (intent) => _FakeIntentLauncher(
          intent,
          canResolve: (i) => i.type == 'application/vnd.android.package-archive',
          onLaunch: (i) {
            if (i.action == 'android.intent.action.VIEW') {
              throw StateError('no installer available');
            }
            launched.add(i.action!);
          },
        ),
      );

      expect(fired, isFalse);
      expect(launched, ['android.settings.MANAGE_UNKNOWN_APP_SOURCES']);
    });
  });
}

/// A minimal [http.BaseClient] that returns a fixed [StreamedResponse] so the
/// `send()` code path (used by `download`) can be exercised with a stream.
class _StreamClient extends http.BaseClient {
  _StreamClient(this.response);

  final http.StreamedResponse response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
}

/// A scriptable [IntentLauncher] for install tests.
///
/// `android_intent_plus` hard-codes a local platform check, so the real
/// launcher is inert off-device; this fake lets the install flow resolve and
/// launch deterministically on the test host.
class _FakeIntentLauncher implements IntentLauncher {
  _FakeIntentLauncher(this.intent, {required this.canResolve, this.onLaunch});

  final AndroidIntent intent;
  final bool Function(AndroidIntent) canResolve;
  final void Function(AndroidIntent)? onLaunch;

  @override
  Future<bool> canResolveActivity() async => canResolve(intent);

  @override
  Future<void> launch() async => onLaunch?.call(intent);
}
