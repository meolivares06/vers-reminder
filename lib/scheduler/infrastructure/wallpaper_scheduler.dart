import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';

import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/wallpaper/infrastructure/wallpaper_generator.dart';

const String _taskName = 'wallpaperChange';
const String _taskUnique = 'periodicWallpaperChange';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'vers_reminder.db');
    final db = await openDatabase(path);

    try {
      final config = await db.query('app_config', where: 'id = 1');
      if (config.isEmpty) return true;

      final enabled = config.first['scheduler_enabled'] == 1;
      if (!enabled) return true;

      final idsStr = config.first['active_category_ids'] as String? ?? '[]';
      final catIds = (json.decode(idsStr) as List).cast<int>();
      if (catIds.isEmpty) return true;

      final prefs = await SharedPreferences.getInstance();
      final screenWidth = prefs.getInt('screen_width') ?? 1080;
      final screenHeight = prefs.getInt('screen_height') ?? 1920;

      // Cannot generate wallpaper in background isolate (no Flutter
      // rendering). Instead, set the next pre-generated wallpaper that was
      // cached during a previous foreground session (triggerNow, app init).
      await WallpaperGenerator.instance
          .setNextPreGenerated(screenWidth, screenHeight);
    } finally {
      await db.close();
    }

    return true;
  });
}

class WallpaperScheduler {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);

    // Listen for scheduler state changes via the event bus
    EventBus.instance.on<SchedulerToggled>((event) async {
      if (event.enabled && event.frequencyMinutes != null) {
        await registerPeriodic(event.frequencyMinutes!);
      } else if (!event.enabled) {
        await cancel();
      }
    });
  }

  static Future<void> registerPeriodic(int frequencyMinutes) async {
    await Workmanager().registerPeriodicTask(
      _taskUnique,
      _taskName,
      frequency: Duration(minutes: frequencyMinutes),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_taskUnique);
  }
}
