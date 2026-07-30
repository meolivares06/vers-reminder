# Design: Scaffolding + Backoffice + Seed

## Technical Approach

Single-phase Flutter project scaffold from zero: `flutter create`, wire dependencies, define SQLite schema via raw SQL, build a `DatabaseService` singleton, load seed JSON from assets, and wire a Provider tree that feeds the Backoffice UI. The design follows the proposal's 5 phases but collapses them into 3 delivery slices: (1) project scaffold + models + DB layer, (2) seed data + locale resolution, (3) backoffice CRUD screens.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `pubspec.yaml` | Create | Flutter project deps: sqflite, path_provider, provider, intl |
| `lib/main.dart` | Create | App entry: providers, locale resolution, MaterialApp router |
| `lib/models/verse.dart` | Create | Verse data class + fromMap/toMap |
| `lib/models/category.dart` | Create | Category data class + fromMap/toMap |
| `lib/database/database_service.dart` | Create | SQLite init, schema, CRUD helpers, seed loader |
| `lib/database/seed_loader.dart` | Create | Reads `verses.json`, inserts if DB empty |
| `lib/providers/verse_provider.dart` | Create | ChangeNotifier wrapping DatabaseService, exposes grouped verses |
| `lib/providers/locale_provider.dart` | Create | ChangeNotifier for locale state + override persistence |
| `lib/screens/backoffice/verse_list_screen.dart` | Create | Grouped verse list with category headers |
| `lib/screens/backoffice/verse_form_screen.dart` | Create | Create/edit form with multi-category chips |
| `lib/widgets/category_chip_field.dart` | Create | Reusable category chip selector with inline add |
| `lib/widgets/confirm_delete_dialog.dart` | Create | Confirmation dialog for verse deletion |
| `lib/l10n/app_es.arb` | Create | Spanish UI strings |
| `lib/l10n/app_pt.arb` | Create | Portuguese UI strings |
| `assets/seed/verses.json` | Create | Seed verses in ES (RVR60) and PT (ARC 2009) |

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|-------------|-----------|
| State management | **provider** | Riverpod, BLoC | Pre-scaffold project, minimal deps, well-known API. Riverpod adds code gen infra we don't need yet. |
| Locale override storage | **SharedPreferences** | SQLite table | Single string key, no migration risk, avoid coupling locale to the verse DB. |
| DB initialization | **Raw SQL in `onCreate`** | sqflite migrations package | No versioning needed yet. Single schema version. Migrations come when schema evolves. |
| Seed check | **COUNT(*) on verses** | Separate flag table | One query vs. two writes. If verses exist, skip — simple and correct. |
| Grouped query | **SQL JOIN + Dart groupBy** | SQL GROUP BY with JSON aggregation | Dart code is easier to read/debug. Raw data keeps queries simple, grouping moves to the provider. |

## Data Flow

```
Seed JSON ──→ SeedLoader ──→ DatabaseService ──→ SQLite
                                    ↑
                              VerseProvider (ChangeNotifier)
                                    │
                    ┌───────────────┼───────────────┐
                    ↓               ↓               ↓
            VerseListScreen   VerseFormScreen   LocaleProvider
                                                    │
                                      SharedPreferences ←── user toggle
                                                    ↓
                                              MaterialApp
                                              (localizationsDelegates)
```

**Locale resolution order**: `LocaleProvider.init()` reads override from SharedPreferences → if null, falls back to `WidgetsBinding.instance.platformDispatcher.locale` → resolves to `es` or `pt` → `MaterialApp` rebuilds.

## Interfaces / Contracts

```dart
// DatabaseService — singleton, created once in main()
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  Future<Database> get database;
  // Verses
  Future<int> insertVerse(Verse v, List<int> categoryIds);
  Future<void> updateVerse(Verse v, List<int> categoryIds);
  Future<void> deleteVerse(int id);
  Future<Map<String, List<Verse>>> getVersesGroupedByCategory(String locale);
  // Categories
  Future<List<Category>> getAllCategories();
  Future<int> insertCategory(String name, {String? icon});
  // Seed
  Future<bool> isVerseTableEmpty();
  Future<void> loadSeed(String locale);
}

// VerseProvider — ChangeNotifier, consumed by UI
class VerseProvider extends ChangeNotifier {
  Map<String, List<Verse>> get groupedVerses;
  List<Category> get categories;
  Future<void> loadVerses(String locale);
  Future<void> saveVerse(Verse v, List<int> categoryIds);
  Future<void> removeVerse(int id);
}

// LocaleProvider — ChangeNotifier, drives MaterialApp locale
class LocaleProvider extends ChangeNotifier {
  Locale get locale;
  Future<void> init();
  Future<void> setLocale(Locale l);
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Verse/Category model serialization | Dart `==` and `toMap`/`fromMap` roundtrip |
| Unit | SeedLoader skip-if-not-empty | In-memory SQLite, insert one row, verify seed skips |
| Integration | DatabaseService CRUD + cascade | In-memory SQLite, full insert/update/delete cycle |
| Integration | LocaleProvider init + persistence | SharedPreferences mock, verify fallback chain |
| Widget | VerseFormScreen validation | `flutter_test` pumpWidget, verify error on no categories |

## Migration / Rollout

No migration required. First scaffold — no prior data.

## Open Questions

- [ ] Confirm seed verses JSON format: should categories be seeded separately or inferred from verses? (Design assumes categories are defined in a `categories` key in the JSON, separate from verses.)
- [ ] Confirm whether the author wants exactly 16 fixed categories or the seed file content will be provided separately.
- [ ] Confirm app icon / splash screen — out of scope for now, but needed before Play Store.
