import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/database_service.dart';
import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_result.dart';
import 'package:vers_reminder/wallpaper/domain/wallpaper_status.dart';
import 'package:vers_reminder/backup/wallpaper_backup_service.dart';
import 'package:vers_reminder/wallpaper/wallpaper_generator.dart';

/// Manages wallpaper generation state and triggers.
///
/// Holds the current wallpaper path, timestamp, status, permission state,
/// and backup flag. Orchestrates wallpaper generation via [triggerNow]
/// and pre-generation for the background scheduler.
///
/// Communication with other modules uses [EventBus]:
/// - Listens for [RefreshWallpaper] to trigger generation
/// - Emits [WallpaperGenerated], [SettingChanged], and [NotificationRequested]
class WallpaperState extends ChangeNotifier {
  WallpaperState({this.wallpaperGenerator}) {
    EventBus.instance.on<RefreshWallpaper>((event) async {
      await triggerNow(locale: event.locale);
    });
  }

  final DatabaseService _db = DatabaseService.instance;

  /// Test seam — the wallpaper generation service.
  @visibleForTesting
  final WallpaperGenerator? wallpaperGenerator;

  late final WallpaperGenerator _generator =
      wallpaperGenerator ?? WallpaperGenerator.instance;

  bool _isLoading = false;
  WallpaperStatus _status = WallpaperStatus.idle;
  String? _statusPayload;
  bool _wallpaperPermissionGranted = false;
  String? _lastWallpaperPath;
  DateTime? _lastWallpaperTimestamp;
  bool _hasBackup = false;
  bool _useMyWallpaper = false;
  String? _userBackgroundPath;
  int _horizontalOffset = 0;
  String _verticalAlignment = 'center';
  int _calibratedInset = 0;
  double _fontScale = 1.0;
  bool _isPreGenerating = false;

  bool get isLoading => _isLoading;
  WallpaperStatus get status => _status;
  String? get statusPayload => _statusPayload;
  bool get wallpaperPermissionGranted => _wallpaperPermissionGranted;
  String? get lastWallpaperPath => _lastWallpaperPath;
  DateTime? get lastWallpaperTimestamp => _lastWallpaperTimestamp;
  bool get hasBackup => _hasBackup;
  bool get useMyWallpaper => _useMyWallpaper;
  String? get userBackgroundPath => _userBackgroundPath;

  // ── Test seams ──

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

  @visibleForTesting
  void setHasBackup(bool value) {
    _hasBackup = value;
    notifyListeners();
  }

  @visibleForTesting
  void setStatusForTest(WallpaperStatus status, {String? payload}) {
    _status = status;
    _statusPayload = payload;
  }

  // ── init ──

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

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

    // Load permission flag from DB
    final config = await _db.getAppConfig();
    _wallpaperPermissionGranted =
        (config['wallpaper_permission_granted'] as int?) == 1;

