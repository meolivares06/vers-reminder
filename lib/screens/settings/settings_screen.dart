import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/wallpaper_status.dart';
import '../../providers/locale_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/image_cache_service.dart';
import '../../services/wallpaper_generator.dart';
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const List<int> frequencyOptions = [15, 30, 60, 180, 360, 720, 1440];

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Timer? _previewTimer;
  String? _previewImagePath;
  Uint8List? _cachedPreview;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePreview());
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

    if (verse == null) {
      if (mounted) setState(() => _cachedPreview = null);
      return;
    }

    // Capture width before async gap
    final previewWidth =
        (MediaQuery.of(context).size.width * 0.8).round();

    _previewImagePath ??=
        await ImageCacheService.instance.getNextRandomImage();

    if (_previewImagePath == null) return;

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
    );

    if (!mounted || generation != _previewGeneration) return;
    setState(() => _cachedPreview = bytes);
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
                // ── Scheduling ──
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

                // ── Appearance ──
                const Divider(),
                _SectionHeader(
                  title: l10n.sectionAppearance,
                  subtitle: l10n.sectionAppearanceSub,
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
                // Mini preview
                const SizedBox(height: 12),
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
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.wallpaper),
                  label: Text(l10n.changeNow),
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
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutVersion),
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
