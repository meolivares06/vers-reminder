import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_service.dart';
import '../models/wallpaper_result.dart';
import '../models/wallpaper_status.dart';
import '../services/wallpaper_backup_service.dart';
import '../services/wallpaper_generator.dart';
import '../services/wallpaper_scheduler.dart';
import '../services/notification_service.dart';
import 'verse_provider.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({this.wallpaperGenerator});

  final DatabaseService _db = DatabaseService.instance;

  /// Test seam — the wallpaper generation service. Defaults to
  /// [WallpaperGenerator.instance] when null.
  @visibleForTesting
  final WallpaperGenerator? wallpaperGenerator;

  late final WallpaperGenerator _generator =
      wallpaperGenerator ?? WallpaperGenerator.instance;

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
  DateTime? _lastWallpaperTimestamp;
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
  DateTime? get lastWallpaperTimestamp => _lastWallpaperTimestamp;
  bool get hasBackup => _hasBackup;
  bool get useMyWallpaper => _useMyWallpaper;
  String? get userBackgroundPath => _userBackgroundPath;

  String get _frequencyText {
    if (_frequencyMinutes % 60 == 0) {
      return 'Every ${_frequencyMinutes ~/ 60} h';
    }
    return 'Every $_frequencyMinutes min';
  }

  /// Exposed for widget tests only — lets Home render a deterministic
  /// active-categories count without a real database.
  @visibleForTesting
  void setActiveCategoriesForTest(Set<int> ids) {
    _activeCategoryIds = ids;
    notifyListeners();
  }

  /// Exposed for widget tests only — allows setting the wallpaper-card state
  /// without calling [init], which requires a real database.
  @visibleForTesting
  void setWallpaperCard({
    String? path,
    DateTime? timestamp,
    bool permissionGranted = false,
  }) {
    _lastWallpaperPath = path;
    _lastWallpaperTimestamp = timestamp;
    _wallpaperPermissionGranted = permissionGranted;
    notifyListeners();
  }

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
    _lastWallpaperTimestamp = _parseTimestamp(
      prefs.getString('last_wallpaper_timestamp'),
    );
    _hasBackup = prefs.getBool(WallpaperBackupService.backupFlagKey) ?? false;
    _useMyWallpaper = prefs.getBool('use_my_wallpaper') ?? false;
    _userBackgroundPath = prefs.getString('user_background_path');

    // Re-register WorkManager task if enabled (survives reboot)
    if (_isEnabled && _activeCategoryIds.isNotEmpty) {
      await WallpaperScheduler.registerPeriodic(_frequencyMinutes);
      await NotificationService.show(_frequencyText);

      // F3: dismiss loading BEFORE fire-and-forget pre-gen so the app
      // becomes interactive immediately; pre-gen failures are logged.
      _isLoading = false;
      notifyListeners();

      unawaited(
        _preGenerateFutureWallpapers(locale: 'es').catchError((e, st) {
          debugPrint('SettingsProvider: pre-gen failed: $e\n$st');
        }),
      );
    } else {
      _isLoading = false;
      notifyListeners();
    }
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
    await _db.updateAppConfig({'scheduler_enabled': enabled ? 1 : 0});
    notifyListeners();

    if (enabled && _activeCategoryIds.isNotEmpty) {
      await WallpaperScheduler.registerPeriodic(_frequencyMinutes);
      await NotificationService.show(_frequencyText);
      // F3: fire-and-forget pre-gen for background scheduler (non-blocking)
      final prefs = await SharedPreferences.getInstance();
      final locale = prefs.getString('locale_override') ?? 'es';
      unawaited(
        _preGenerateFutureWallpapers(locale: locale).catchError((e, st) {
          debugPrint('SettingsProvider: pre-gen failed: $e\n$st');
        }),
      );
    } else {
      await WallpaperScheduler.cancel();
      await NotificationService.cancel();
    }
  }

  Future<void> setFrequency(int minutes) async {
    _frequencyMinutes = minutes;
    await _db.updateAppConfig({'frequency_minutes': minutes});
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
    final result = await _generator.generateAndSetWallpaper(
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
        await NotificationService.show(citation ?? _frequencyText);
        _lastWallpaperPath = wallpaperPath;
        _lastWallpaperTimestamp = DateTime.now();
        // Persistence is best-effort: the in-memory wallpaper state is already
        // correct, so a failed write must never break the generation flow.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_wallpaper_path', wallpaperPath);
          // Write-only new key: old installs lack it and stay null until the
          // next foreground generation (backwards-compatible with
          // last_wallpaper_path, which still governs the empty/exists state).
          await prefs.setString(
            'last_wallpaper_timestamp',
            _lastWallpaperTimestamp!.toIso8601String(),
          );
        } catch (e) {
          debugPrint('Failed to persist last wallpaper metadata: $e');
        }
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

  /// Parses a persisted ISO8601 [String] into a [DateTime], returning `null`
  /// when the key is absent or malformed (old installs / corrupt values).
  static DateTime? _parseTimestamp(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
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

    await _generator.preGenerateWallpapers(
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
