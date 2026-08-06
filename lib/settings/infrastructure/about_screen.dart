import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:vers_reminder/shared/shared.dart';
import 'package:vers_reminder/settings/infrastructure/update_check_result.dart';
import 'package:vers_reminder/settings/infrastructure/update_service.dart';

/// The lifetime of the self-update flow in the About screen.
enum _UpdateCheckState { idle, checking, available, downloading, installing }

/// Public release page of the project repo — used by the share tile and as the
/// browser fallback when the release tag is unknown.
const String _releaseLatestUrl =
    'https://github.com/meolivares06/vers-reminder/releases/latest';

/// Support email shown on the contact tile.
const String _contactEmail = 'meolivares06@gmail.com';

/// Dedicated About screen reached from a Settings tile (and Home tile).
///
/// Holds the app update/version/share/contact content previously inlined in
/// `settings_screen.dart`. The self-update state machine and the injectable
/// [updateService] seam were moved here verbatim (pure move).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.updateService});

  /// Test seam — the update service used by the About flow. Defaults to
  /// [UpdateService.instance] when null.
  @visibleForTesting
  final UpdateService? updateService;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '';
  _UpdateCheckState _updateState = _UpdateCheckState.idle;
  UpdateCheckResult? _updateResult;
  String? _downloadedApkPath;
  double _downloadProgress = 0;

  /// Live-rebuild handle for the progress dialog. The progress dialog route is
  /// a sibling on the root navigator, so the parent `setState` cannot rebuild
  /// it; this callback (captured from the dialog's `StatefulBuilder`) is what
  /// actually pushes progress updates into the dialog. Together with the
  /// parent `setState`, both stay in sync.
  StateSetter? _setDialogState;

  /// Whether the cancelable progress dialog is currently presented. Guards the
  /// completion/error `pop()` so a barrier-dismissed dialog is not double-popped
  /// (which would otherwise pop whatever route is underneath — e.g. AboutScreen
  /// itself).
  bool _progressDialogShowing = false;

  /// The update service driving the About flow — injectable for tests.
  late final UpdateService _updateService =
      widget.updateService ?? UpdateService.instance;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await resolveAppVersionString();
      if (mounted) {
        setState(() => _appVersion = version);
      }
    } catch (_) {
      // Leave the version field empty — the version tile renders no stale
      // string when the platform lookup fails.
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _updateState = _UpdateCheckState.checking);

    final result = await _updateService.checkForUpdate();

    if (!mounted) return;

    if (result.available) {
      setState(() {
        _updateState = _UpdateCheckState.available;
        _updateResult = result;
      });
      _showUpdateConfirmDialog(l10n, result);
    } else if (result.error != null) {
      setState(() => _updateState = _UpdateCheckState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.updateCheckFailed),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: l10n.retry, onPressed: _checkForUpdate),
        ),
      );
    } else {
      setState(() => _updateState = _UpdateCheckState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.upToDate),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUpdateConfirmDialog(
    AppLocalizations l10n,
    UpdateCheckResult result,
  ) {
    showDialog<void>(
      context: context,
      // The only exits are the explicit buttons: barrier taps must not dismiss
      // the dialog, or the state machine would be stranded in `available` with
      // a disabled tile and no way back to retry.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.updateAvailable(_displayVersion(result.tagName))),
        content: Text(
          l10n.downloadUpdateConfirm(
            _displayVersion(result.tagName),
            result.sizeBytes != null ? _formatSize(result.sizeBytes!) : '?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Re-enable the tile: cancelling the confirm dialog leaves no
              // active download, so the state machine must return to idle
              // instead of staying stuck in `available` with a disabled tile.
              setState(() => _updateState = _UpdateCheckState.idle);
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _downloadAndInstall(l10n, result);
            },
            child: Text(l10n.downloadUpdate),
          ),
        ],
      ),
    ).then((_) {
      // Defensive: barrierDismissible:false already guarantees the dialog only
      // closes through Cancel/Download, both of which leave the state machine
      // consistent. If a future refactor re-enables barrier dismissal, still
      // reset to idle instead of stranding the update tile disabled forever.
      if (!mounted || _updateState != _UpdateCheckState.available) return;
      setState(() => _updateState = _UpdateCheckState.idle);
    });
  }

  Future<void> _downloadAndInstall(
    AppLocalizations l10n,
    UpdateCheckResult result,
  ) async {
    if (!mounted) return;
    setState(() {
      _updateState = _UpdateCheckState.downloading;
      _downloadProgress = 0;
    });

    // Show the cancelable progress dialog. The dialog route is a sibling on
    // the navigator, so the parent setState alone cannot rebuild it — the
    // dialog must be driven through its own `setDialogState` handle (captured
    // into [_setDialogState]) for live progress updates.
    _progressDialogShowing = true;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          _setDialogState = setDialogState;
          final percent = (_downloadProgress * 100).round();
          return AlertDialog(
            title: Text(l10n.downloadingUpdate),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.updateDownloadProgress('$percent')),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                ),
              ],
            ),
          );
        },
      ),
    );
    // Clear the guard whenever the route closes (barrier dismiss OR a
    // programmatic pop) so a later close no-ops instead of popping whatever is
    // underneath.
    dialogFuture.whenComplete(() {
      _progressDialogShowing = false;
      _setDialogState = null;
    });

    try {
      final apkPath = await _updateService.download(
        result,
        onProgress: (bytes, total) {
          if (!mounted) return;
          final progress = total > 0 ? bytes / total : 0.0;
          // Update both the parent (tile subtitle / future dialog state) and
          // the live dialog route.
          setState(() => _downloadProgress = progress);
          _setDialogState?.call(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      _closeProgressDialog();
      setState(() {
        _updateState = _UpdateCheckState.installing;
        _downloadedApkPath = apkPath;
      });
      _showInstallAction(l10n);
    } catch (e) {
      debugPrint('Update download failed: $e');
      if (!mounted) return;
      _closeProgressDialog();
      // Return to a fully recoverable state: the tile is re-enabled (idle)
      // AND a Retry action immediately re-runs the download. Either path lets
      // the user out of the failed-download stall.
      setState(() => _updateState = _UpdateCheckState.idle);
      if (ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.updateDownloadFailed),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: () => _downloadAndInstall(l10n, result),
            ),
          ),
        );
      }
    }
  }

  /// Closes the progress dialog, but only if it is still presented (i.e. not
  /// already dismissed via the barrier). Guards against popping whatever route
  /// sits underneath the dialog on the navigator.
  void _closeProgressDialog() {
    if (!_progressDialogShowing) return;
    _progressDialogShowing = false;
    Navigator.of(context).pop();
  }

  void _showInstallAction(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      // Like the confirm dialog: the install action must only close through its
      // explicit buttons, otherwise the state machine could be stranded in
      // `installing` with a disabled tile.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.updateAvailable(_displayVersion(_updateResult?.tagName)),
        ),
        content: Text(l10n.downloadComplete),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _updateState = _UpdateCheckState.idle);
            },
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.system_update_alt),
            label: Text(l10n.installNow),
            onPressed: () {
              Navigator.of(ctx).pop();
              _startInstall(l10n);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startInstall(AppLocalizations l10n) async {
    final apkPath = _downloadedApkPath;
    if (apkPath == null) return;
    if (!mounted) return;

    try {
      final fired = await _updateService.install(
        apkPath,
        // The browser fallback should land on a real release page (with the
        // version tag), never the raw APK download URL. Fall back to the
        // latest-release page when the tag is unknown.
        releaseUrl: _releasePageUrl(_updateResult?.tagName),
      );
      // NOTE: a `false` return covers both "nothing fired" and "the system
      // installer failed but the unknown-app-sources deep-link was opened".
      // Either way no install happened here, so the accurate `updateInstallFailed`
      // copy is shown.
      if (!mounted) return;
      setState(() => _updateState = _UpdateCheckState.idle);
      if (!fired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.updateInstallFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Install failed: $e');
      if (!mounted) return;
      setState(() => _updateState = _UpdateCheckState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.updateInstallFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Builds the public release page URL for [tag] on the project repo.
  ///
  /// Falls back to the `releases/latest` page when the tag is unknown so the
  /// browser fallback in [UpdateService.install] always lands on a page the
  /// user can act on, never the raw APK download URL.
  String _releasePageUrl(String? tag) {
    if (tag == null || tag.trim().isEmpty) {
      return _releaseLatestUrl;
    }
    return 'https://github.com/meolivares06/vers-reminder/releases/tag/$tag';
  }

  String _displayVersion(String? tag) => tag ?? '?';

  String _formatSize(int bytes) {
    const kb = 1024.0;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionAbout)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            title: l10n.sectionAbout,
            subtitle: l10n.aboutDescription,
          ),
          AsyncActionButton(
            icon: Icons.system_update_alt,
            label: l10n.checkForUpdates,
            style: AsyncActionButtonStyle.tile,
            enabled: _updateState == _UpdateCheckState.idle,
            subtitle: _updateState == _UpdateCheckState.available
                ? l10n.updateAvailable(_displayVersion(_updateResult?.tagName))
                : null,
            onPressed: _checkForUpdate,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(_appVersion.isNotEmpty ? _appVersion : ''),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(l10n.aboutShare),
            onTap: () {
              Share.share(l10n.shareApp(_releaseLatestUrl));
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text(_contactEmail),
            subtitle: Text(l10n.aboutContact),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: _contactEmail));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.emailCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const SectionHeader(
            title: 'Reconocimientos',
            subtitle: 'A Alejandro Delgado Vaillant por su gran aporte.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
