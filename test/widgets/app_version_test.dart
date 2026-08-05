import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vers_reminder/shared/widgets/app_version.dart';

/// Channel used by `package_info_plus` — mocked so `resolveAppVersionString`
/// never hits a real platform channel in tests.
const MethodChannel _packageInfoChannel =
    MethodChannel('dev.fluttercommunity.plus/package_info');

Map<String, String> _packageInfo = const {
  'version': '2.4.1',
  'buildNumber': '7',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, null);
  });

  // NOTE: `PackageInfo.fromPlatform()` caches its result in a static field,
  // so the error path MUST be exercised BEFORE the first successful fetch
  // populates the cache. Keep this test first in the file.
  test('resolveAppVersionString rethrows platform failures verbatim',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        throw PlatformException(code: 'channel_error', message: 'boom');
      }
      return null;
    });

    await expectLater(
      resolveAppVersionString(),
      throwsA(isA<PlatformException>()
          .having((e) => e.message, 'message', 'boom')),
    );
  });

  test('resolveAppVersionString formats v{version}+{build}', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'version': _packageInfo['version'],
          'buildNumber': _packageInfo['buildNumber'],
          'packageName': 'com.versreminder.vers_reminder',
          'appName': 'vers_reminder',
        };
      }
      return null;
    });

    expect(await resolveAppVersionString(), 'v2.4.1+7');
  });
}
