import 'package:flutter/foundation.dart';
import 'package:vers_reminder/shared/shared.dart' hide Category;
import 'package:vers_reminder/shared/domain/category.dart' as models;
import 'package:vers_reminder/verses/application/seed_loader.dart';

class VerseProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  Map<String, List<Verse>> _groupedVerses = {};
  List<models.Category> _categories = [];
  bool _isLoading = false;
  String _currentLocale = 'es';

  Map<String, List<Verse>> get groupedVerses => _groupedVerses;
  List<models.Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> init({String locale = 'es'}) async {
    _currentLocale = locale;
    _isLoading = true;
    notifyListeners();

    await SeedLoader(_db).loadIfEmpty();
    await loadCategories();
    await loadVerses(locale);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadVerses(String locale) async {
    _currentLocale = locale;
    _groupedVerses = await _db.getVersesGroupedByCategory(locale);
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _db.getAllCategories();
    notifyListeners();
  }

  Future<void> saveVerse(Verse verse, List<int> categoryIds) async {
    if (verse.id != null) {
      await _db.updateVerse(verse, categoryIds);
    } else {
      await _db.insertVerse(verse, categoryIds);
    }
    // Reload after save so UI reflects the change
    await loadVerses(_currentLocale);
    await loadCategories();
  }

  Future<void> removeVerse(int id) async {
    await _db.deleteVerse(id);
    // Reload after delete
    await loadVerses(_currentLocale);
  }

  Future<void> addCategory(String name, {bool isSeed = false}) async {
    await _db.insertCategory(name, isSeed: isSeed);
    await loadCategories();
  }
}
