import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:vers_reminder/shared/shared.dart';

/// Manages scheduler configuration: enabled state, frequency, and
/// active verse categories that drive wallpaper generation scheduling.
///
/// Emits [SchedulerToggled] events so [WallpaperScheduler] (and other
/// listeners) react to config changes without direct imports.
class SchedulerConfig extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  bool _isEnabled = false;
  int _frequencyMinutes = 360;
  Set<int> _activeCategoryIds = {};

  bool get isEnabled => _isEnabled;
  int get frequencyMinutes => _frequencyMinutes;
  Set<int> get activeCategoryIds => _activeCategoryIds;

  String get _frequencyText {
    if (_frequencyMinutes % 60 == 0) {
      return 'Every ${_frequencyMinutes ~/ 60} h';
    }
    return 'Every $_frequencyMinutes min';
  }

  /// Test seam — allows widget tests to preset active categories without
  /// a real database.
  @visibleForTesting
  void setActiveCategoriesForTest(Set<int> ids) {
    _activeCategoryIds = ids;
    notifyListeners();
  }

  Future<void> init() async {
    final config = await _db.getAppConfig();
    _isEnabled = config['scheduler_enabled'] == 1;
    _frequencyMinutes = config['frequency_minutes'] as int? ?? 360;
    final idsStr = config['active_category_ids'] as String? ?? '[]';
    _activeCategoryIds = (json.decode(idsStr) as List).cast<int>().toSet();

    if (_isEnabled && _activeCategoryIds.isNotEmpty) {
      EventBus.instance.emit(SchedulerToggled(enabled: true));
      EventBus.instance.emit(
        NotificationRequested(
          title: 'Vers Reminder',
          body: '',
        ),
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _db.updateAppConfig({'scheduler_enabled': enabled ? 1 : 0});
    notifyListeners();

    if (enabled) {
      EventBus.instance.emit(
        SchedulerToggled(enabled: true, frequencyMinutes: _frequencyMinutes),
      );
      if (_activeCategoryIds.isNotEmpty) {
        EventBus.instance.emit(
          NotificationRequested(title: 'Vers Reminder', body: _frequencyText),
        );
      }
    } else {
      EventBus.instance.emit(const SchedulerToggled(enabled: false));
    }
  }

  Future<void> setFrequency(int minutes) async {
    _frequencyMinutes = minutes;
    await _db.updateAppConfig({'frequency_minutes': minutes});
    notifyListeners();

    EventBus.instance.emit(
      SchedulerToggled(
        enabled: _isEnabled,
        frequencyMinutes: minutes,
      ),
    );
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
      EventBus.instance.emit(const SchedulerToggled(enabled: false));
    } else if (_isEnabled && _activeCategoryIds.length == 1) {
      EventBus.instance.emit(
        SchedulerToggled(enabled: true, frequencyMinutes: _frequencyMinutes),
      );
    }
  }
}
