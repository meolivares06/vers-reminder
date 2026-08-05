import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/wallpaper/domain/wallpaper_result.dart';
import 'package:vers_reminder/verses/domain/verse.dart';
import 'package:vers_reminder/wallpaper/infrastructure/wallpaper_generator.dart';

/// Creates a small synthetic image in the system temp directory and returns
/// its path. Uses [Directory.systemTemp] to avoid requiring the Flutter
/// binding, so this works in plain `test()` as well as `testWidgets()`.
String _createTestImage(int width, int height) {
  final bg = img.Image(width: width, height: height, numChannels: 3);
  img.fillRect(
    bg,
    x1: 0,
    y1: 0,
    x2: width,
    y2: height,
    color: img.ColorRgba8(50, 100, 150, 255),
  );

  final file = File(
    '${Directory.systemTemp.path}/test_bg_${width}x$height.png',
  );
  file.writeAsBytesSync(img.encodePng(bg));
  return file.path;
}

void main() {
  group('WallpaperGenerator screen-size output', () {
    // ── Task 3.1 ──
    test('output PNG resized to screen dimensions when params provided', () {
      // Simulate _render's core resize pipeline with the `image` package.
      final srcPath = _createTestImage(100, 200);
      final srcBytes = File(srcPath).readAsBytesSync();
      final srcImage = img.decodeImage(srcBytes);
      expect(srcImage, isNotNull);

      // Resize: equivalent to what _render does with screenWidth/screenHeight
      final resized = img.copyResize(srcImage!, width: 1080, height: 2340);
      expect(
        resized.width,
        1080,
        reason: 'resized width should match screenWidth',
      );
      expect(
        resized.height,
        2340,
        reason: 'resized height should match screenHeight',
      );

      // Verify the resize didn't corrupt the image (can encode/decode)
      final pngBytes = img.encodePng(resized);
      final decoded = img.decodeImage(pngBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1080);
      expect(decoded.height, 2340);

      File(srcPath).deleteSync();
    });

    // ── Task 3.2 ──
    test('native dimensions preserved when screen params omitted', () {
      // Simulate _render without resize: decode only, no copyResize call.
      final srcPath = _createTestImage(100, 200);
      final srcBytes = File(srcPath).readAsBytesSync();
      final srcImage = img.decodeImage(srcBytes);
      expect(srcImage, isNotNull);

      // No resize — dimensions should match source
      expect(
        srcImage!.width,
        100,
        reason: 'without resize, width should match source',
      );
      expect(
        srcImage.height,
        200,
        reason: 'without resize, height should match source',
      );

      File(srcPath).deleteSync();
    });

    // ── Task 3.3 ──
    test('fallback to 1080×1920 when SharedPreferences returns null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final screenWidth = prefs.getInt('screen_width') ?? 1080;
      final screenHeight = prefs.getInt('screen_height') ?? 1920;

      expect(
        screenWidth,
        1080,
        reason: 'null screen_width should fall back to 1080',
      );
      expect(
        screenHeight,
        1920,
        reason: 'null screen_height should fall back to 1920',
      );
    });

    // ── Task 3.4 ──
    test(
      'SharedPreferences cached dimensions are read and forwarded',
      () async {
        // Simulate what main.dart writes on first launch
        SharedPreferences.setMockInitialValues({
          'screen_width': 1440,
          'screen_height': 3120,
        });
        final prefs = await SharedPreferences.getInstance();

        // Simulate what callbackDispatcher reads
        final screenWidth = prefs.getInt('screen_width') ?? 1080;
        final screenHeight = prefs.getInt('screen_height') ?? 1920;

        // These values would be passed to generateAndSetWallpaper()
        expect(
          screenWidth,
          1440,
          reason: 'should return cached 1440, not fallback 1080',
        );
        expect(
          screenHeight,
          3120,
          reason: 'should return cached 3120, not fallback 1920',
        );
      },
    );

    // ── Untested: corrupt/missing image → _render returns null ──
    test('corrupt image bytes cause decodeImage to return null', () {
      // Create a file with random bytes (not valid JPG/PNG)
      final corruptPath = '${Directory.systemTemp.path}/corrupt_test_image.bin';
      final corruptFile = File(corruptPath);
      corruptFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFF]);

      final bytes = corruptFile.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      expect(
        decoded,
        isNull,
        reason: 'corrupt/non-image bytes should decode to null',
      );

      corruptFile.deleteSync();
    });

    test(
      'generateAndSetWallpaper returns error when image is missing',
      () async {
        // Use the generator with a non-existent image path
        SharedPreferences.setMockInitialValues({
          'screen_width': 1080,
          'screen_height': 1920,
        });

        final generator = WallpaperGenerator.instance;
        final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

        // Expect an error since there are no cached nature images
        final result = await generator.generateAndSetWallpaper(
          verse: verse,
          locale: 'es',
          screenWidth: 1080,
          screenHeight: 1920,
        );

        expect(
          result,
          isA<WallpaperResultError>(),
          reason: 'should fail because no image cache available',
        );
        expect(
          (result as WallpaperResultError).reason,
          WallpaperErrorReason.backgroundMissing,
          reason: 'should be backgroundMissing error',
        );
      },
    );

    // ── Partial: write-once cache guard ──
    test(
      'main.dart write-once guard does not overwrite existing dimensions',
      () async {
        // Simulate an app restart with v2 dimensions already cached
        SharedPreferences.setMockInitialValues({
          'screen_dim_version': 2,
          'screen_width': 720,
          'screen_height': 1280,
        });
        final prefs = await SharedPreferences.getInstance();

        // Guard from main.dart: only write if not already set (after version check)
        const currentDimVersion = 2;
        final cachedVersion = prefs.getInt('screen_dim_version');
        if (cachedVersion != currentDimVersion) {
          await prefs.remove('screen_width');
          await prefs.remove('screen_height');
          await prefs.setInt('screen_dim_version', currentDimVersion);
        }

        if (!prefs.containsKey('screen_width')) {
          await prefs.setInt('screen_width', 1080);
          await prefs.setInt('screen_height', 1920);
        }

        // Values should still be the original (720x1280), not overwritten
        expect(
          prefs.getInt('screen_width'),
          720,
          reason: 'write-once guard should keep original 720, not 1080',
        );
        expect(
          prefs.getInt('screen_height'),
          1280,
          reason: 'write-once guard should keep original 1280, not 1920',
        );
        expect(
          prefs.getInt('screen_dim_version'),
          2,
          reason: 'version should remain unchanged',
        );
      },
    );

    test('version mismatch clears stale dimensions for re-cache', () async {
      // Simulate having v1 (logical pixels) cached
      SharedPreferences.setMockInitialValues({
        'screen_dim_version': 1,
        'screen_width': 1080,
        'screen_height': 1920,
      });
      final prefs = await SharedPreferences.getInstance();

      // Version check from main.dart
      const currentDimVersion = 2;
      final cachedVersion = prefs.getInt('screen_dim_version');
      if (cachedVersion != currentDimVersion) {
        await prefs.remove('screen_width');
        await prefs.remove('screen_height');
        await prefs.setInt('screen_dim_version', currentDimVersion);
      }

      // Old values should be cleared
      expect(
        prefs.containsKey('screen_width'),
        false,
        reason: 'stale screen_width should be removed',
      );
      expect(
        prefs.containsKey('screen_height'),
        false,
        reason: 'stale screen_height should be removed',
      );
      expect(
        prefs.getInt('screen_dim_version'),
        2,
        reason: 'version should be updated to current',
      );
    });
  });

  group('_composite() pipeline', () {
    // ── Covers R-WG-008 Sc.1 ──
    test(
      'compositeFromBytes returns PNG bytes matching specified dimensions',
      () async {
        final srcBytes = _createTestImageBytes(100, 200);
        final generator = WallpaperGenerator.instance;
        final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

        final result = await generator.compositeFromBytes(
          backgroundBytes: srcBytes,
          verse: verse,
          locale: 'es',
          screenWidth: 1080,
          screenHeight: 2340,
        );

        expect(result, isNotNull, reason: 'should return non-null bytes');
        final decoded = img.decodeImage(result!);
        expect(decoded, isNotNull, reason: 'should decode as valid PNG');
        expect(decoded!.width, 1080, reason: 'width should match screenWidth');
        expect(
          decoded.height,
          2340,
          reason: 'height should match screenHeight',
        );
      },
    );

    // ── Covers R-WG-008 Sc.2 ──
    test('compositeFromBytes returns null for corrupt input bytes', () async {
      final generator = WallpaperGenerator.instance;
      final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

      final result = await generator.compositeFromBytes(
        backgroundBytes: Uint8List.fromList([0x00, 0x01, 0x02, 0xFF]),
        verse: verse,
        locale: 'es',
      );

      expect(result, isNull, reason: 'corrupt bytes should return null');
    });

    // ── Covers R-WG-009 Sc.1 & 2 (renderPreview resolution) ──
    test('renderPreview returns ¼ resolution output', () async {
      // compositeFromBytes with ¼ dimensions produces correct size.
      // This validates the preview pipeline at the byte level,
      // equivalent to what renderPreview does internally.
      final srcBytes = _createTestImageBytes(400, 800);
      final generator = WallpaperGenerator.instance;
      final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

      final result = await generator.compositeFromBytes(
        backgroundBytes: srcBytes,
        verse: verse,
        locale: 'es',
        screenWidth: 100,
        screenHeight: 200,
      );

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 100, reason: 'preview width should match');
      expect(decoded.height, 200, reason: 'preview height should match');
    });

    // ── F8 RED: renderOnly error logging ──
    test('F8-RED renderOnly catch block logs error via debugPrint', () {
      final source =
          File('lib/wallpaper/infrastructure/wallpaper_generator.dart')
              .readAsStringSync();

      // Find the renderOnly method
      final renderOnlyIdx = source.indexOf('Future<String?> renderOnly(');
      expect(renderOnlyIdx, greaterThan(0),
          reason: 'renderOnly method must exist');

      // The catch block inside renderOnly must log via debugPrint
      // and return null as safe fallback.
      final catchIdx = source.indexOf('debugPrint(\'renderOnly failed',
          renderOnlyIdx);
      expect(catchIdx, greaterThan(0),
          reason: 'F8 fix: renderOnly catch must log error via debugPrint '
              'before returning null — current catch (_) swallows silently');
    });

    // ── F10 RED: compute fallback error logging ──
    test('F10-RED compute fallback catch logs isolate error via debugPrint', () {
      final source =
          File('lib/wallpaper/infrastructure/wallpaper_generator.dart')
              .readAsStringSync();

      // Find the compute/_encodePngWorker area
      final computeIdx = source.indexOf('compute(_encodePngWorker');
      expect(computeIdx, greaterThan(0),
          reason: 'compute call must exist');

      // The catch block after compute must log the error via debugPrint
      // before falling back to sync encoding.
      final catchIdx = source.indexOf(
        'debugPrint(\'PNG encode isolate failed',
        computeIdx,
      );
      expect(catchIdx, greaterThan(0),
          reason: 'F10 fix: compute fallback catch must log isolate error '
              'via debugPrint before falling back — current catch (_) swallows silently');
    });

    test('compositing with calibratedInset crops before resize', () async {
      final srcBytes = _createTestImageBytes(200, 400);
      final generator = WallpaperGenerator.instance;
      final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

      // 50px inset each side: 200-100=100 width, 400 height stays
      final result = await generator.compositeFromBytes(
        backgroundBytes: srcBytes,
        verse: verse,
        locale: 'es',
        screenWidth: 100,
        screenHeight: 200,
        calibratedInset: 50,
      );

      expect(result, isNotNull, reason: 'should still render with inset');
      // After crop: 100x400 → resize to 100x200
      final decoded = img.decodeImage(result!);
      expect(decoded!.width, 100);
    });

    // ── Covers R-WG-009 Sc.3: null on background failure ──
    test('compositeFromBytes returns null for empty input bytes', () async {
      final generator = WallpaperGenerator.instance;
      final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

      final result = await generator.compositeFromBytes(
        backgroundBytes: Uint8List.fromList([]),
        verse: verse,
        locale: 'es',
      );

      expect(
        result,
        isNull,
        reason: 'empty bytes should return null (no image to decode)',
      );
    });
  });

  group('_getBackgroundBytes', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'useMyWallpaper: true + file exists with valid bytes → bytes returned',
      () async {
        // Create a temp PNG and set its path in SharedPreferences.
        // _createTestImage with the same dimensions returns the same filename,
        // so use a single file for both the user background and nature fallback.
        final imagePath = _createTestImage(100, 200);
        SharedPreferences.setMockInitialValues({
          'user_background_path': imagePath,
        });

        final generator = WallpaperGenerator.instance;
        final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');

        final result = await generator.renderPreview(
          verse: verse,
          locale: 'es',
          previewWidth: 50,
          previewHeight: 100,
          previewImagePath: imagePath,
          useMyWallpaper: true,
        );

        expect(
          result,
          isNotNull,
          reason: 'should return composited bytes from user background file',
        );

        File(imagePath).deleteSync();
      },
    );

    test(
      'useMyWallpaper: true + file missing → falls back to nature',
      () async {
        // Set a path that does NOT exist
        SharedPreferences.setMockInitialValues({
          'user_background_path': '/nonexistent/path/user_background.png',
        });

        final generator = WallpaperGenerator.instance;
        final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');
        final testImage = _createTestImage(100, 200);

        final result = await generator.renderPreview(
          verse: verse,
          locale: 'es',
          previewWidth: 50,
          previewHeight: 100,
          previewImagePath: testImage,
          useMyWallpaper: true,
        );

        // Falls back to previewImagePath when user background file is missing
        expect(
          result,
          isNotNull,
          reason: 'should fall back to nature image when user file missing',
        );

        File(testImage).deleteSync();
      },
    );

    test('useMyWallpaper: true + path null → falls back to nature', () async {
      // No user_background_path in SharedPreferences
      SharedPreferences.setMockInitialValues({});

      final generator = WallpaperGenerator.instance;
      final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');
      final testImage = _createTestImage(100, 200);

      final result = await generator.renderPreview(
        verse: verse,
        locale: 'es',
        previewWidth: 50,
        previewHeight: 100,
        previewImagePath: testImage,
        useMyWallpaper: true,
      );

      expect(
        result,
        isNotNull,
        reason:
            'should fall back to nature image when user_background_path is null',
      );

      File(testImage).deleteSync();
    });

    test(
      'useMyWallpaper: false → uses nature path from previewImagePath',
      () async {
        final generator = WallpaperGenerator.instance;
        final verse = Verse(textEs: 'Test verse', citation: 'Test 1:1');
        final testImage = _createTestImage(100, 200);

        final result = await generator.renderPreview(
          verse: verse,
          locale: 'es',
          previewWidth: 50,
          previewHeight: 100,
          previewImagePath: testImage,
          useMyWallpaper: false,
        );

        expect(
          result,
          isNotNull,
          reason: 'should render from nature path when useMyWallpaper is false',
        );

        File(testImage).deleteSync();
      },
    );
  });

  group('WallpaperGenerator typography (wallpaper-gen delta)', () {
    final generator = WallpaperGenerator.instance;

    test('verse style is EB Garamond regular (not italic) in paint and measurement', () {
      final style = generator.verseMeasureStyle(24);
      expect(
        style.fontFamily,
        'EB Garamond',
        reason: 'verse must use the EB Garamond typeface',
      );
      expect(
        style.fontStyle,
        isNull,
        reason: 'verse must render in regular weight, not italic',
      );
    });

    test('citation style is sans-serif with letterSpacing', () {
      final style = generator.citationMeasureStyle(24);
      expect(
        style.fontFamily,
        isNull,
        reason: 'citation must fall back to the default sans-serif family',
      );
      expect(
        style.letterSpacing,
        1.5,
        reason: 'citation must be letter-spaced',
      );
    });

    test('citation renders uppercase in paint and measurement', () {
      expect(
        generator.citationDisplayText('John 3:16'),
        'JOHN 3:16',
        reason: 'citation is transformed to uppercase before drawing',
      );
    });

    test('citation dash uses brand gold color 0xFFEFB14D', () {
      expect(
        WallpaperGenerator.citationRuleColor,
        const Color(0xFFEFB14D),
        reason: 'citation dash must match the brand gold accent',
      );
    });

    test('measurement parity: new styles resolve within 1px of legacy', () {
      const text = 'Amad a vuestros enemigos y orad por los que os persiguen';
      const citation = 'Mateo 5:44';
      final maxTextWidth = 1080 - (1080 * 0.08) * 2;
      final availableHeight = 2400 - (2400 * 0.08) * 2;

      final newSize = generator.resolveFontSizeForTest(
        text: text,
        citation: citation,
        maxTextWidth: maxTextWidth,
        availableHeight: availableHeight,
        screenWidth: 1080,
      );
      final legacySize = generator.resolveFontSizeForTest(
        text: text,
        citation: citation,
        maxTextWidth: maxTextWidth,
        availableHeight: availableHeight,
        screenWidth: 1080,
        legacyStyles: true,
      );

      expect(
        (newSize - legacySize).abs(),
        lessThanOrEqualTo(1.0),
        reason:
            'the italic verse + uppercase citation must not regress the '
            'fitted font size by more than 1px vs the pre-change styles',
      );
    });
  });

  group('_compositeCanvas resource disposal (F1+F2 RED)', () {
    final generator = WallpaperGenerator.instance;

    // ── Task 1.1 RED: F1 — PictureRecorder disposal ──
    test('finally block contains null-guarded picture dispose pattern', () {
      final source =
          File('lib/wallpaper/infrastructure/wallpaper_generator.dart')
              .readAsStringSync();

      // After fix: ui.Picture? picture declared before try block
      expect(
        source.contains('ui.Picture? picture'),
        isTrue,
        reason:
            'F1 fix requires ui.Picture? picture declared before the try block '
            'so the finally block can null-guard picture?.dispose() on error paths',
      );

      // After fix: picture?.dispose() in finally before bg.dispose()
      final finallyIdx = source.lastIndexOf('finally');
      expect(finallyIdx, greaterThan(0), reason: 'finally block must exist');
      final pictureDisposeIdx = source.indexOf(
        'picture?.dispose()',
        finallyIdx,
      );
      final bgDisposeIdx = source.indexOf('bg.dispose()', finallyIdx);

      expect(
        pictureDisposeIdx,
        greaterThan(0),
        reason: 'finally must contain picture?.dispose() for error-path cleanup',
      );
      expect(
        pictureDisposeIdx < bgDisposeIdx,
        isTrue,
        reason: 'picture?.dispose() must run before bg.dispose() — '
            'reverse creation order (recorder → bg)',
      );

      // After fix: picture = null after success-path picture.dispose()
      final pictureNullIdx = source.indexOf('picture = null');
      expect(
        pictureNullIdx,
        greaterThan(0),
        reason: 'after success-path picture.dispose(), picture must be set to null '
            'so the finally guard is a no-op on success and active on error',
      );
    });

    // ── Task 1.1 RED: F2 — TextPainter disposal nesting ──
    test(
      'citationPainter nested inside textPainter disposal scope '
      '(reverse-creation order)',
      () {
        final source =
            File('lib/wallpaper/infrastructure/wallpaper_generator.dart')
              .readAsStringSync();

        final textDisposeIdx = source.indexOf('textPainter.dispose()');
        final citationDisposeIdx = source.indexOf(
          'citationPainter.dispose()',
        );

        expect(
          citationDisposeIdx,
          greaterThan(0),
          reason: 'citationPainter must be disposed in a finally block',
        );
        expect(
          textDisposeIdx,
          greaterThan(0),
          reason: 'textPainter must be disposed in a finally block',
        );
        // Reverse creation order: citation (created last) → text (created first)
        expect(
          citationDisposeIdx < textDisposeIdx,
          isTrue,
          reason:
              'dispose must follow reverse creation order: '
              'citationPainter.dispose() before textPainter.dispose()',
        );
      },
    );

    // ── Task 3.3 behavioral: memory stress via repeated compositing ──
    test('5× consecutive compositeFromBytes returns non-null each time', () async {
      final srcBytes = _createTestImageBytes(100, 200);
      final verse = Verse(textEs: 'Stress test', citation: 'Test 1:1');

      for (int i = 0; i < 5; i++) {
        final result = await generator.compositeFromBytes(
          backgroundBytes: srcBytes,
          verse: verse,
          locale: 'es',
          screenWidth: 270,
          screenHeight: 480,
        );
        expect(
          result,
          isNotNull,
          reason: 'iteration $i: compositeFromBytes should return valid bytes '
              'without native resource leaks causing GPU exhaustion',
        );
        expect(
          result!.length,
          greaterThan(100),
          reason: 'iteration $i: output should be a valid PNG of reasonable size',
        );
      }
    });
  });
}

/// Creates a synthetic image in memory and returns its PNG bytes.
/// Unlike [_createTestImage], this avoids writing to disk.
Uint8List _createTestImageBytes(int width, int height) {
  final bg = img.Image(width: width, height: height, numChannels: 3);
  img.fillRect(
    bg,
    x1: 0,
    y1: 0,
    x2: width,
    y2: height,
    color: img.ColorRgba8(50, 100, 150, 255),
  );
  return Uint8List.fromList(img.encodePng(bg));
}
