import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/verses/domain/verse.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    final dbPath = 'vp_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE verses (id INTEGER PRIMARY KEY AUTOINCREMENT, textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, createdAt TEXT NOT NULL)');
        await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE verse_categories (verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)');
        await db.execute('CREATE INDEX idx_vc_verseId ON verse_categories(verseId)');
        await db.execute('CREATE INDEX idx_vc_categoryId ON verse_categories(categoryId)');
        await db.execute('CREATE INDEX idx_verses_createdAt ON verses(createdAt)');
        await db.execute('CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\')');
        await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
      }),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('VerseProvider', () {
    test('init loads with existing data', () async {
      final db = DatabaseService.instance;
      final catId = await db.insertCategory('Salvación', isSeed: true);
      // Insert a verse so seed loader skips
      await db.insertVerse(Verse(textEs: 'Seed guard', citation: 'Guard 1:1'), [catId]);

      final provider = VerseProvider();
      await provider.init(locale: 'es');

      expect(provider.isLoading, false);
      expect(provider.categories.length, 1);
      expect(provider.groupedVerses.isNotEmpty, true);
    });

    test('saveVerse creates and reloads', () async {
      final db = DatabaseService.instance;
      final catId = await db.insertCategory('Fe', isSeed: true);
      await db.insertVerse(Verse(textEs: 'Pre', citation: 'Pre 1:1'), [catId]);

      final provider = VerseProvider();
      await provider.init(locale: 'es');

      final verse = Verse(textEs: 'La fe es...', citation: 'Heb 11:1');
      await provider.saveVerse(verse, [catId]);

      expect(provider.groupedVerses.isNotEmpty, true);
    });

    test('removeVerse deletes and reloads', () async {
      final db = DatabaseService.instance;
      final catId = await db.insertCategory('Fe', isSeed: true);
      final verseId = await db.insertVerse(
        Verse(textEs: 'To delete', citation: 'V1'), [catId]);

      final provider = VerseProvider();
      await provider.init(locale: 'es');
      expect(provider.groupedVerses.isNotEmpty, true);

      await provider.removeVerse(verseId);
      expect(provider.groupedVerses.isEmpty, true);
    });

    test('addCategory inserts and loads categories', () async {
      final db = DatabaseService.instance;
      await db.insertCategory('Existing', isSeed: true);
      final cats = await db.getAllCategories();
      await db.insertVerse(Verse(textEs: 'Pre', citation: 'P 1:1'), [cats.first.id!]);

      final provider = VerseProvider();
      await provider.init(locale: 'es');
      expect(provider.categories.length, 1);

      await provider.addCategory('Nueva Cat');
      expect(provider.categories.length, 2);
    });
  });
}
