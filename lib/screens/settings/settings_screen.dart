import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/update_check_result.dart';
import '../../models/wallpaper_status.dart';
import '../../providers/locale_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/image_cache_service.dart';
import '../../services/update_service.dart';
import '../../services/wallpaper_backup_service.dart';
import '../../services/wallpaper_generator.dart';
import '../../widgets/app_version.dart';
import '../../widgets/async_action_button.dart';
// TODO: restore when calibration is re-evaluated
// import '../calibration/calibration_screen.dart';

/// Maps frequency minutes to the matching ARB key.
String _frequencyLabel(int minutes, AppLocalizations l10n) {
  return switch (minutes) {
    15 => l10n.freq15min,
    30 => l10n.freq30min,
    60 => l10n.freq1h,
    180 => l10n.freq3h,
    360 => l10n.freq6h,
    720 => l10n.freq12h,
    1440 => l10n.freq24h,
    _ => '$minutes min',
  };
}

/// The lifetime of the self-update flow in the About section.
enum _UpdateCheckState { idle, checking, available, downloading, installing }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.updateService});

  /// Test seam — the update service used by the About flow. Defaults to
  /// [UpdateService.instance] when null.
  @visibleForTesting
  final UpdateService? updateService;

  static const List<int> frequencyOptions = [15, 30, 60, 180, 360, 720, 1440];

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Timer? _previewTimer;
  String? _previewImagePath;
  Uint8List? _cachedPreview;
  int _previewGeneration = 0;
  String _appVersion = '';
  _UpdateCheckState _updateState = _UpdateCheckState.idle;
  UpdateCheckResult? _updateResult;
  String? _downloadedApkPath;
  double _downloadProgress = 0;

  /// True once a preview attempt produced nothing (no verse, no cached image,
  /// or a render error). Lets the mini-preview settle into a placeholder
  /// instead of showing an indeterminate spinner forever.
  bool _previewUnavailable = false;

  /// Live-rebuild handle for the progress dialog. The progress dialog route is
  /// a sibling on the root navigator, so the parent `setState` cannot rebuild
  /// it; this callback (captured from the dialog's `StatefulBuilder`) is what
  /// actually pushes progress updates into the dialog. Together with the
  /// parent `setState`, both stay in sync.
  StateSetter? _setDialogState;

  /// Whether the cancelable progress dialog is currently presented. Guards the
  /// completion/error `pop()` so a barrier-dismissed dialog is not double-popped
  /// (which would otherwise pop whatever route is underneath — e.g. Settings
  /// itself).
  bool _progressDialogShowing = false;

  /// The update service driving the About flow — injectable for tests.
  late final UpdateService _updateService =
      widget.updateService ?? UpdateService.instance;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePreview();
    });
  }

  Future<void> _loadVersion() async {
    try {
      final version = await resolveAppVersionString();
      if (mounted) {
        setState(() => _appVersion = version);
      }
    } catch (_) {
      // Leave the version field empty — the About tile renders no stale string
      // when the platform lookup fails.
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 300), () {
      _updatePreview();
    });
  }

  Future<void> _updatePreview() async {
    final generation = ++_previewGeneration;

    final verseProvider = context.read<VerseProvider>();
    final settings = context.read<SettingsProvider>();
    final locale = context.read<LocaleProvider>().locale.languageCode;

    final allVerses = verseProvider.groupedVerses.values
        .expand((list) => list)
        .toList();
    final verse = allVerses.isNotEmpty ? allVerses.first : null;

    // No verse to render (e.g. empty library) — settle into the placeholder
    // instead of leaving the indeterminate spinner running forever.
    if (verse == null) {
      if (mounted) {
        setState(() {
          _cachedPreview = null;
          _previewUnavailable = true;
        });
      }
      return;
    }

    // Capture width before async gap
    final previewWidth =
        (MediaQuery.of(context).size.width * 0.8).round();

    try {
      _previewImagePath ??=
          await ImageCacheService.instance.getNextRandomImage();

      // No cached image to render against (empty cache on first run) — settle
      // into the placeholder.
      if (_previewImagePath == null) {
        if (mounted) {
          setState(() {
            _cachedPreview = null;
            _previewUnavailable = true;
          });
        }
        return;
      }

      final bytes = await WallpaperGenerator.instance.renderPreview(
        verse: verse,
        locale: locale,
        previewWidth: previewWidth,
        previewHeight: 150,
        horizontalOffset: settings.horizontalOffset,
        verticalAlignment: settings.verticalAlignment,
        fontScale: settings.fontScale,
        calibratedInset: settings.calibratedInset,
        previewImagePath: _previewImagePath,
        useMyWallpaper: settings.useMyWallpaper,
      );

      if (!mounted || generation != _previewGeneration) return;
      setState(() {
        _cachedPreview = bytes;
        _previewUnavailable = false;
      });
    } catch (e) {
      debugPrint('Wallpaper mini-preview generation failed: $e');
      if (!mounted || generation != _previewGeneration) return;
      setState(() {
        _cachedPreview = null;
        _previewUnavailable = true;
      });
    }
  }

  Future<void> _onMioSelected() async {
    final settings = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    if (settings.userBackgroundPath == null) {
      // No image stored — open picker automatically
      try {
        final picker = ImagePicker();
        final XFile? pickedImage =
            await picker.pickImage(source: ImageSource.gallery);

        if (pickedImage == null) {
          // User cancelled — revert to App
          await settings.setUseMyWallpaper(false);
          return;
        }

        final appDir = await getApplicationDocumentsDirectory();
        final destPath = '${appDir.path}/user_background.png';
        await File(pickedImage.path).copy(destPath);
        await settings.setUserBackgroundPath(destPath);
        await settings.setUseMyWallpaper(true);
        _previewImagePath = null;
        _schedulePreview();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.backgroundSelected),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.backgroundPickFailed),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await settings.setUseMyWallpaper(false);
      }
    } else {
      // Image already stored — just toggle
      await settings.setUseMyWallpaper(true);
      _previewImagePath = null;
      _schedulePreview();
    }
  }

  Future<void> _onReplaceImage() async {
    final settings = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    try {
      final picker = ImagePicker();
      final XFile? pickedImage =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedImage == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final destPath = '${appDir.path}/user_background.png';
      await File(pickedImage.path).copy(destPath);
      await settings.setUserBackgroundPath(destPath);
      _previewImagePath = null;
      _schedulePreview();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.backgroundSelected),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.backgroundPickFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showWallpaperPermissionDialog(
    BuildContext context,
    SettingsProvider settings,
    VerseProvider verseProvider,
    String locale,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permissionTitle),
        content: Text(l10n.permissionMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await settings.grantWallpaperPermission();
              await settings.triggerNow(
                verseProvider: verseProvider,
                locale: locale,
              );
            },
            child: Text(l10n.changeNow),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.restoreConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.restoreConfirmOk),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await WallpaperBackupService.instance.restoreOriginal();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? l10n.restoreSuccess : l10n.restoreError),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      AppLocalizations l10n, UpdateCheckResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.updateAvailable(_displayVersion(result.tagName))),
        content: Text(l10n.downloadUpdateConfirm(
          _displayVersion(result.tagName),
          result.sizeBytes != null ? _formatSize(result.sizeBytes!) : '?',
        )),
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
    );
  }

  Future<void> _downloadAndInstall(
      AppLocalizations l10n, UpdateCheckResult result) async {
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
                    value: _downloadProgress > 0 ? _downloadProgress : null),
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
      builder: (ctx) => AlertDialog(
        title: Text(l10n.updateAvailable(_displayVersion(_updateResult?.tagName))),
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
      return 'https://github.com/meolivares06/vers-reminder/releases/latest';
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
    final settings = context.watch<SettingsProvider>();
    final verseProvider = context.watch<VerseProvider>();
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Appearance (wallpaper section, FIRST) ──
                _SectionHeader(
                  title: l10n.sectionAppearance,
                  subtitle: l10n.sectionAppearanceSub,
                ),
                // Mini preview — shown at the top of the wallpaper section so
                // the user sees the current composition before its params.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: _cachedPreview != null
                        ? Image.memory(_cachedPreview!, fit: BoxFit.cover)
                        : Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            // Settles into a placeholder when a preview can't
                            // be produced (empty cache/offline first run) so
                            // the spinner never spins forever.
                            child: _previewUnavailable
                                ? const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 32,
                                    ),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                          ),
                  ),
                ),
                // Vertical alignment
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'top', label: Text(l10n.topAlign)),
                      ButtonSegment(
                          value: 'center', label: Text(l10n.centerAlign)),
                      ButtonSegment(
                          value: 'bottom', label: Text(l10n.bottomAlign)),
                    ],
                    selected: {settings.verticalAlignment},
                    onSelectionChanged: (sel) {
                      settings.setVerticalAlignment(sel.first);
                      _schedulePreview();
                    },
                  ),
                ),
                // Background source — always visible
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(l10n.backgroundSourceLabel,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                              value: false, label: Text(l10n.backgroundSourceApp)),
                          ButtonSegment(
                              value: true, label: Text(l10n.backgroundSourceMine)),
                        ],
                        selected: {settings.useMyWallpaper},
                        onSelectionChanged: (sel) {
                          final value = sel.first;
                          if (value) {
                            _onMioSelected();
                          } else {
                            settings.setUseMyWallpaper(false);
                            _previewImagePath = null;
                            _schedulePreview();
                          }
                        },
                      ),
                      // Thumbnail + Replace button when Mío is selected and image exists
                      if (settings.useMyWallpaper &&
                          settings.userBackgroundPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 100,
                                  height: 150,
                                  child: Image.file(
                                    File(settings.userBackgroundPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.swap_horiz),
                                label: Text(l10n.replaceBackgroundImage),
                                onPressed: _onReplaceImage,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Horizontal offset
                Row(
                  children: [
                    Text(l10n.leftOffset),
                    Expanded(
                      child: Slider(
                        value: settings.horizontalOffset.toDouble(),
                        min: -20,
                        max: 20,
                        divisions: 40,
                        label: settings.horizontalOffset.toString(),
                        onChanged: (v) {
                          settings.setHorizontalOffset(v.round());
                          _schedulePreview();
                        },
                      ),
                    ),
                    Text(l10n.rightOffset),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${l10n.leftOffset} ${settings.horizontalOffset} '
                    '(${settings.horizontalOffset < 0 ? l10n.leftOffset : l10n.rightOffset})',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                // Font scale
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('A-'),
                    Expanded(
                      child: Slider(
                        value: settings.fontScale,
                        min: 0.6,
                        max: 1.8,
                        divisions: 24,
                        label: settings.fontScale.toStringAsFixed(2),
                        onChanged: (v) {
                          settings.setFontScale(
                              double.parse(v.toStringAsFixed(2)));
                          _schedulePreview();
                        },
                      ),
                    ),
                    const Text('A+'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${l10n.fontSize}: ${settings.fontScale.toStringAsFixed(2)}\u00d7',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),

                // ── Restore original wallpaper ──
                const SizedBox(height: 8),
                Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    return AsyncActionButton(
                      icon: Icons.restore,
                      label: l10n.restoreOriginalWallpaper,
                      style: AsyncActionButtonStyle.tile,
                      enabled: settings.hasBackup,
                      onPressed: () =>
                          _showRestoreDialog(context, l10n),
                    );
                  },
                ),

                // ── Scheduling ──
                const Divider(),
                _SectionHeader(
                  title: l10n.sectionScheduling,
                  subtitle: l10n.sectionSchedulingSub,
                ),
                SwitchListTile(
                  title: Text(l10n.autoChange),
                  subtitle: settings.isEnabled
                      ? Text(_frequencyLabel(settings.frequencyMinutes, l10n))
                      : null,
                  value: settings.isEnabled,
                  onChanged: (v) => settings.setEnabled(v),
                ),
                if (settings.isEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: SettingsScreen.frequencyOptions
                          .map(
                            (freq) => ChoiceChip(
                              label: Text(_frequencyLabel(freq, l10n)),
                              selected: settings.frequencyMinutes == freq,
                              selectedColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              onSelected: (_) => settings.setFrequency(freq),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                // ── Categories ──
                const Divider(),
                _SectionHeader(
                  title: l10n.categoriesLabel,
                  subtitle: l10n.sectionCategoriesSub,
                ),
                // Select all / Clear all
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.select_all, size: 18),
                      label: Text(l10n.selectAll),
                      onPressed: () {
                        for (final cat in verseProvider.categories) {
                          if (!settings.activeCategoryIds.contains(cat.id)) {
                            settings.toggleCategory(cat.id!);
                          }
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.deselect, size: 18),
                      label: Text(l10n.clearAll),
                      onPressed: () {
                        for (final cat in verseProvider.categories) {
                          if (settings.activeCategoryIds.contains(cat.id)) {
                            settings.toggleCategory(cat.id!);
                          }
                        }
                      },
                    ),
                  ],
                ),
                ...verseProvider.categories.map((cat) => CheckboxListTile(
                      title: Text(cat.name),
                      value: settings.activeCategoryIds.contains(cat.id),
                      onChanged: (_) => settings.toggleCategory(cat.id!),
                    )),

                // ── Actions ──
                const Divider(),
                _SectionHeader(
                  title: l10n.sectionActions,
                  subtitle: l10n.sectionActionsSub,
                ),
                AsyncActionButton(
                  icon: Icons.wallpaper,
                  label: l10n.changeNow,
                  style: AsyncActionButtonStyle.filled,
                  onPressed: () async {
                    if (!settings.wallpaperPermissionGranted) {
                      _showWallpaperPermissionDialog(
                        context,
                        settings,
                        verseProvider,
                        locale,
                        l10n,
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    await settings.triggerNow(
                      verseProvider: verseProvider,
                      locale: locale,
                    );
                    if (!mounted) return;
                    final status = settings.status;
                    if (status == WallpaperStatus.updated) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.wallpaperUpdated(
                              settings.statusPayload ?? '')),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'OK',
                            onPressed: () {},
                          ),
                        ),
                      );
                    } else if (status == WallpaperStatus.error) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.generatingError,
                              style: const TextStyle(color: Colors.red)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (status == WallpaperStatus.noCategories) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.selectCategoryStatus),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                // TODO: Re-evaluate if calibration is needed after Canvas pipeline.
                //       Kept commented until further testing on device.
                // const SizedBox(height: 8),
                // OutlinedButton.icon(
                //   icon: const Icon(Icons.tune),
                //   label: Text(l10n.calibrateButton),
                //   onPressed: () => Navigator.of(context).push(
                //     MaterialPageRoute(
                //       builder: (_) => const CalibrationScreen(),
                //     ),
                //   ),
                // ),

                // ── About ──
                const Divider(),
                _SectionHeader(
                  title: l10n.sectionAbout,
                  subtitle: l10n.aboutDescription,
                ),
                AsyncActionButton(
                  icon: Icons.system_update_alt,
                  label: l10n.checkForUpdates,
                  style: AsyncActionButtonStyle.tile,
                  enabled: _updateState == _UpdateCheckState.idle,
                  subtitle: _updateState == _UpdateCheckState.available
                      ? l10n.updateAvailable(
                          _displayVersion(_updateResult?.tagName))
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
                    Share.share(
                      'Descargá Vers Reminder: '
                      'https://github.com/meolivares06/vers-reminder/releases/latest',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('meolivares06@gmail.com'),
                  subtitle: Text(l10n.aboutContact),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: 'meolivares06@gmail.com'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email copiado al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                // Safe bottom padding
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

/// A section header with title and descriptive subtitle for settings groups.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
