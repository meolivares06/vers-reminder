import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

import 'package:vers_reminder/shared/shared.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_result.dart';
import 'package:vers_reminder/wallpaper/infrastructure/image_cache_service.dart';

/// Generates and optionally sets wallpapers composed of verse text
/// over a background with dark overlay.
///
/// Architecture (hybrid rendering):
/// 1. [image] package loads JPG, applies dark overlay, encodes PNG
/// 2. Flutter [TextPainter] renders verse text at native resolution
/// 3. Final composition merges both layers
///
/// Singleton pattern matching [ImageCacheService] conventions.
class WallpaperGenerator {
  static final WallpaperGenerator instance = WallpaperGenerator._internal();
  WallpaperGenerator._internal();

  static const double _textPaddingRatio = 0.08;
  static const double _baseFontRatio = 0.04;
  static const double _minFontRatio = 0.015;
  static const double _fontStep = 2.0;
  static const double _citationFontSizeRatio = 0.75;

  /// Gold brand color used for the citation dash (matches `goldAccent`).
  @visibleForTesting
  static const Color citationRuleColor = Color(0xFFEFB14D);

  /// Shared typographic identity for the verse text: EB Garamond.
  ///
  /// Used by BOTH the paint pass and [_resolveFontSize] so measurement can
  /// never drift from what renders (spec R-WG "Measurement-Paint parity").
  @visibleForTesting
  TextStyle verseMeasureStyle(double size) => TextStyle(
    fontSize: size,
    height: 1.4,
    fontFamily: 'EB Garamond',
  );

  /// Shared typographic identity for the citation: sans-serif (no explicit
  /// family), letter-spaced, rendered uppercase via [citationDisplayText].
  @visibleForTesting
  TextStyle citationMeasureStyle(double size) =>
      TextStyle(fontSize: size, height: 1.4, letterSpacing: 1.5);

  /// Uppercase transformation applied to the citation in both the paint and
  /// measurement passes — kept in one place so the fitting loop always
  /// measures the exact text that will be drawn.
  @visibleForTesting
  String citationDisplayText(String citation) => citation.toUpperCase();

