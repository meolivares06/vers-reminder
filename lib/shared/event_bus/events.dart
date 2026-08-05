/// Events for the modular-refactor event bus (Phase 2).
///
/// Emitted by modules and consumed by other modules via [EventBus].
/// Replaces the 8 HIGH-severity cross-module direct imports identified
/// in exploration #1128.

class RefreshWallpaper {
  final String locale;
  const RefreshWallpaper({required this.locale});
}

class WallpaperGenerated {
  final String path;
  final String? citation;
  const WallpaperGenerated({required this.path, this.citation});
}

class VerseAdded {
  final int? categoryId;
  const VerseAdded({this.categoryId});
}

class SettingChanged {
  final String key;
  const SettingChanged({required this.key});
}

class PermissionGranted {
  const PermissionGranted();
}

class SchedulerToggled {
  final bool enabled;
  final int? frequencyMinutes;
  const SchedulerToggled({required this.enabled, this.frequencyMinutes});
}

class BackupRestored {
  const BackupRestored();
}

class NotificationRequested {
  final String title;
  final String body;
  const NotificationRequested({required this.title, required this.body});
}
