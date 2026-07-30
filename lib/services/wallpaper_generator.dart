import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

import '../models/verse.dart';
import '../models/wallpaper_result.dart';
import 'image_cache_service.dart';

/// Generates and optionally sets wallpapers composed of verse text
/// over a nature background with dark overlay.
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
  }) async {
    try {
      final imagePath = await ImageCacheService.instance.getNextRandomImage();
      if (imagePath == null) {
        return WallpaperResultError(WallpaperErrorReason.backgroundMissing);
      }

      final outputPath = await _render(
        backgroundPath: imagePath,
        verse: verse,
        locale: locale,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        horizontalOffset: horizontalOffset,
        verticalAlignment: verticalAlignment,
        fontScale: fontScale,
        calibratedInset: calibratedInset,
      );
      if (outputPath == null) {
        return WallpaperResultError(WallpaperErrorReason.renderFailed);
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          if (screenWidth != null && screenHeight != null) {
            await _suggestDesiredDimensions(screenWidth, screenHeight);
          }
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
  }) async {
    try {
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
      );
    } catch (_) {
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
        final actualInset =
            calibratedInset < maxInset ? calibratedInset.toDouble() : maxInset;
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
          style: TextStyle(
            color: Colors.white,
            fontSize: resolvedFontSize,
            fontWeight: FontWeight.w700,
            height: 1.4,
            shadows: [shadow],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 10,
        ellipsis: '...',
      )..layout(maxWidth: maxTextWidth);

      final citationPainter = TextPainter(
        text: TextSpan(
          text: citation,
          style: TextStyle(
            color: Colors.white70,
            fontSize: citationFontSize,
            fontWeight: FontWeight.w500,
            height: 1.4,
            shadows: [shadow],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);

      final totalTextHeight = textPainter.height + gap + citationPainter.height;

      // Vertical position (clamp to stay on screen)
      final startY = switch (verticalAlignment) {
        'top' => padding,
        'bottom' => (screenHeight - totalTextHeight - padding)
            .clamp(0.0, screenHeight.toDouble()),
        _ => ((screenHeight - totalTextHeight) / 2)
            .clamp(0.0, screenHeight.toDouble()),
      };

      // Horizontal position with user offset (clamp to screen edges)
      final startX = (padding + horizontalOffset).clamp(
        0.0,
        (screenWidth - textPainter.width - gap).clamp(0.0, screenWidth.toDouble()),
      );

      textPainter.paint(canvas, Offset(startX, startY));
      citationPainter.paint(
        canvas,
        Offset(startX, startY + textPainter.height + gap),
      );

      textPainter.dispose();
      citationPainter.dispose();

      // Yield before rasterization — PNG encode is CPU-heavy
      await Future<void>.delayed(Duration.zero);

      // --- 6. Rasterize to PNG ---
      final picture = recorder.endRecording();
      final result = await picture.toImage(screenWidth, screenHeight);
      picture.dispose();
      final byteData = await result.toByteData(format: ui.ImageByteFormat.png);
      result.dispose();
      return byteData?.buffer.asUint8List();
    } finally {
      bg.dispose();
    }
  }

  /// Runs the font-sizing loop: starts at [screenWidth] × [_baseFontRatio]
  /// × [fontScale] and shrinks by [_fontStep] until all text + citation fits
  /// within [availableHeight].
  double _resolveFontSize({
    required String text,
    required String citation,
    required double maxTextWidth,
    required double availableHeight,
    required int screenWidth,
    required double fontScale,
  }) {
    final baseSize = screenWidth * _baseFontRatio * fontScale;
    final minSize = screenWidth * _minFontRatio * fontScale;
    const gap = 16.0;

    for (var size = baseSize; size >= minSize; size -= _fontStep) {
      final citationSize = size * _citationFontSizeRatio;

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, height: 1.4),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);

      final cp = TextPainter(
        text: TextSpan(
          text: citation,
          style: TextStyle(fontSize: citationSize, height: 1.4),
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
  }) =>
      _compositeCanvas(
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
  }) async {
    final w = screenWidth ?? 1080;
    final h = screenHeight ?? 2400;

    // 1. Load background image bytes
    final file = File(backgroundPath);
    final bytes = await file.readAsBytes();

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
  }) async {
    try {
      final imagePath =
          previewImagePath ?? await ImageCacheService.instance.getNextRandomImage();
      if (imagePath == null) return null;

      final file = File(imagePath);
      final bytes = await file.readAsBytes();

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
  Future<void> _setWallpaper(String imagePath, int screenWidth,
      int screenHeight) async {
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
}
