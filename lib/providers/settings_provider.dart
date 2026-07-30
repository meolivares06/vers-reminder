import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_service.dart';
import '../models/wallpaper_result.dart';
import '../models/wallpaper_status.dart';
import '../services/wallpaper_backup_service.dart';
import '../services/wallpaper_generator.dart';
import '../services/wallpaper_scheduler.dart';
import 'verse_provider.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  bool _isEnabled = false;
  int _frequencyMinutes = 360;
  Set<int> _activeCategoryIds = {};
  bool _isLoading = false;
  WallpaperStatus _status = WallpaperStatus.idle;
  String? _statusPayload;
  bool _wallpaperPermissionGranted = false;
  int _horizontalOffset = 0;
  String _verticalAlignment = 'center';
  int _calibratedInset = 0;
  double _fontScale = 1.0;
  String? _lastWallpaperPath;
  bool _hasBackup = false;
  bool _useMyWallpaper = false;
  String? _userBackgroundPath;

  bool get isEnabled => _isEnabled;
  int get frequencyMinutes => _frequencyMinutes;
  Set<int> get activeCategoryIds => _activeCategoryIds;
  bool get isLoading => _isLoading;
  WallpaperStatus get status => _status;
  String? get statusPayload => _statusPayload;
  bool get wallpaperPermissionGranted => _wallpaperPermissionGranted;
  int get horizontalOffset => _horizontalOffset;
  String get verticalAlignment => _verticalAlignment;
  int get calibratedInset => _calibratedInset;
  double get fontScale => _fontScale;
  String? get lastWallpaperPath => _lastWallpaperPath;
  bool get hasBackup => _hasBackup;
  bool get useMyWallpaper => _useMyWallpaper;
  String? get userBackgroundPath => _userBackgroundPath;

  /// Exposed for widget tests only — allows setting backup state without
  /// calling [init], which requires a real database.
  @visibleForTesting
  void setHasBackup(bool value) {
    _hasBackup = value;
    notifyListeners();
  }

  Future<void> setUseMyWallpaper(bool value) async {
    _useMyWallpaper = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_my_wallpaper', value);
    notifyListeners();
  }

  Future<void> setUserBackgroundPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('user_background_path', path);
    } else {
      await prefs.remove('user_background_path');
    }
    _userBackgroundPath = path;
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final config = await _db.getAppConfig();
    _isEnabled = config['scheduler_enabled'] == 1;
    _frequencyMinutes = config['frequency_minutes'] as int? ?? 360;
    final idsStr = config['active_category_ids'] as String? ?? '[]';
    _activeCategoryIds = (json.decode(idsStr) as List).cast<int>().toSet();
    _wallpaperPermissionGranted =
        (config['wallpaper_permission_granted'] as int?) == 1;

    // Load wallpaper layout preferences from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _horizontalOffset = prefs.getInt('horizontal_offset') ?? 0;
    _verticalAlignment = prefs.getString('vertical_alignment') ?? 'center';
    _calibratedInset = prefs.getInt('calibrated_inset') ?? 0;
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
    _lastWallpaperPath = prefs.getString('last_wallpaper_path');
    _hasBackup = prefs.getBool(WallpaperBackupService.backupFlagKey) ?? false;
    _useMyWallpaper = prefs.getBool('use_my_wallpaper') ?? false;
    _userBackgroundPath = prefs.getString('user_background_path');

    // Re-register WorkManager task if enabled (survives reboot)
    if (_isEnabled && _activeCategoryIds.isNotEmpty) {
      await WallpaperScheduler.registerPeriodic(_frequencyMinutes);
      // Pre-generate wallpapers for background scheduler to use
      await _preGenerateFutureWallpapers(locale: 'es');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setHorizontalOffset(int value) async {
    _horizontalOffset = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('horizontal_offset', value);
    notifyListeners();
  }

  Future<void> setVerticalAlignment(String value) async {
    _verticalAlignment = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vertical_alignment', value);
    notifyListeners();
  }

  Future<void> setCalibratedInset(int value) async {
    _calibratedInset = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calibrated_inset', value);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', value);
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _db.updateAppConfig({
      'scheduler_enabled': enabled ? 1 : 0,
    });
    notifyListeners();

    if (enabled && _activeCategoryIds.isNotEmpty) {
      await WallpaperScheduler.registerPeriodic(_frequencyMinutes);
      // Pre-generate wallpapers for the background scheduler
      final prefs = await SharedPreferences.getInstance();
      final locale = prefs.getString('locale_override') ?? 'es';
      await _preGenerateFutureWallpapers(locale: locale);
    } else {
      await WallpaperScheduler.cancel();
    }
  }

  Future<void> setFrequency(int minutes) async {
    _frequencyMinutes = minutes;
    await _db.updateAppConfig({
      'frequency_minutes': minutes,
    });
    notifyListeners();

    if (_isEnabled && _activeCategoryIds.isNotEmpty) {
      await WallpaperScheduler.cancel();
      await WallpaperScheduler.registerPeriodic(minutes);
    }
  }

  Future<void> toggleCategory(int categoryId) async {
    if (_activeCategoryIds.contains(categoryId)) {
      _activeCategoryIds.remove(categoryId);
    } else {
      _activeCategoryIds.add(categoryId);
    }

    await _db.updateAppConfig({
      'active_category_ids': json.encode(_activeCategoryIds.toList()),
    });
    notifyListeners();

    if (_activeCategoryIds.isEmpty && _isEnabled) {
      await WallpaperScheduler.cancel();
    } else if (_isEnabled && _activeCategoryIds.length == 1) {
      // Re-register after having none
      await WallpaperScheduler.registerPeriodic(_frequencyMinutes);
    }
  }

  Future<void> grantWallpaperPermission() async {
    _wallpaperPermissionGranted = true;
    await _db.updateAppConfig({'wallpaper_permission_granted': 1});
    notifyListeners();
  }

  Future<void> triggerNow({
    required VerseProvider verseProvider,
    required String locale,
  }) async {
    if (_activeCategoryIds.isEmpty) {
      _status = WallpaperStatus.noCategories;
      _statusPayload = null;
      notifyListeners();
      return;
    }

    _status = WallpaperStatus.generating;
    _statusPayload = null;
    notifyListeners();

    final verses = await _db.getVersesByCategoryIds(
      _activeCategoryIds.toList(),
      locale,
    );

    if (verses.isEmpty) {
      _status = WallpaperStatus.error;
      _statusPayload = 'No verses for locale';
      // ignore: avoid_print
      print('WallpaperGenerator: noVersesForLocale');
      notifyListeners();
      return;
    }

    // Auto-backup original wallpaper on first trigger
    if (!_hasBackup) {
      final saved = await WallpaperBackupService.instance.backupCurrent();
      if (saved) {
        _hasBackup = true;
        notifyListeners();
      }
    }

    final verse = verses[0];
    final result = await WallpaperGenerator.instance.generateAndSetWallpaper(
      verse: verse,
      locale: locale,
      horizontalOffset: _horizontalOffset,
      verticalAlignment: _verticalAlignment,
      fontScale: _fontScale,
      calibratedInset: _calibratedInset,
      useMyWallpaper: _useMyWallpaper,
    );

    switch (result) {
      case WallpaperResultSuccess(:final wallpaperPath, :final citation):
        _status = WallpaperStatus.updated;
        _statusPayload = citation;
        _lastWallpaperPath = wallpaperPath;
        SharedPreferences.getInstance().then(
            (prefs) => prefs.setString('last_wallpaper_path', wallpaperPath));
        // Pre-generate future wallpapers for the background scheduler
        // after a successful foreground generation.
        await _preGenerateFutureWallpapers(locale: locale);
      case WallpaperResultError(:final reason):
        _status = WallpaperStatus.error;
        _statusPayload = reason.name;
        // ignore: avoid_print
        print('WallpaperGenerator error: $reason');
    }
    notifyListeners();
  }

  /// Pre-generates wallpapers for the WorkManager background scheduler.
  ///
  /// Picks random verses from active categories and generates [_preGenCount]
  /// wallpapers that the background callback can set without needing Flutter
  /// rendering APIs. Called after [triggerNow] and on app init.
  Future<void> _preGenerateFutureWallpapers({required String locale}) async {
    if (_activeCategoryIds.isEmpty) return;

    final randomVerses = await _db.getRandomVerses(
      _activeCategoryIds.toList(),
      locale,
      WallpaperGenerator.preGenCount,
    );

    if (randomVerses.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final screenWidth = prefs.getInt('screen_width') ?? 1080;
    final screenHeight = prefs.getInt('screen_height') ?? 1920;

    await WallpaperGenerator.instance.preGenerateWallpapers(
      verses: randomVerses,
      locale: locale,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      horizontalOffset: _horizontalOffset,
      verticalAlignment: _verticalAlignment,
      fontScale: _fontScale,
      calibratedInset: _calibratedInset,
      useMyWallpaper: _useMyWallpaper,
    );
  }
}
