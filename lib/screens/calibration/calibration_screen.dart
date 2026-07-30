import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/wallpaper_status.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/image_cache_service.dart';
import '../../services/wallpaper_generator.dart';

/// Overlay painter that shows the launcher crop zone as semi-transparent
/// black bars on each edge of the preview.
///
/// [inset] is the pixel amount cropped at full display resolution.
/// [screenWidth] is the actual screen width in display pixels — the inset
/// is scaled proportionally to the preview canvas size.
class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.inset,
    required this.screenWidth,
  });

  final int inset;
  final double screenWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (inset <= 0) return;

    // Scale the inset from display resolution to the preview canvas width
    final cropWidth = inset * (size.width / screenWidth);

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    // Top bar
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropWidth), paint);
    // Bottom bar
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - cropWidth, size.width, cropWidth),
      paint,
    );
    // Left bar
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cropWidth, size.height),
      paint,
    );
    // Right bar
    canvas.drawRect(
      Rect.fromLTWH(size.width - cropWidth, 0, cropWidth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.inset != inset || oldDelegate.screenWidth != screenWidth;
}

/// Calibration screen for wallpaper crop inset with live preview.
///
/// Flow: preview with crop-zone overlay updates instantly as slider adjusts
/// → "Aplicar y verificar" generates at full resolution and sets wallpaper
/// → check home screen → return here → adjust → repeat → "Guardar" when done.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  Uint8List? _previewBytes;
  bool _previewPending = true;
  String? _previewImagePath;
  Timer? _debounce;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Renders the preview with the current horizontal offset.
  /// The crop zone is shown as a visual overlay that updates
  /// instantly — no need to regenerate for crop changes.
  Future<void> _loadPreview({int generation = 0}) async {
    if (!mounted) return;

    final verseProvider = context.read<VerseProvider>();
    final settings = context.read<SettingsProvider>();
    final locale = context.read<LocaleProvider>().locale.languageCode;

    final verse = verseProvider.groupedVerses.values
        .expand((list) => list)
        .firstOrNull;

    _previewImagePath ??=
        await ImageCacheService.instance.getNextRandomImage();

    if (!mounted || verse == null || _previewImagePath == null) {
      if (mounted) setState(() => _previewPending = false);
      return;
    }

    // Match preview aspect ratio to the phone screen so the aspect-ratio
    // crop in _composite produces the same result at both preview and full res.
    final screenSize = MediaQuery.of(context).size;
    const previewWidth = 270;
    final previewHeight =
        (previewWidth * screenSize.height / screenSize.width).round();

    final bytes = await WallpaperGenerator.instance.renderPreview(
      verse: verse,
      locale: locale,
      horizontalOffset: settings.horizontalOffset,
      verticalAlignment: settings.verticalAlignment,
      fontScale: settings.fontScale,
      calibratedInset: 0, // no crop — overlay shows the crop zone
      previewImagePath: _previewImagePath,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );

    if (!mounted) return;
    setState(() {
      if (bytes != null && generation == _previewGeneration) {
        _previewBytes = bytes;
      }
      _previewPending = false;
    });
  }

  /// Schedules a preview regeneration (debounced) when settings that
  /// affect the text rendering (offset, alignment, fontScale) change.
  /// Keeps the current preview visible while loading (no flicker).
  void _schedulePreview() {
    _debounce?.cancel();
    _previewGeneration++;
    final gen = _previewGeneration;
    _debounce = Timer(
      const Duration(milliseconds: 150),
      () => _loadPreview(generation: gen),
    );
  }

  /// Builds a row showing a setting label and its current value.
  Widget _valueRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  /// Local helper: maps [WallpaperStatus] + [payload] to a localized string.
  String _mapStatus(
      WallpaperStatus status, String? payload, AppLocalizations l10n) {
    return switch (status) {
      WallpaperStatus.idle => '',
      WallpaperStatus.generating => l10n.generating,
      WallpaperStatus.updated => l10n.wallpaperUpdated(payload ?? ''),
      WallpaperStatus.error => l10n.generatingError,
      WallpaperStatus.noCategories => l10n.selectCategoryStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final verseProvider = context.watch<VerseProvider>();
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibrationTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.calibrationTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.calibrationInstructions,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Live preview with crop overlay
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: _previewBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_previewBytes!, fit: BoxFit.contain),
                          // Crop zone overlay — updates instantly with slider
                          CustomPaint(
                            painter: _CropOverlayPainter(
                              inset: settings.calibratedInset,
                              screenWidth: screenWidth,
                            ),
                          ),
                          // Center label showing crop value
                          if (settings.calibratedInset > 0)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${settings.calibratedInset} px',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: _previewPending
                            ? const CircularProgressIndicator()
                            : Text(
                                'Generando preview...',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Current value display
            Text(
              '${l10n.cropInsetLabel}: ${settings.calibratedInset} px',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cropInsetDesc,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Crop inset slider — instant, no debounce
            Slider(
              value: settings.calibratedInset.toDouble(),
              min: 0,
              max: 500,
              divisions: 100,
              label: '${settings.calibratedInset} px',
              onChanged: (v) => settings.setCalibratedInset(v.round()),
            ),
            const SizedBox(height: 8),

            // Horizontal offset slider
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
            const SizedBox(height: 16),

            // Current values info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajustes actuales',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _valueRow(
                      context,
                      l10n.cropInsetLabel,
                      '${settings.calibratedInset} px',
                      Icons.crop,
                    ),
                    const SizedBox(height: 4),
                    _valueRow(
                      context,
                      'Offset horizontal',
                      '${settings.horizontalOffset} px '
                      '(${settings.horizontalOffset < 0 ? l10n.leftOffset : l10n.rightOffset})',
                      Icons.swap_horiz,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Apply button
            FilledButton.icon(
              icon: const Icon(Icons.wallpaper),
              label: Text(l10n.applyVerify),
              onPressed: () => settings.triggerNow(
                verseProvider: verseProvider,
                locale: locale,
              ),
            ),
            const SizedBox(height: 12),

            // Save button
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(l10n.saveCalibration),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.saveCalibration)),
                );
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 12),

            // Reset button
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reset),
              onPressed: () => settings.setCalibratedInset(0),
            ),

            // Status message
            if (settings.status != WallpaperStatus.idle) ...[
              const SizedBox(height: 16),
              Card(
                color: settings.status == WallpaperStatus.error
                    ? Colors.red.shade900
                    : Colors.green.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        settings.status == WallpaperStatus.error
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mapStatus(
                              settings.status, settings.statusPayload, l10n),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }
}
