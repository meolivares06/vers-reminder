import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:vers_reminder/verses/domain/verse.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';

class SeedLoader {
  final DatabaseService _db;

  SeedLoader(this._db);

  Future<void> loadIfEmpty() async {
    final isEmpty = await _db.isVerseTableEmpty();
    if (!isEmpty) return;

    final jsonString =
        await rootBundle.loadString('assets/seed/verses.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;

    final db = await _db.database;
    await db.transaction((txn) async {
      // Insert categories first
      final categories = data['categories'] as List<dynamic>;
      final Map<String, int> categoryIdMap = {};
      for (final cat in categories) {
        final name = cat['name'] as String;
        final isSeed = cat['isSeed'] as bool? ?? false;
        final id = await txn.insert('categories', {
          'name': name,
          'isSeed': isSeed ? 1 : 0,
        });
        categoryIdMap[name] = id;
      }

      // Insert verses
      final verses = data['verses'] as List<dynamic>;
      for (final v in verses) {
        final citation = v['citation'] as String;
        final textEs = v['textEs'] as String;
        final textPt = v['textPt'] as String?;
        final categoryName = v['categoryName'] as String;

        final verse = Verse(
          citation: citation,
          textEs: textEs,
          textPt: textPt,
        );

        final categoryId = categoryIdMap[categoryName];
        if (categoryId != null) {
          final verseId = await txn.insert('verses', verse.toMap());
          await txn.insert('verse_categories', {
            'verseId': verseId,
            'categoryId': categoryId,
          });
        }
      }
    });
  }
}
