import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageCacheService {
  static const String _assetPrefix = 'assets/images/nature';
  static const int _totalImages = 10;
  static const String _cacheDirName = 'nature_cache';

  static final ImageCacheService instance = ImageCacheService._internal();
  ImageCacheService._internal();

  String? _cachePath;
  bool _initialized = false;
  final Random _random = Random();

  bool get isInitialized => _initialized;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cachePath = p.join(appDir.path, _cacheDirName);

    final dir = Directory(_cachePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await ensureImageStock();
    _initialized = true;
  }

  /// Returns the file path of a random cached image, or null if none available.
  Future<String?> getNextRandomImage() async {
    if (_cachePath == null) return null;

    final dir = Directory(_cachePath!);
    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();

    if (files.isEmpty) return null;
    return files[_random.nextInt(files.length)].path;
  }

  /// Ensures exactly [_totalImages] valid JPG images exist in cache.
  /// Re-copies any file that is missing, corrupt, or not a real JPG.
  Future<void> ensureImageStock() async {
    if (_cachePath == null) return;

    await _repairCache();

    // Now copy any missing files from assets
    for (int i = 1; i <= _totalImages; i++) {
      final fileName = 'nature_${i.toString().padLeft(2, '0')}.jpg';
      final destPath = p.join(_cachePath!, fileName);

      final destFile = File(destPath);
      if (await destFile.exists()) continue;

      try {
        final assetPath = '$_assetPrefix/$fileName';
        final byteData = await rootBundle.load(assetPath);
        await destFile.writeAsBytes(byteData.buffer.asUint8List());
      } catch (e) {
        // ignore: avoid_print
        print('Warning: could not load $fileName: $e');
      }
    }
  }

  /// Removes cached files that are not valid JPGs (wrong signature).
  Future<void> _repairCache() async {
    if (_cachePath == null) return;
    final dir = Directory(_cachePath!);
    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final isValidJpg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      if (!isValidJpg) {
        // ignore: avoid_print
        print('Removing corrupt cache file: ${file.path}');
        await file.delete();
      }
    }
  }

  /// Returns the total number of images in the cache directory.
  Future<int> getCachedCount() async {
    if (_cachePath == null) return 0;
    final dir = Directory(_cachePath!);
    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();
    return files.length;
  }
}
