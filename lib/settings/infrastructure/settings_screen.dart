import 'dart:io';

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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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

    final isGenerating = wallpaper.status == WallpaperStatus.generating;

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
                // Text position schematic — shows where the verse text will land
                // on the wallpaper without rendering the actual image.
                _TextPositionSchematic(
                  horizontalOffset: appearance.horizontalOffset,
                  verticalAlignment: appearance.verticalAlignment,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isGenerating ? null : () async {
          if (!wallpaper.wallpaperPermissionGranted) {
            _showWallpaperPermissionDialog(context, wallpaper, locale, l10n);
            return;
          }
          final messenger = ScaffoldMessenger.of(context);
          final errorColor = Theme.of(context).colorScheme.error;
          await wallpaper.triggerNow(locale: locale);
          if (!mounted) return;
          final status = wallpaper.status;
          if (status == WallpaperStatus.updated) {
            messenger.showSnackBar(SnackBar(
              content: Text(l10n.wallpaperUpdated(wallpaper.statusPayload ?? '')),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ));
          } else if (status == WallpaperStatus.error) {
            messenger.showSnackBar(SnackBar(
              content: Text(l10n.generatingError, style: TextStyle(color: errorColor)),
              behavior: SnackBarBehavior.floating,
            ));
          } else if (status == WallpaperStatus.noCategories) {
            messenger.showSnackBar(SnackBar(
              content: Text(l10n.selectCategoryStatus),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        icon: isGenerating
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.wallpaper),
        label: Text(isGenerating ? l10n.generating : l10n.applyChanges),
      ),
    );
  }
}

/// A lightweight schematic showing where the verse text will land on the
/// wallpaper. Replaces the live [WallpaperGenerator.renderPreview] call so
/// the settings screen stays fast and reactive.
///
/// The colored bar represents the wallpaper area. The shaded text block
/// moves horizontally according to [horizontalOffset] and vertically
/// according to [verticalAlignment], giving instant positional feedback.
class _TextPositionSchematic extends StatelessWidget {
  final int horizontalOffset;
  final String verticalAlignment;

  const _TextPositionSchematic({
    required this.horizontalOffset,
    required this.verticalAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 72,
          width: double.infinity,
          child: ColoredBox(
            color: surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Map horizontal offset (-20..20) to x position within the bar.
                final maxW = constraints.maxWidth;
                final textBlockW = maxW * 0.4; // ~40% of width
                final centerX = (maxW - textBlockW) / 2;
                final offsetX = (horizontalOffset / 20.0) *
                    ((maxW - textBlockW) / 2);
                final left = centerX + offsetX;

                // Map vertical alignment to y position.
                final maxH = constraints.maxHeight;
                final textBlockH = 28.0;
                final top = switch (verticalAlignment) {
                  'top' => 8.0,
                  'center' => (maxH - textBlockH) / 2,
                  _ => maxH - textBlockH - 8, // bottom
                };

                return Stack(
                  children: [
                    // Text block — shaded region where the verse lands.
                    Positioned(
                      left: left,
                      top: top,
                      width: textBlockW,
                      height: textBlockH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Aa',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Horizontal offset indicator — small arrow showing direction.
                    if (horizontalOffset != 0)
                      Positioned(
                        top: maxH / 2 - 6,
                        left: horizontalOffset > 0
                            ? left + textBlockW + 4
                            : left - 16,
                        child: Icon(
                          horizontalOffset > 0
                              ? Icons.arrow_forward_ios
                              : Icons.arrow_back_ios,
                          size: 12,
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
