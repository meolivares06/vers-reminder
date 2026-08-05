import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/verses/domain/verse.dart';

Future<Database> _createDb() async {
  return databaseFactoryFfi.openDatabase(':memory:',
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            textEs TEXT NOT NULL, textPt TEXT,
            citation TEXT NOT NULL, createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE verse_categories (
            verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL,
            PRIMARY KEY (verseId, categoryId),
            FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE,
            FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_vc_verseId ON verse_categories(verseId)');
        await db.execute('CREATE INDEX idx_vc_categoryId ON verse_categories(categoryId)');
        await db.execute('CREATE INDEX idx_verses_createdAt ON verses(createdAt)');
        await db.execute('''
          CREATE TABLE app_config (
            id INTEGER PRIMARY KEY DEFAULT 1,
            scheduler_enabled INTEGER NOT NULL DEFAULT 0,
            frequency_minutes INTEGER NOT NULL DEFAULT 360,
            active_category_ids TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
      },
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  var _counter = 0;

  setUp(() async {
    _counter++;
    final dbPath = 'vrdb_${DateTime.now().millisecondsSinceEpoch}_$_counter.db';
    final db = await databaseFactoryFfi.openDatabase(dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async { /* schema in _createDb */ },
      ),
    );
    // Create schema manually
    await db.execute('CREATE TABLE IF NOT EXISTS verses (id INTEGER PRIMARY KEY AUTOINCREMENT, textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, createdAt TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS verse_categories (verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vc_verseId ON verse_categories(verseId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vc_categoryId ON verse_categories(categoryId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_verses_createdAt ON verses(createdAt)');
    await db.execute('CREATE TABLE IF NOT EXISTS app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\')');
    await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
    DatabaseService.setTestDatabase(db);
  });

  group('DatabaseService', () {
    test('isVerseTableEmpty returns true on fresh DB', () async {
      expect(await DatabaseService.instance.isVerseTableEmpty(), true);
    });

    test('insert and read a verse', () async {
      final db = DatabaseService.instance;
      final catId = await db.insertCategory('Test Cat', isSeed: true);
      final verseId = await db.insertVerse(
        Verse(textEs: 'ES', textPt: 'PT', citation: 'T 1:1'), [catId]);
      expect(verseId, greaterThan(0));
      expect(await db.isVerseTableEmpty(), false);
      final grouped = await db.getVersesGroupedByCategory('es');
      expect(grouped.length, 1);
      expect(grouped.values.first.first.textEs, 'ES');
    });

    test('update a verse', () async {
      final db = DatabaseService.instance;
      final catId = await db.insertCategory('Cat', isSeed: true);
      final vid = await db.insertVerse(Verse(textEs: 'O', citation: 'O 1:1'), [catId]);
      await db.updateVerse(Verse(id: vid, textEs: 'U', citation: 'O 1:1'), [catId]);
      final g = await db.getVersesGroupedByCategory('es');
      expect(g.values.first.first.textEs, 'U');
    });

    test('delete with cascade', () async {
      final db = DatabaseService.instance;
      final cId = await db.insertCategory('DelCat', isSeed: true);
      final vId = await db.insertVerse(Verse(textEs: 'D', citation: 'D 1:1'), [cId]);

      // Verify verse exists
      var before = await db.getVersesGroupedByCategory('es');
      expect(before.isNotEmpty, true);

      await db.deleteVerse(vId);

      // After delete, those verse_categories rows should be gone
      var after = await db.getVersesGroupedByCategory('es');
      // The category DelCat should either have 0 verses or not be in the map
      final hasDelCat = after.containsKey('DelCat');
      if (hasDelCat) {
        expect(after['DelCat'], isEmpty);
      }

      // Category should still exist
      final cats = await db.getAllCategories();
      expect(cats.any((c) => c.name == 'DelCat'), true);
    });

    test('categories CRUD', () async {
      await DatabaseService.instance.insertCategory('CatA_', isSeed: true);
      await DatabaseService.instance.insertCategory('CatB_', isSeed: true);
      final cats = await DatabaseService.instance.getAllCategories();
      final filtered = cats.where((c) => c.name.startsWith('Cat'));
      expect(filtered.length, 2);
    });

    test('getVersesByCategoryIds', () async {
      final db = DatabaseService.instance;
      final c = await db.insertCategory('C', isSeed: true);
      await db.insertVerse(Verse(textEs: 'V1', citation: 'V1'), [c]);
      await db.insertVerse(Verse(textEs: 'V2', citation: 'V2'), [c]);
      final r = await db.getVersesByCategoryIds([c], 'es');
      expect(r.length, 1);
    });

    test('app config defaults', () async {
      final c = await DatabaseService.instance.getAppConfig();
      expect(c['scheduler_enabled'], 0);
      expect(c['frequency_minutes'], 360);
    });

    test('app config update', () async {
      await DatabaseService.instance.updateAppConfig({'scheduler_enabled': 1, 'frequency_minutes': 60});
      final c = await DatabaseService.instance.getAppConfig();
      expect(c['scheduler_enabled'], 1);
      expect(c['frequency_minutes'], 60);
    });
  });
}
