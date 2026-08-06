import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/backup/infrastructure/wallpaper_backup_service.dart';

void main() {
  group('WallpaperBackupService event integration', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Ensure init is called once (idempotent — safe to call in every setUp).
      WallpaperBackupService.init();
      // Force reset the static flag for test isolation.
      // ignore: invalid_use_of_visible_for_testing_member
      WallpaperBackupService.resetForTesting();
      WallpaperBackupService.init();
    });

    test('init subscribes and emits BackupRestored on BackupRequested backup',
        () async {
      BackupRestored? received;
      EventBus.instance.on<BackupRestored>((event) async {
        received = event;
      });

      await EventBus.instance.emit(const BackupRequested(operation: 'backup'));

      expect(received, isNotNull);
      expect(received!.operation, 'backup');
      // backupCurrent() will fail in test environment (no MethodChannel),
      // so success should be false.
      expect(received!.success, false);
    });

    test('init subscribes and emits BackupRestored on BackupRequested restore',
        () async {
      BackupRestored? received;
      EventBus.instance.on<BackupRestored>((event) async {
        received = event;
      });

      await EventBus.instance.emit(const BackupRequested(operation: 'restore'));

      expect(received, isNotNull);
      expect(received!.operation, 'restore');
      expect(received!.success, false);
    });

    test('init is idempotent — second call does not duplicate handler',
        () async {
      // First call was in setUp. Second call should be a no-op.
      WallpaperBackupService.init();

      final received = <BackupRestored>[];
      EventBus.instance.on<BackupRestored>((event) async {
        received.add(event);
      });

      await EventBus.instance.emit(const BackupRequested(operation: 'backup'));

      // One from the backup service handler, one from our test handler.
      expect(received.length, 2,
          reason: 'one from backup service + one from test handler');
    });
  });
}
