import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:vers_reminder/settings/update_cleanup_service.dart';

void main() {
  late Directory appSupport;

  setUp(() {
    appSupport = Directory.systemTemp.createTempSync('update_cleanup_test_');
  });

  tearDown(() {
    if (appSupport.existsSync()) {
      appSupport.deleteSync(recursive: true);
    }
  });

  group('updatesDir', () {
    test('Sc.1 creates updates dir when absent', () async {
      final path = await UpdateCleanupService.instance
          .updatesDir(appSupportOverride: appSupport.path);

      expect(path, p.join(appSupport.path, 'updates'));
      expect(Directory(path).existsSync(), isTrue);
    });

    test('Sc.1b reuses existing updates dir', () async {
      final dir = Directory(p.join(appSupport.path, 'updates'));
      dir.createSync(recursive: true);

      final path = await UpdateCleanupService.instance
          .updatesDir(appSupportOverride: appSupport.path);

      expect(path, p.join(appSupport.path, 'updates'));
    });
  });

  group('cleanUpdatesDir', () {
    test('Sc.2 deletes old apk files in updates dir', () async {
      final dir = Directory(p.join(appSupport.path, 'updates'));
      dir.createSync(recursive: true);
      File(p.join(dir.path, 'v1.0.0-1.apk')).writeAsBytesSync([1, 2, 3]);
      File(p.join(dir.path, 'v0.9.0-3.apk')).writeAsBytesSync([1, 2, 3]);

      final deleted = await UpdateCleanupService.instance
          .cleanUpdatesDir(appSupportOverride: appSupport.path);

      expect(deleted, 2);
      expect(dir.existsSync(), isTrue);
      expect(
          dir.listSync().whereType<File>().where((f) =>
              f.path.toLowerCase().endsWith('.apk')),
          isEmpty);
    });

    test('Sc.3 empty updates dir is a no-op returning 0', () async {
      final dir = Directory(p.join(appSupport.path, 'updates'));
      dir.createSync(recursive: true);

      final deleted = await UpdateCleanupService.instance
          .cleanUpdatesDir(appSupportOverride: appSupport.path);

      expect(deleted, 0);
    });

    test('Sc.4 absent updates dir is created and no-op returns 0', () async {
      final dir = Directory(p.join(appSupport.path, 'updates'));
      expect(dir.existsSync(), isFalse);

      final deleted = await UpdateCleanupService.instance
          .cleanUpdatesDir(appSupportOverride: appSupport.path);

      expect(deleted, 0);
      expect(dir.existsSync(), isTrue);
    });

    test('Sc.5 missing apk at delete time is tolerated without error',
        () async {
      // A partial download existed once but is now gone; the sweep must not
      // raise despite the missing target.
      final dir = Directory(p.join(appSupport.path, 'updates'));
      dir.createSync(recursive: true);
      final partial = File(p.join(dir.path, 'old.apk'));
      partial.writeAsBytesSync([1, 2, 3]);
      partial.deleteSync();

      final deleted = await UpdateCleanupService.instance
          .cleanUpdatesDir(appSupportOverride: appSupport.path);

      expect(deleted, 0);
    });

    test('non-apk files are left untouched', () async {
      final dir = Directory(p.join(appSupport.path, 'updates'));
      dir.createSync(recursive: true);
      File(p.join(dir.path, 'current.apk')).writeAsBytesSync([1, 2, 3]);
      File(p.join(dir.path, 'readme.txt')).writeAsBytesSync([9]);

      final deleted = await UpdateCleanupService.instance
          .cleanUpdatesDir(appSupportOverride: appSupport.path);

      expect(deleted, 1);
      expect(File(p.join(dir.path, 'readme.txt')).existsSync(), isTrue);
    });
  });
}
