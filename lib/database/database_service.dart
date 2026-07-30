import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/verse.dart';
import '../models/category.dart' as models;

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  /// For testing: inject a pre-built database (e.g., from sqflite_common_ffi).
  static void setTestDatabase(Database db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = p.join(await getDatabasesPath(), 'vers_reminder.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        textEs TEXT NOT NULL,
        textPt TEXT,
        citation TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        isSeed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE verse_categories (
        verseId INTEGER NOT NULL,
        categoryId INTEGER NOT NULL,
        PRIMARY KEY (verseId, categoryId),
        FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // Performance indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vc_verseId ON verse_categories(verseId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vc_categoryId ON verse_categories(categoryId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_verses_createdAt ON verses(createdAt)');

    await _createAppConfig(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAppConfig(db);
    }
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE app_config ADD COLUMN wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0
      ''');
    }
  }

  Future<void> _createAppConfig(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_config (
        id INTEGER PRIMARY KEY DEFAULT 1,
        scheduler_enabled INTEGER NOT NULL DEFAULT 0,
        frequency_minutes INTEGER NOT NULL DEFAULT 360,
        active_category_ids TEXT NOT NULL DEFAULT '[]',
        wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO app_config (id) VALUES (1)
    ''');
  }

  // --- Verses ---

  Future<int> insertVerse(Verse verse, List<int> categoryIds) async {
    final db = await database;
    final verseId = await db.insert('verses', verse.toMap());
    for (final catId in categoryIds) {
      await db.insert('verse_categories', {
        'verseId': verseId,
        'categoryId': catId,
      });
    }
    return verseId;
  }

  Future<void> updateVerse(Verse verse, List<int> categoryIds) async {
    final db = await database;
    await db.update(
      'verses',
      verse.toMap(),
      where: 'id = ?',
      whereArgs: [verse.id],
    );
    // Re-insert categories
    await db.delete(
      'verse_categories',
      where: 'verseId = ?',
      whereArgs: [verse.id],
    );
    for (final catId in categoryIds) {
      await db.insert('verse_categories', {
        'verseId': verse.id,
        'categoryId': catId,
      });
    }
  }

  Future<void> deleteVerse(int id) async {
    final db = await database;
    // Cascade delete via FK
    await db.delete('verses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, List<Verse>>> getVersesGroupedByCategory(
      String locale) async {
    final db = await database;
    final textField = locale == 'pt' ? 'textPt' : 'textEs';

    final rows = await db.rawQuery('''
      SELECT v.*, c.name as categoryName
      FROM verses v
      INNER JOIN verse_categories vc ON v.id = vc.verseId
      INNER JOIN categories c ON vc.categoryId = c.id
      WHERE v.$textField IS NOT NULL AND v.$textField != ''
      ORDER BY c.name ASC, v.createdAt ASC
    ''');

    final Map<String, List<Verse>> grouped = {};
    for (final row in rows) {
      final categoryName = row['categoryName'] as String;
      final verse = Verse.fromMap(row);
      grouped.putIfAbsent(categoryName, () => []);
      grouped[categoryName]!.add(verse);
    }
    return grouped;
  }

  // --- Categories ---

  Future<List<models.Category>> getAllCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((row) => models.Category.fromMap(row)).toList();
  }

  Future<int> insertCategory(String name, {bool isSeed = false}) async {
    final db = await database;
    return await db.insert('categories', {
      'name': name,
      'isSeed': isSeed ? 1 : 0,
    });
  }

  // --- App Config ---

  Future<Map<String, dynamic>> getAppConfig() async {
    final db = await database;
    final rows = await db.query('app_config', where: 'id = 1');
    if (rows.isEmpty) {
      return {
        'scheduler_enabled': 0,
        'frequency_minutes': 360,
        'active_category_ids': '[]',
        'wallpaper_permission_granted': 0,
      };
    }
    return rows.first;
  }

  Future<void> updateAppConfig(Map<String, dynamic> values) async {
    final db = await database;
    await db.update(
      'app_config',
      values,
      where: 'id = 1',
    );
  }

  Future<List<Verse>> getVersesByCategoryIds(
      List<int> categoryIds, String locale) async {
    if (categoryIds.isEmpty) return [];

    final db = await database;
    final textField = locale == 'pt' ? 'v.textPt' : 'v.textEs';
    final placeholders = categoryIds.map((_) => '?').join(',');

    final rows = await db.rawQuery('''
      SELECT v.* FROM verses v
      INNER JOIN verse_categories vc ON v.id = vc.verseId
      WHERE vc.categoryId IN ($placeholders)
      AND $textField IS NOT NULL AND $textField != ''
      ORDER BY RANDOM() LIMIT 1
    ''', categoryIds);

    return rows.map((row) => Verse.fromMap(row)).toList();
  }

  /// Returns up to [limit] random verses from the selected categories.
  Future<List<Verse>> getRandomVerses(
      List<int> categoryIds, String locale, int limit) async {
    if (categoryIds.isEmpty || limit <= 0) return [];

    final db = await database;
    final textField = locale == 'pt' ? 'v.textPt' : 'v.textEs';
    final placeholders = categoryIds.map((_) => '?').join(',');

    final rows = await db.rawQuery('''
      SELECT v.* FROM verses v
      INNER JOIN verse_categories vc ON v.id = vc.verseId
      WHERE vc.categoryId IN ($placeholders)
      AND $textField IS NOT NULL AND $textField != ''
      ORDER BY RANDOM() LIMIT $limit
    ''', categoryIds);

    return rows.map((row) => Verse.fromMap(row)).toList();
  }

  // --- Seed ---

  Future<bool> isVerseTableEmpty() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM verses');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count == 0;
  }
}