  /// Main entry point: generate and optionally set wallpaper.
  ///
  /// [screenWidth] and [screenHeight] resize the background to device
  /// screen dimensions. [horizontalOffset] shifts text proportionally:
  /// each unit ≈ 0.5% of image width. [fontScale] multiplies font size
  /// (1.0 = default). [calibratedInset] crops each side of the background
  /// before resize to compensate for launcher cropping.
  ///
  /// Returns a [WallpaperResult] variant — pattern-match on the result
  /// rather than reading string error messages.
  Future<WallpaperResult> generateAndSetWallpaper({
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    try {
      String? imagePath;
      if (!useMyWallpaper) {
        imagePath = await ImageCacheService.instance.getNextRandomImage();
        if (imagePath == null) {
          return WallpaperResultError(WallpaperErrorReason.backgroundMissing);
        }
      }

      final outputPath = await _render(
        backgroundPath: imagePath ?? '',
        verse: verse,
        locale: locale,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        horizontalOffset: horizontalOffset,
        verticalAlignment: verticalAlignment,
        fontScale: fontScale,
        calibratedInset: calibratedInset,
        useMyWallpaper: useMyWallpaper,
      );
      if (outputPath == null) {
        return WallpaperResultError(WallpaperErrorReason.renderFailed);
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _setWallpaper(outputPath, screenWidth ?? 0, screenHeight ?? 0);
        } catch (e) {
          // Wallpaper was generated successfully; set failure is logged.
          // ignore: avoid_print
          print('WallpaperGenerator: generated but could not set: $e');
        }
      }

      return WallpaperResultSuccess(
        outputPath,
        _selectText(verse, locale),
        verse.citation,
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('WallpaperGenerator ERROR: $e\n$stack');
      return WallpaperResultError(WallpaperErrorReason.storageFailure);
    }
  }

  /// Render-only: generate wallpaper PNG without setting it.
  ///
  /// Optional [screenWidth] and [screenHeight] resize the background to
  /// device screen dimensions before compositing. When omitted, the
  /// background keeps its native resolution.
  Future<String?> renderOnly({
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    try {
      if (!useMyWallpaper) {
        final imagePath = await ImageCacheService.instance.getNextRandomImage();
        if (imagePath == null) return null;
        return await _render(
          backgroundPath: imagePath,
          verse: verse,
          locale: locale,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          horizontalOffset: horizontalOffset,
          verticalAlignment: verticalAlignment,
          fontScale: fontScale,
          calibratedInset: calibratedInset,
          useMyWallpaper: false,
        );
      }
      return await _render(
        backgroundPath: '',
        verse: verse,
        locale: locale,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        horizontalOffset: horizontalOffset,
        verticalAlignment: verticalAlignment,
        fontScale: fontScale,
        calibratedInset: calibratedInset,
        useMyWallpaper: true,
      );
    } catch (e) {
      debugPrint('renderOnly failed: $e');
      return null;
    }
  }

  /// Exposed for testing only. Calls [_render] with an explicit
  /// background path and optional screen dimensions, bypassing
  /// [ImageCacheService].
  @visibleForTesting
  Future<String?> renderFromPath({
    required String backgroundPath,
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
  }) => _render(
    backgroundPath: backgroundPath,
    verse: verse,
    locale: locale,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    horizontalOffset: horizontalOffset,
    verticalAlignment: verticalAlignment,
    fontScale: fontScale,
    calibratedInset: calibratedInset,
  );

  /// Core compositing pipeline — no file I/O.
  ///
  /// Renders the full wallpaper on a [ui.Canvas] at exact [screenWidth] ×
  /// [screenHeight] using GPU-accelerated [drawImageRect] for background
  /// scaling and [TextPainter] for verse text. Then rasterizes to PNG bytes.
  ///
  /// Order of operations:
  /// 1. Decode background bytes to [ui.Image] via [instantiateImageCodec]
  /// 2. Apply center-crop + optional [calibratedInset] via [drawImageRect]
  /// 3. Draw dark overlay rectangle
  /// 4. Measure text with dynamic font sizing (shrinks until it fits)
  /// 5. Paint text and citation onto the same canvas
  /// 6. Rasterize to PNG via [Picture.toImage] + [toByteData]
  ///
  /// Returns null only if image bytes cannot be decoded or canvas export fails.
  Future<Uint8List?> _compositeCanvas({
    required Uint8List backgroundBytes,
    required Verse verse,
    required String locale,
    required int screenWidth,
    required int screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
  }) async {
    // --- 1. Decode background ---
    ui.Image? bg;
    try {
      final codec = await ui.instantiateImageCodec(backgroundBytes);
      final frame = await codec.getNextFrame();
      bg = frame.image;
      codec.dispose();
    } catch (_) {
      return null;
    }

    // Yield after heavy image decode
    await Future<void>.delayed(Duration.zero);

    // --- 2. Set up Canvas at exact screen dimensions ---
    ui.Picture? picture; // F1: declared before try so finally can null-guard dispose
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, screenWidth.toDouble(), screenHeight.toDouble()),
    );

    try {
      // --- 3. Center-crop + calibratedInset ---
      double srcX = 0, srcY = 0;
      double srcW = bg.width.toDouble();
      double srcH = bg.height.toDouble();

      if (calibratedInset > 0) {
        final maxInset = (srcW / 2) - 1;
        final actualInset = calibratedInset < maxInset
            ? calibratedInset.toDouble()
            : maxInset;
        srcX += actualInset;
        srcW -= actualInset * 2;
      }

      // Cover: image fills entire canvas, centered, no distortion
      final scaleX = screenWidth / srcW;
      final scaleY = screenHeight / srcH;
      final coverScale = scaleX > scaleY ? scaleX : scaleY;

      final dstW = srcW * coverScale;
      final dstH = srcH * coverScale;
      final dstX = (screenWidth - dstW) / 2;
      final dstY = (screenHeight - dstH) / 2;

      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(srcX, srcY, srcW, srcH),
        Rect.fromLTWH(dstX, dstY, dstW, dstH),
        Paint()..filterQuality = FilterQuality.high,
      );

      // --- 4. Dark overlay (40 % ) ---
      canvas.drawRect(
        Rect.fromLTWH(0, 0, screenWidth.toDouble(), screenHeight.toDouble()),
        Paint()..color = const Color(0x66000000),
      );

      // --- 5. Text layout ---
      final text = _selectText(verse, locale);
      final citation = verse.citation;
      final padding = (screenWidth * _textPaddingRatio).toDouble();
      final maxTextWidth = screenWidth - (padding * 2);
      final availableHeight = screenHeight - (padding * 2);
      const gap = 16.0;

      final resolvedFontSize = _resolveFontSize(
        text: text,
        citation: citation,
        maxTextWidth: maxTextWidth,
        availableHeight: availableHeight,
        screenWidth: screenWidth,
        fontScale: fontScale,
      );
      final citationFontSize = resolvedFontSize * _citationFontSizeRatio;

      // Shadow for readability
      final shadow = Shadow(
        color: Colors.black.withValues(alpha: 0.6),
        blurRadius: 6,
        offset: const Offset(2, 2),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: verseMeasureStyle(resolvedFontSize).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [shadow],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 10,
        ellipsis: '...',
      )..layout(maxWidth: maxTextWidth);

      // F2: nested try/finally — citationPainter scoped inside textPainter's
      // disposal block so both are guaranteed disposed in reverse-creation order.
      try {
        final citationPainter = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '— ',
                style: citationMeasureStyle(citationFontSize).copyWith(
                  color: citationRuleColor,
                  fontWeight: FontWeight.w500,
                  shadows: [shadow],
                ),
              ),
              TextSpan(
                text: citationDisplayText(citation),
                style: citationMeasureStyle(citationFontSize).copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  shadows: [shadow],
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxTextWidth);

        final totalTextHeight =
            textPainter.height + gap + citationPainter.height;

        // Vertical position (clamp to stay on screen)
        final startY = switch (verticalAlignment) {
          'top' => padding,
          'bottom' => (screenHeight - totalTextHeight - padding).clamp(
            0.0,
            screenHeight.toDouble(),
          ),
          _ => ((screenHeight - totalTextHeight) / 2).clamp(
            0.0,
            screenHeight.toDouble(),
          ),
        };

        // Horizontal position with user offset (clamp to screen edges)
        final startX = (padding + horizontalOffset).clamp(
          0.0,
          (screenWidth - textPainter.width - gap).clamp(
            0.0,
            screenWidth.toDouble(),
          ),
        );

        // INNER: paint scope — citationPainter.dispose() in inner finally
        try {
          textPainter.paint(canvas, Offset(startX, startY));

          final citationTop = startY + textPainter.height + gap;
          citationPainter.paint(canvas, Offset(startX, citationTop));
        } finally {
          citationPainter.dispose();
        }
      } finally {
        textPainter.dispose();
      }

