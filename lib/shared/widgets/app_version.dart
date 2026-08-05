import 'package:package_info_plus/package_info_plus.dart';

/// Resolves the installed app version into a display string.
///
/// Returns `v{version}+{buildNumber}` (e.g. `v2.4.1+7`) so Home and Settings
/// About sections always reflect the actual installed release. Errors are
/// NOT caught here — they propagate verbatim so callers decide how to handle
/// a failing platform lookup (typically leaving the version field empty).
Future<String> resolveAppVersionString() async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version}+${info.buildNumber}';
}
