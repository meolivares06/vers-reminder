import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/verses/domain/verse.dart';
import 'package:vers_reminder/verses/widgets/verse_list_screen.dart';
import 'package:vers_reminder/shared/widgets/verse_tile.dart';
import 'package:vers_reminder/shared/widgets/confirm_delete_dialog.dart';
import 'package:vers_reminder/verses/infrastructure/category_create_dialog.dart';

/// Helper: wraps a child widget in a MaterialApp with localization delegates.
Widget wrapWithL10n(Widget child) {
  return MaterialApp(
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final dbPath = 'wl_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE verses (id INTEGER PRIMARY KEY AUTOINCREMENT, textEs TEXT NOT NULL, textPt TEXT, citation TEXT NOT NULL, createdAt TEXT NOT NULL)');
        await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, isSeed INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE verse_categories (verseId INTEGER NOT NULL, categoryId INTEGER NOT NULL, PRIMARY KEY (verseId, categoryId), FOREIGN KEY (verseId) REFERENCES verses(id) ON DELETE CASCADE, FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE)');
        await db.execute('CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT \'[]\')');
        await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        await db.execute('CREATE INDEX idx_vc_verseId ON verse_categories(verseId)');
        await db.execute('CREATE INDEX idx_vc_categoryId ON verse_categories(categoryId)');
        await db.execute('CREATE INDEX idx_verses_createdAt ON verses(createdAt)');
      }),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('VerseTile', () {
    testWidgets('shows citation and text preview', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: VerseTile(
          verse: Verse(textEs: 'Texto largo del versículo', citation: 'Juan 3:16'),
          onTap: () {},
          onDelete: () {},
        ),
      )));

      expect(find.text('Juan 3:16'), findsOneWidget);
      expect(find.text('Texto largo del versículo'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: VerseTile(
          verse: Verse(textEs: 'Texto', citation: 'T 1:1'),
          onTap: () => tapped = true,
          onDelete: () {},
        ),
      )));

      await tester.tap(find.text('Texto'));
      expect(tapped, true);
    });
  });

  group('ConfirmDeleteDialog', () {
    testWidgets('shows citation in message', (tester) async {
      await tester.pumpWidget(wrapWithL10n(Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => ConfirmDeleteDialog.show(ctx, 'Juan 3:16'),
            child: const Text('Open'),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Juan 3:16'), findsOneWidget);
      expect(find.text('¿Eliminar versículo?'), findsOneWidget);
    });

    testWidgets('returns true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(wrapWithL10n(Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmDeleteDialog.show(ctx, 'V 1:1');
            },
            child: const Text('Open'),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('returns false on cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(wrapWithL10n(Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await ConfirmDeleteDialog.show(ctx, 'V 1:1');
            },
            child: const Text('Open'),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, false);
    });
  });

  group('CategoryCreateDialog', () {
    testWidgets('returns category name on create', (tester) async {
      String? result;
      await tester.pumpWidget(wrapWithL10n(Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await CategoryCreateDialog.show(ctx);
            },
            child: const Text('Open'),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Fe');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(result, 'Fe');
    });

    testWidgets('returns null on cancel', (tester) async {
      String? result;
      await tester.pumpWidget(wrapWithL10n(Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await CategoryCreateDialog.show(ctx);
            },
            child: const Text('Open'),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('validates empty name', (tester) async {
      await tester.pumpWidget(wrapWithL10n(Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => CategoryCreateDialog.show(ctx),
            child: const Text('Open'),
          ),
        ),
      )));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Try to create without entering text
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
    });
  });
}