      // Yield before rasterization — PNG encode is CPU-heavy
      await Future<void>.delayed(Duration.zero);

      // --- 6. Rasterize to PNG via background isolate ---
      picture = recorder.endRecording(); // F1: assign outer nullable variable
      final image = await picture.toImage(screenWidth, screenHeight);
      picture.dispose();
      picture = null; // F1: after success-path dispose, null-out so finally guard is no-op
      // rawRgba is fast — GPU readback without PNG encoding
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      if (byteData == null) return null;
      final rawBytes = byteData.buffer.asUint8List();
      // PNG encode in isolate to avoid blocking the UI thread.
      // Falls back to synchronous encoding if isolate is unavailable
      // (e.g., in test environments or constrained runtimes).
      try {
        return await compute(_encodePngWorker, (
          rawBytes,
          screenWidth,
          screenHeight,
        ));
      } catch (e) {
        debugPrint('PNG encode isolate failed: $e');
        // Fallback: encode synchronously on main thread
        return _encodePngWorker((rawBytes, screenWidth, screenHeight));
      }
    } finally {
      picture?.dispose(); // F1: error-path cleanup — no-op on success (nulled above)
      bg.dispose();
    }
  }

  /// Resolves background image bytes based on the source selection.
  ///
  /// When [useMyWallpaper] is `false`: reads a random cached nature image
  /// via [ImageCacheService] and returns its bytes. May return null if no
  /// cached image is available.
  ///
  /// When [useMyWallpaper] is `true`: reads the user's picked background
  /// image from `{appDir}/user_background.png` via [File.readAsBytes].
  /// The path is stored in SharedPreferences under `user_background_path`.
  /// Returns null if the path is missing, the file doesn't exist, or the
  /// read fails — the caller should fall back to nature images.
  Future<Uint8List?> _getBackgroundBytes({required bool useMyWallpaper}) async {
    if (!useMyWallpaper) {
      final path = await ImageCacheService.instance.getNextRandomImage();
      if (path == null) return null;
      return await File(path).readAsBytes();
    }
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('user_background_path');
    if (path == null) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      // ignore: avoid_print
      print('WallpaperGenerator: read user background failed: $e');
      return null;
    }
  }

  /// Runs the font-sizing loop: starts at [screenWidth] × [_baseFontRatio]
  /// × [fontScale] and shrinks by [_fontStep] until all text + citation fits
  /// within [availableHeight].
  ///
  /// The measurement TextStyles mirror the paint pass exactly — italic EB
  /// Garamond verse, sans-serif uppercase citation with letterSpacing — so
  /// the resolved size never overflows what actually renders. When
  /// [legacyStyles] is true (test-only parity check), the pre-change styles
  /// are used instead.
  double _resolveFontSize({
    required String text,
    required String citation,
    required double maxTextWidth,
    required double availableHeight,
    required int screenWidth,
    required double fontScale,
    bool legacyStyles = false,
  }) {
    final baseSize = screenWidth * _baseFontRatio * fontScale;
    final minSize = screenWidth * _minFontRatio * fontScale;
    const gap = 16.0;
    final measureCitation = legacyStyles
        ? citation
        : '— ${citationDisplayText(citation)}';

    for (var size = baseSize; size >= minSize; size -= _fontStep) {
      final citationSize = size * _citationFontSizeRatio;

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: legacyStyles
              ? TextStyle(
                  fontSize: size,
                  height: 1.4,
                  fontFamily: 'EB Garamond',
                )
              : verseMeasureStyle(size),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);

      final cp = TextPainter(
        text: TextSpan(
          text: measureCitation,
          style: legacyStyles
              ? TextStyle(
                  fontSize: citationSize,
                  height: 1.4,
                  fontFamily: 'EB Garamond',
                )
              : citationMeasureStyle(citationSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);

      final totalHeight = tp.height + gap + cp.height;
      tp.dispose();
      cp.dispose();

      if (totalHeight <= availableHeight || size <= minSize + _fontStep) {
        return size;
      }
    }
    return minSize;
  }

  /// Testing seam — resolves the verse/citation font size with the current
  /// typographic styles, or with the pre-change legacy styles when
  /// [legacyStyles] is true, so tests can prove measurement-paint parity
  /// stays within 1px (spec "No sizing regression after style change").
  @visibleForTesting
  double resolveFontSizeForTest({
    required String text,
    required String citation,
    required double maxTextWidth,
    required double availableHeight,
    required int screenWidth,
    double fontScale = 1.0,
    bool legacyStyles = false,
  }) => _resolveFontSize(
    text: text,
    citation: citation,
    maxTextWidth: maxTextWidth,
    availableHeight: availableHeight,
    screenWidth: screenWidth,
    fontScale: fontScale,
    legacyStyles: legacyStyles,
  );

  /// Exposed for testing only. Calls [_compositeCanvas] directly with raw bytes.
  @visibleForTesting
  Future<Uint8List?> compositeFromBytes({
    required Uint8List backgroundBytes,
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
  }) => _compositeCanvas(
    backgroundBytes: backgroundBytes,
    verse: verse,
    locale: locale,
    screenWidth: screenWidth ?? 1080,
    screenHeight: screenHeight ?? 2400,
    horizontalOffset: horizontalOffset,
    verticalAlignment: verticalAlignment,
    fontScale: fontScale,
    calibratedInset: calibratedInset,
  );

  /// Core render pipeline — reads file, composites via Canvas, writes PNG.
  Future<String?> _render({
    required String backgroundPath,
    required Verse verse,
    required String locale,
    int? screenWidth,
    int? screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    final w = screenWidth ?? 1080;
    final h = screenHeight ?? 2400;

    // 1. Load background image bytes
    late Uint8List bytes;
    if (useMyWallpaper) {
      final bgBytes = await _getBackgroundBytes(useMyWallpaper: true);
      if (bgBytes != null) {
        bytes = bgBytes;
      } else {
        // Fallback to nature
        // ignore: avoid_print
        print(
          'WallpaperGenerator: user background not available in _render, falling back to nature',
        );
        final fallbackPath = await ImageCacheService.instance
            .getNextRandomImage();
        if (fallbackPath == null) return null;
        bytes = await File(fallbackPath).readAsBytes();
      }
    } else {
      final file = File(backgroundPath);
      bytes = await file.readAsBytes();
    }

    // 2. Composite via Canvas pipeline
    final pngBytes = await _compositeCanvas(
      backgroundBytes: bytes,
      verse: verse,
      locale: locale,
      screenWidth: w,
      screenHeight: h,
      horizontalOffset: horizontalOffset,
      verticalAlignment: verticalAlignment,
      fontScale: fontScale,
      calibratedInset: calibratedInset,
    );
    if (pngBytes == null) return null;

    // 3. Write to temp file and return path
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outputPath).writeAsBytes(pngBytes);

    return outputPath;
  }

  /// Render a preview of the wallpaper at reduced resolution.
  ///
  /// Picks a random cached background image, composites the verse at
  /// [previewWidth] × [previewHeight], and returns raw PNG bytes.
  /// Returns null if no cached image is available or compositing fails.
  /// Performs no file I/O.
  ///
  /// Provide [previewImagePath] to reuse the same background across
  /// consecutive preview calls — essential for calibration where the
  /// user needs to see the crop effect on a single stable image.
  Future<Uint8List?> renderPreview({
    required Verse verse,
    required String locale,
    int previewWidth = 270,
    int previewHeight = 480,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    String? previewImagePath,
    bool useMyWallpaper = false,
  }) async {
    try {
      Uint8List? bytes;
      if (useMyWallpaper) {
        bytes = await _getBackgroundBytes(useMyWallpaper: true);
      }

      if (bytes == null) {
        final imagePath =
            previewImagePath ??
            await ImageCacheService.instance.getNextRandomImage();
        if (imagePath == null) return null;

        final file = File(imagePath);
        bytes = await file.readAsBytes();
      }

      return await _compositeCanvas(
        backgroundBytes: bytes,
        verse: verse,
        locale: locale,
        screenWidth: previewWidth,
        screenHeight: previewHeight,
        horizontalOffset: horizontalOffset,
        verticalAlignment: verticalAlignment,
        fontScale: fontScale,
        calibratedInset: calibratedInset,
      );
    } catch (_) {
      return null;
    }
  }

  /// Select the verse text based on active locale.
  String _selectText(Verse verse, String locale) {
    if (locale == 'pt') {
      return verse.textPt ?? verse.textEs;
    }
    return verse.textEs;
  }

  /// Tells Android not to rescale the wallpaper by suggesting the exact
  /// screen dimensions. Must be called BEFORE setWallpaper.
  Future<void> _suggestDesiredDimensions(int width, int height) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      const channel = MethodChannel('vers_reminder/wallpaper');
      await channel.invokeMethod('suggestDesiredDimensions', {
        'width': width,
        'height': height,
      });
    } catch (_) {
      // Non-fatal: wallpaper settings still proceed even if this fails.
      // ignore: avoid_print
      print('WallpaperGenerator: suggestDesiredDimensions failed (ignored)');
    }
  }

  /// Set wallpaper on Android using [wallpaper_manager_flutter].
  Future<void> _setWallpaper(
    String imagePath,
    int screenWidth,
    int screenHeight,
  ) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Wallpaper file not found: $imagePath');
    }

    try {
      // Tell Android the wallpaper is already at exact screen dimensions
      await _suggestDesiredDimensions(screenWidth, screenHeight);

      final manager = WallpaperManagerFlutter();
      await manager.setWallpaper(file, WallpaperManagerFlutter.bothScreens);
    } catch (e) {
      throw Exception('Failed to set wallpaper: $e');
    }
  }

  // ── Pre-generated wallpaper cache ──

  /// Number of wallpapers to pre-generate for the background scheduler.
  static const int preGenCount = 5;
  static const String _preGenDirName = 'pre_generated';

  /// Generates up to [_preGenCount] wallpapers with random verses and
  /// background images, saved to a cache directory for the WorkManager
  /// callback to use (which cannot run Flutter rendering APIs).
  ///
  /// Each wallpaper uses the current layout settings. Clears old pre-generated
  /// files first. Stores the count and a starting index in SharedPreferences
  /// under keys `pregen_count` and `pregen_index`.
  Future<int> preGenerateWallpapers({
    required List<Verse> verses,
    required String locale,
    required int screenWidth,
    required int screenHeight,
    int horizontalOffset = 0,
    String verticalAlignment = 'center',
    double fontScale = 1.0,
    int calibratedInset = 0,
    bool useMyWallpaper = false,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final preGenDir = Directory(p.join(appDir.path, _preGenDirName));
    if (!await preGenDir.exists()) {
      await preGenDir.create(recursive: true);
    }

    // Clean old pre-generated files
    await for (final entry in preGenDir.list()) {
      if (entry is File) await entry.delete();
    }

    // Resolve background bytes once for the entire batch when using
    // the user's wallpaper — ensures visual consistency across all
    // pre-generated PNGs and avoids repeated MethodChannel calls.
    Uint8List? batchBytes;
    if (useMyWallpaper) {
      batchBytes = await _getBackgroundBytes(useMyWallpaper: true);
      if (batchBytes == null) {
        // ignore: avoid_print
        print(
          'WallpaperGenerator: user background not available in preGenerate, '
          'falling back to nature per wallpaper',
        );
      }
    }

    final rng = Random();
    int count = 0;
    for (int i = 0; i < preGenCount && i < verses.length; i++) {
      final verse = verses[i];

      Uint8List backgroundBytes;
      if (batchBytes != null) {
        backgroundBytes = batchBytes;
      } else {
        final imagePath = await ImageCacheService.instance.getNextRandomImage();
        if (imagePath == null) continue;
        backgroundBytes = await File(imagePath).readAsBytes();
      }

      final pngBytes = await _compositeCanvas(
        backgroundBytes: backgroundBytes,
        verse: verse,
        locale: locale,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        horizontalOffset: rng.nextBool() ? horizontalOffset : 0,
        verticalAlignment: verticalAlignment,
        fontScale: fontScale,
        calibratedInset: calibratedInset,
      );

      if (pngBytes == null) continue;

      await File(
        p.join(preGenDir.path, 'pregen_$i.png'),
      ).writeAsBytes(pngBytes);
      count++;
    }

    // Reset index for next consumption round
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pregen_index', 0);
    await prefs.setInt('pregen_count', count);

    return count;
  }

  /// Tries to set the next available pre-generated wallpaper.
  ///
  /// Safe to call from WorkManager background isolate because it does not
  /// use Flutter rendering APIs — only file I/O, SharedPreferences, and
  /// the [wallpaper_manager_flutter] plugin's method channel (which works
  /// from background via PluginRegistrant).
  ///
  /// Returns true if a wallpaper was set, false if no pre-generated files
  /// remain or any step fails.
  Future<bool> setNextPreGenerated(int screenWidth, int screenHeight) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final preGenDir = Directory(p.join(appDir.path, _preGenDirName));
      if (!await preGenDir.exists()) return false;

      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('pregen_count') ?? 0;
      if (count == 0) return false;

      var index = prefs.getInt('pregen_index') ?? 0;
      // Wrap around when all pre-generated wallpapers have been consumed
      // so the background scheduler never stops rotating.
      if (index >= count) index = 0;

      final filePath = p.join(preGenDir.path, 'pregen_$index.png');
      final file = File(filePath);
      if (!await file.exists()) return false;

      // This calls wallpaper_manager_flutter's plugin channel which is
      // registered for background isolates via PluginRegistrant.
      // _suggestDesiredDimensions will fail silently (channel not in
      // background) — that's fine, the wallpaper is already at the correct
      // resolution.
      final manager = WallpaperManagerFlutter();
      await manager.setWallpaper(file, WallpaperManagerFlutter.bothScreens);

      // Advance index for the next scheduled run
      await prefs.setInt('pregen_index', index + 1);

      // Persist the generation timestamp so WallpaperState (foreground) picks
      // it up on the next read and the "Next in ~X min" countdown stays honest.
      await prefs.setString(
        'last_wallpaper_timestamp',
        DateTime.now().toIso8601String(),
      );

      // Also persist the wallpaper path so the home card shows the current
      // image — otherwise the card stays frozen on the last manual generation.
      await prefs.setString('last_wallpaper_path', filePath);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('WallpaperGenerator: setNextPreGenerated failed: $e');
      return false;
    }
  }
}

