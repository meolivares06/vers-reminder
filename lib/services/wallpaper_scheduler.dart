import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';

import '../models/verse.dart';
import 'wallpaper_generator.dart';

const String _taskName = 'wallpaperChange';
const String _taskUnique = 'periodicWallpaperChange';
const String _localePrefKey = 'locale_override';

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
      final locale = prefs.getString(_localePrefKey) ?? 'es';
      final screenWidth = prefs.getInt('screen_width') ?? 1080;
      final screenHeight = prefs.getInt('screen_height') ?? 1920;
      final horizontalOffset = prefs.getInt('horizontal_offset') ?? 0;
      final verticalAlignment =
          prefs.getString('vertical_alignment') ?? 'center';
      final calibratedInset = prefs.getInt('calibrated_inset') ?? 0;
      final fontScale = prefs.getDouble('font_scale') ?? 1.0;

      final textField = locale == 'pt' ? 'v.textPt' : 'v.textEs';
      final placeholders = catIds.map((id) => '?').join(',');
      final verses = await db.rawQuery('''
        SELECT v.* FROM verses v
        INNER JOIN verse_categories vc ON v.id = vc.verseId
        WHERE vc.categoryId IN ($placeholders)
        AND $textField IS NOT NULL AND $textField != ''
        ORDER BY RANDOM() LIMIT 1
      ''', catIds);

      if (verses.isEmpty) return true;

      final verse = Verse.fromMap(verses.first);
      await WallpaperGenerator.instance.generateAndSetWallpaper(
        verse: verse,
        locale: locale,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        horizontalOffset: horizontalOffset,
        verticalAlignment: verticalAlignment,
        calibratedInset: calibratedInset,
        fontScale: fontScale,
      );
    } finally {
      await db.close();
    }

    return true;
  });
}

class WallpaperScheduler {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
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
