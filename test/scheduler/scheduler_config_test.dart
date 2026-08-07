import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dbPath = 'sc_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE verses (id INTEGER PRIMARY KEY AUTOINCREMENT, textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, createdAt TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE verse_categories (verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)',
          );
          await db.execute(
            'CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\')',
          );
          await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('SchedulerConfig', () {
    // ── Initial state ──
    test('initial state has defaults', () async {
      final config = SchedulerConfig();
      await config.init();

      expect(config.isEnabled, false);
      expect(config.frequencyMinutes, 360);
      expect(config.activeCategoryIds, isEmpty);
    });

    test('init loads config from database', () async {
      // Pre-populate database
      await DatabaseService.instance.updateAppConfig({
        'scheduler_enabled': 1,
        'frequency_minutes': 60,
        'active_category_ids': '[1,2]',
      });

      final config = SchedulerConfig();
      await config.init();

      expect(config.isEnabled, true);
      expect(config.frequencyMinutes, 60);
      expect(config.activeCategoryIds, {1, 2});
    });

    // ── setEnabled ──
    test('setEnabled updates state and emits event', () async {
      final config = SchedulerConfig();
      await config.init();

      var emittedEnabled = false;
      EventBus.instance.on<SchedulerToggled>((event) async {
        emittedEnabled = event.enabled;
      });

      await config.setEnabled(true);

      expect(config.isEnabled, true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emittedEnabled, true);
    });

    test('setEnabled(false) emits disabled event', () async {
      final config = SchedulerConfig();
      await config.init();
      await config.setEnabled(true);

      var emittedEnabled = false;
      // Add a listener AFTER initial state
      EventBus.instance.on<SchedulerToggled>((event) async {
        emittedEnabled = event.enabled;
      });

      await config.setEnabled(false);

      expect(config.isEnabled, false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emittedEnabled, false);
    });

    test('setEnabled persists to database', () async {
      final config = SchedulerConfig();
      await config.init();

      await config.setEnabled(true);

      final dbConfig = await DatabaseService.instance.getAppConfig();
      expect(dbConfig['scheduler_enabled'], 1);
    });

    // ── setFrequency ──
    test('setFrequency updates value and emits event', () async {
      final config = SchedulerConfig();
      await config.init();

      var receivedFrequency = 0;
      EventBus.instance.on<SchedulerToggled>((event) async {
        receivedFrequency = event.frequencyMinutes ?? 0;
      });

      await config.setFrequency(60);

      expect(config.frequencyMinutes, 60);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(receivedFrequency, 60);
    });

    test('setFrequency persists to database', () async {
      final config = SchedulerConfig();
      await config.init();

      await config.setFrequency(30);

      final dbConfig = await DatabaseService.instance.getAppConfig();
      expect(dbConfig['frequency_minutes'], 30);
    });

    // ── toggleCategory ──
    test('toggleCategory adds and removes', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);
      await DatabaseService.instance.insertCategory('Cat 2', isSeed: true);

      final config = SchedulerConfig();
      await config.init();

      config.toggleCategory(1);
      expect(config.activeCategoryIds, {1});

      config.toggleCategory(2);
      expect(config.activeCategoryIds, {1, 2});

      config.toggleCategory(1);
      expect(config.activeCategoryIds, {2});
    });

    test('toggleCategory persists to database', () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);

      final config = SchedulerConfig();
      await config.init();

      config.toggleCategory(1);

      final dbConfig = await DatabaseService.instance.getAppConfig();
      expect(dbConfig['active_category_ids'], contains('1'));
    });

    test('toggleCategory emits SchedulerToggled when empty → non-empty',
        () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);

      final config = SchedulerConfig();
      await config.init();
      await config.setEnabled(true);

      var emitted = false;
      EventBus.instance.on<SchedulerToggled>((event) async {
        emitted = event.enabled;
      });

      config.toggleCategory(1);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emitted, true);
    });

    test('toggleCategory emits SchedulerToggled(false) when last removed',
        () async {
      await DatabaseService.instance.insertCategory('Cat 1', isSeed: true);

      final config = SchedulerConfig();
      await config.init();
      await config.setEnabled(true);
      config.toggleCategory(1);

      var emittedDisabled = false;
      EventBus.instance.on<SchedulerToggled>((event) async {
        if (!event.enabled) emittedDisabled = true;
      });

      config.toggleCategory(1); // Remove last category

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emittedDisabled, true);
    });
  });
}