// ── Background isolate: PNG encode from raw RGBA bytes ──

/// Encodes raw RGBA bytes into a PNG image in a background isolate.
///
/// Receives raw RGBA data (from [ui.ImageByteFormat.rawRgba]), width, and
/// height. Writes a valid PNG with IHDR/IDAT/IEND chunks using zlib
/// compression. Runs via [compute] so the UI thread is not blocked.
@pragma('vm:entry-point')
Uint8List _encodePngWorker((Uint8List, int, int) params) {
  final (rawRgba, width, height) = params;
  final bytes = <int>[];

  void writeBe32(int v) {
    bytes.addAll([
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ]);
  }

  void writeChunk(String type, List<int> data) {
    writeBe32(data.length);
    bytes.addAll(type.codeUnits);
    bytes.addAll(data);
    writeBe32(_crc32([...type.codeUnits, ...data]));
  }

  // PNG signature
  bytes.addAll([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk: width, height, 8-bit RGBA
  final ihdr = Uint8List(13);
  _be32(ihdr, 0, width);
  _be32(ihdr, 4, height);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace
  writeChunk('IHDR', ihdr);

  // Build filtered scanlines (filter None = 0x00 per row)
  final stride = width * 4;
  final scanlines = Uint8List(height * (1 + stride));
  for (int y = 0; y < height; y++) {
    final offset = y * (1 + stride);
    scanlines[offset] = 0; // filter byte: None
    scanlines.setRange(
      offset + 1,
      offset + 1 + stride,
      rawRgba.sublist(y * stride, (y + 1) * stride),
    );
  }

  // IDAT chunk: zlib-compressed scanlines
  final zlib = ZLibCodec(level: 6);
  writeChunk('IDAT', zlib.encoder.convert(scanlines));

  // IEND chunk
  writeChunk('IEND', []);

  return Uint8List.fromList(bytes);
}

/// Writes a 32-bit big-endian integer into [target] at [offset].
void _be32(Uint8List target, int offset, int value) {
  target[offset] = (value >> 24) & 0xFF;
  target[offset + 1] = (value >> 16) & 0xFF;
  target[offset + 2] = (value >> 8) & 0xFF;
  target[offset + 3] = value & 0xFF;
}

/// CRC-32 checksum used by PNG chunk validation.
int _crc32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if (crc & 1 != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