    _isLoading = false;
    notifyListeners();
  }

  // ── Permission ──

  Future<void> grantPermission() async {
    _wallpaperPermissionGranted = true;
    await _db.updateAppConfig({'wallpaper_permission_granted': 1});
    notifyListeners();
  }

  // ── User wallpaper ──

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

  // ── Trigger generation ──

  /// Triggers wallpaper generation for the active categories.
  ///
  /// Reads [activeCategoryIds] from the database config and appearance
  /// settings from SharedPreferences on each call so this provider stays
  /// decoupled from [SchedulerConfig] and [AppearanceSettings].
  Future<void> triggerNow({required String locale}) async {
    final config = await _db.getAppConfig();
    final activeIds = _parseCategoryIds(
      config['active_category_ids'] as String? ?? '[]',
    );
    final isEnabled = (config['scheduler_enabled'] as int?) == 1;

    if (activeIds.isEmpty && isEnabled) {
      _status = WallpaperStatus.noCategories;
      _statusPayload = null;
      notifyListeners();
      EventBus.instance.emit(const SettingChanged(key: 'no_categories'));
      return;
    }

    if (activeIds.isEmpty) {
      _status = WallpaperStatus.noCategories;
      _statusPayload = null;
      notifyListeners();
      EventBus.instance.emit(const SettingChanged(key: 'no_categories'));
      return;
    }

    // F4 re-entrancy guard
    if (_status == WallpaperStatus.generating) return;

    _status = WallpaperStatus.generating;
    _statusPayload = null;
    notifyListeners();

    final verses = await _db.getVersesByCategoryIds(
      activeIds.toList(),
      locale,
    );

    if (verses.isEmpty) {
      _status = WallpaperStatus.error;
      _statusPayload = 'No verses for locale';
      // ignore: avoid_print
      print('WallpaperGenerator: noVersesForLocale');
      EventBus.instance.emit(const SettingChanged(key: 'wallpaper_error'));
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

    // Read appearance settings from SharedPreferences at runtime so
    // AppearanceSettings writes are always reflected in generation.
    final prefs = await SharedPreferences.getInstance();
    final horizontalOffset = prefs.getInt('horizontal_offset') ?? _horizontalOffset;
    final verticalAlignment = prefs.getString('vertical_alignment') ?? _verticalAlignment;
    final calibratedInset = prefs.getInt('calibrated_inset') ?? _calibratedInset;
    final fontScale = prefs.getDouble('font_scale') ?? _fontScale;
    final useMyWallpaper = prefs.getBool('use_my_wallpaper') ?? _useMyWallpaper;

    final verse = verses[0];
    final result = await _generator.generateAndSetWallpaper(
      verse: verse,
      locale: locale,
      horizontalOffset: horizontalOffset,
      verticalAlignment: verticalAlignment,
      fontScale: fontScale,
      calibratedInset: calibratedInset,
      useMyWallpaper: useMyWallpaper,
    );

    switch (result) {
      case WallpaperResultSuccess(:final wallpaperPath, :final citation):
        _status = WallpaperStatus.updated;
        _statusPayload = citation;
        EventBus.instance.emit(
          NotificationRequested(title: 'Vers Reminder', body: citation ?? ''),
        );
        EventBus.instance.emit(
          WallpaperGenerated(path: wallpaperPath, citation: citation),
        );
        _lastWallpaperPath = wallpaperPath;
        _lastWallpaperTimestamp = DateTime.now();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_wallpaper_path', wallpaperPath);
          await prefs.setString(
            'last_wallpaper_timestamp',
            _lastWallpaperTimestamp!.toIso8601String(),
          );
        } catch (e) {
          debugPrint('Failed to persist last wallpaper metadata: $e');
        }
        await _preGenerateFutureWallpapers(locale: locale);
      case WallpaperResultError(:final reason):
        _status = WallpaperStatus.error;
        _statusPayload = reason.name;
        // ignore: avoid_print
        print('WallpaperGenerator error: $reason');
        EventBus.instance.emit(const SettingChanged(key: 'wallpaper_error'));
    }
    notifyListeners();
  }

  // ── Pre-generation ──

  Future<void> _preGenerateFutureWallpapers({required String locale}) async {
    final config = await _db.getAppConfig();
    final activeIds = _parseCategoryIds(
      config['active_category_ids'] as String? ?? '[]',
    );
    if (activeIds.isEmpty) return;

    if (_isPreGenerating) return;
    _isPreGenerating = true;
    try {
      final randomVerses = await _db.getRandomVerses(
        activeIds.toList(),
        locale,
        WallpaperGenerator.preGenCount,
      );

      if (randomVerses.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final screenWidth = prefs.getInt('screen_width') ?? 1080;
      final screenHeight = prefs.getInt('screen_height') ?? 1920;
      final horizontalOffset = prefs.getInt('horizontal_offset') ?? _horizontalOffset;
      final verticalAlignment = prefs.getString('vertical_alignment') ?? _verticalAlignment;
      final calibratedInset = prefs.getInt('calibrated_inset') ?? _calibratedInset;
      final fontScale = prefs.getDouble('font_scale') ?? _fontScale;
      final useMyWallpaper = prefs.getBool('use_my_wallpaper') ?? _useMyWallpaper;

      await _generator.preGenerateWallpapers(
        verses: randomVerses,
        locale: locale,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        horizontalOffset: horizontalOffset,
        verticalAlignment: verticalAlignment,
        fontScale: fontScale,
        calibratedInset: calibratedInset,
        useMyWallpaper: useMyWallpaper,
      );
    } finally {
      _isPreGenerating = false;
    }
  }

  // ── Helpers ──

  static DateTime? _parseTimestamp(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Set<int> _parseCategoryIds(String raw) {
    if (raw == '[]' || raw.isEmpty) return {};
    try {
      final decoded = raw.codeUnits;
      // Simple parser for JSON array of ints like "[1,2,3]"
      final str = String.fromCharCodes(decoded);
      final inner = str.substring(1, str.length - 1);
      if (inner.isEmpty) return {};
      return inner.split(',').map((s) => int.parse(s.trim())).toSet();
    } catch (_) {
      return {};
    }
  }
}
