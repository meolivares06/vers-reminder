import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:vers_reminder/shared/shared.dart';
import 'package:vers_reminder/wallpaper/wallpaper.dart';
import 'package:vers_reminder/scheduler/scheduler.dart';
import 'package:vers_reminder/settings/application/appearance_settings.dart';
import 'package:vers_reminder/verses/verses.dart';
import 'package:vers_reminder/settings/infrastructure/update_service.dart';
import 'package:vers_reminder/settings/infrastructure/about_screen.dart';

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
    _ => l10n.timeMinutes(minutes),
  };
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.updateService});

  /// Test seam — the update service forwarded to the About screen. Defaults to
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
  /// Last-rendered preview as raw PNG bytes (~300 KB at default preview
  /// width). Held in memory to avoid repeated re-renders on every settings
  /// interaction. The size is acceptable because it is a single in-memory
  /// buffer discarded on screen dispose — no persistent disk footprint.
  Uint8List? _cachedPreview;
  int _previewGeneration = 0;

  /// True once a preview attempt produced nothing (no verse, no cached image,
  /// or a render error). Lets the mini-preview settle into a placeholder
  /// instead of showing an indeterminate spinner forever.
  bool _previewUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePreview();
    });
    EventBus.instance.on<BackupRestored>((event) async {
      if (!mounted) return;
      if (event.operation == 'restore') {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.success
                ? l10n.restoreSuccess
                : l10n.restoreError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
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
    final appearance = context.read<AppearanceSettings>();
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
    final previewWidth = (MediaQuery.of(context).size.width * 0.8).round();

    try {
      _previewImagePath ??= await ImageCacheService.instance
          .getNextRandomImage();

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
        previewHeight: 100,
        horizontalOffset: appearance.horizontalOffset,
        verticalAlignment: appearance.verticalAlignment,
        fontScale: appearance.fontScale,
        calibratedInset: appearance.calibratedInset,
        previewImagePath: _previewImagePath,
        useMyWallpaper: appearance.useMyWallpaper,
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
    final appearance = context.read<AppearanceSettings>();
    final l10n = AppLocalizations.of(context)!;

    if (appearance.userBackgroundPath == null) {
      // No image stored — open picker automatically
      try {
        final picker = ImagePicker();
        final XFile? pickedImage = await picker.pickImage(
          source: ImageSource.gallery,
        );

        if (pickedImage == null) {
          // User cancelled — revert to App
          await appearance.setUseMyWallpaper(false);
          return;
        }

        final appDir = await getApplicationDocumentsDirectory();
        final destPath = '${appDir.path}/user_background.png';
        await File(pickedImage.path).copy(destPath);
        await appearance.setUserBackgroundPath(destPath);
        await appearance.setUseMyWallpaper(true);
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
        await appearance.setUseMyWallpaper(false);
      }
    } else {
      // Image already stored — just toggle
      await appearance.setUseMyWallpaper(true);
      _previewImagePath = null;
      _schedulePreview();
    }
  }

  Future<void> _onReplaceImage() async {
    final appearance = context.read<AppearanceSettings>();
    final l10n = AppLocalizations.of(context)!;

    try {
      final picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedImage == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final destPath = '${appDir.path}/user_background.png';
      await File(pickedImage.path).copy(destPath);
      await appearance.setUserBackgroundPath(destPath);
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
    WallpaperState wallpaper,
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
              await wallpaper.grantPermission();
              await wallpaper.triggerNow(locale: locale);
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

    EventBus.instance.emit(const BackupRequested(operation: 'restore'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wallpaper = context.watch<WallpaperState>();
    final scheduler = context.watch<SchedulerConfig>();
    final appearance = context.watch<AppearanceSettings>();
    final verseProvider = context.watch<VerseProvider>();
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.settings),
          actions: [
            if (scheduler.isEnabled)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.circle, size: 10, color: Colors.green),
              ),
          ],
        ),
      body: wallpaper.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Appearance (wallpaper section, FIRST) ──
                SectionHeader(
                  title: l10n.sectionAppearance,
                ),
                // Mini preview — shown at the top of the wallpaper section so
                // the user sees the current composition before its params.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: _cachedPreview != null
                        ? Image.memory(_cachedPreview!, fit: BoxFit.cover)
                        : Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
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
                      ButtonSegment(value: 'top', label: Text(l10n.topAlign)),
                      ButtonSegment(
                        value: 'center',
                        label: Text(l10n.centerAlign),
                      ),
                      ButtonSegment(
                        value: 'bottom',
                        label: Text(l10n.bottomAlign),
                      ),
                    ],
                    selected: {appearance.verticalAlignment},
                    onSelectionChanged: (sel) {
                      appearance.setVerticalAlignment(sel.first);
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
                        child: Text(
                          l10n.backgroundSourceLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(l10n.backgroundSourceApp),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text(l10n.backgroundSourceMine),
                          ),
                        ],
                        selected: {appearance.useMyWallpaper},
                        onSelectionChanged: (sel) {
                          final value = sel.first;
                          if (value) {
                            _onMioSelected();
                          } else {
                            appearance.setUseMyWallpaper(false);
                            _previewImagePath = null;
                            _schedulePreview();
                          }
                        },
                      ),
                      // Thumbnail + Replace button when Mío is selected and image exists
                      if (appearance.useMyWallpaper &&
                          appearance.userBackgroundPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 100,
                        height: 100,
                                  child: Image.file(
                                    File(appearance.userBackgroundPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
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
                // Horizontal offset — rendered as ONE caption resolved from the value's
                // sign: no static left/right Row labels, no duplicate text node.
                // Direction word comes from the localized offsetLabel(direction, value).
                Slider(
                  value: appearance.horizontalOffset.toDouble(),
                  min: -20,
                  max: 20,
                  divisions: 40,
                  label: appearance.horizontalOffset.toString(),
                  onChanged: (v) {
                    appearance.setHorizontalOffset(v.round());
                    _schedulePreview();
                  },
                ),

                // Font scale
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('A-'),
                    Expanded(
                      child: Slider(
                        value: appearance.fontScale,
                        min: 0.6,
                        max: 1.8,
                        divisions: 24,
                        label: appearance.fontScale.toStringAsFixed(2),
                        onChanged: (v) {
                          appearance.setFontScale(
                            double.parse(v.toStringAsFixed(2)),
                          );
                          _schedulePreview();
                        },
                      ),
                    ),
                    const Text('A+'),
                  ],
                ),

                // ── Restore original wallpaper ──
                const SizedBox(height: 8),
                AsyncActionButton(
                  icon: Icons.restore,
                  label: l10n.restoreOriginalWallpaper,
                  style: AsyncActionButtonStyle.tile,
                  enabled: wallpaper.hasBackup,
                  onPressed: () => _showRestoreDialog(context, l10n),
                ),

                // ── Scheduling ──
                const Divider(),
                SectionHeader(
                  title: l10n.sectionScheduling,
                ),
                SwitchListTile(
                  title: Text(l10n.autoChange),
                  subtitle: scheduler.isEnabled
                      ? Text(_frequencyLabel(scheduler.frequencyMinutes, l10n))
                      : null,
                  value: scheduler.isEnabled,
                  onChanged: (v) => scheduler.setEnabled(v),
                ),
                if (scheduler.isEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ChipTheme(
                      // The selected chip sits on the gold brand surface; the
                      // default M3 selected label color (onSurfaceVariant) is
                      // near-white in dark mode and fails contrast on gold.
                      // Pin the selected label to the fixed dark tone used on
                      // the gold brand surface in both themes.
                      data: ChipTheme.of(context).copyWith(
                        secondaryLabelStyle: TextStyle(color: onGoldAccent),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: SettingsScreen.frequencyOptions
                            .map(
                              (freq) => ChoiceChip(
                                label: Text(_frequencyLabel(freq, l10n)),
                                selected: scheduler.frequencyMinutes == freq,
                                // Gold tint on the selected control via
                                // colorScheme.secondary.
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                onSelected: (_) => scheduler.setFrequency(freq),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                // ── Categories ──
                const Divider(),
                SectionHeader(
                  title: l10n.categoriesLabel,
                ),
                // Select all / Clear all
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      tooltip: l10n.selectAll,
                      onPressed: () {
                        for (final cat in verseProvider.categories) {
                          if (!scheduler.activeCategoryIds.contains(cat.id)) {
                            scheduler.toggleCategory(cat.id!);
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.deselect),
                      tooltip: l10n.clearAll,
                      onPressed: () {
                        for (final cat in verseProvider.categories) {
                          if (scheduler.activeCategoryIds.contains(cat.id)) {
                            scheduler.toggleCategory(cat.id!);
                          }
                        }
                      },
                    ),
                  ],
                ),
                ...verseProvider.categories.map(
                  (cat) => CheckboxListTile(
                    title: Text(cat.name),
                    value: scheduler.activeCategoryIds.contains(cat.id),
                    onChanged: (_) => scheduler.toggleCategory(cat.id!),
                  ),
                ),

                // ── Actions ──
                const Divider(),
                SectionHeader(
                  title: l10n.sectionActions,
                ),
                AsyncActionButton(
                  icon: Icons.wallpaper,
                  label: l10n.changeNow,
                  style: AsyncActionButtonStyle.filled,
                  onPressed: () async {
                    if (!wallpaper.wallpaperPermissionGranted) {
                      _showWallpaperPermissionDialog(
                        context,
                        wallpaper,
                        locale,
                        l10n,
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    // Resolve the theme error tint before the async gap so the
                    // SnackBar text can use it without a post-await context use.
                    final errorColor = Theme.of(context).colorScheme.error;
                    await wallpaper.triggerNow(locale: locale);
                    if (!mounted) return;
                    final status = wallpaper.status;
                    if (status == WallpaperStatus.updated) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.wallpaperUpdated(wallpaper.statusPayload ?? ''),
                          ),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(label: 'OK', onPressed: () {}),
                        ),
                      );
                    } else if (status == WallpaperStatus.error) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.generatingError,
                            style: TextStyle(color: errorColor),
                          ),
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

                // ── About ──
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.sectionAbout),
                  trailing: Text(
                    'v1.0.0+3',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AboutScreen(updateService: widget.updateService),
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
