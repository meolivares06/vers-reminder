import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vers_reminder/shared/domain/database_service.dart';
import 'package:vers_reminder/shared/shared.dart' hide Category;
import 'package:vers_reminder/shared/domain/category.dart' as models;
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/scheduler/application/scheduler_config.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/verses/widgets/category_chip_bar.dart';

Widget wrapL10n(Widget child) {
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
    final dbPath = 'ccb_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute("CREATE TABLE app_config (id INTEGER PRIMARY KEY DEFAULT 1, scheduler_enabled INTEGER NOT NULL DEFAULT 0, frequency_minutes INTEGER NOT NULL DEFAULT 360, active_category_ids TEXT NOT NULL DEFAULT '[]', wallpaper_permission_granted INTEGER NOT NULL DEFAULT 0)");
          await db.execute("INSERT OR IGNORE INTO app_config (id) VALUES (1)");
        },
      ),
    );
    DatabaseService.setTestDatabase(db);
  });

  group('CategoryChipBar widget', () {
    testWidgets('renders a chip for each category plus ✚', (tester) async {
      final scheduler = SchedulerConfig();
      final provider = VerseProvider();

      // Provide test data via runAsync so async operations don't block.
      await tester.runAsync(() async {
        provider.setCategoriesForTest([
          models.Category(id: 1, name: 'Esperanza'),
          models.Category(id: 2, name: 'Fe'),
        ]);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SchedulerConfig>.value(value: scheduler),
            ChangeNotifierProvider<VerseProvider>.value(value: provider),
          ],
          child: wrapL10n(const Scaffold(body: CategoryChipBar())),
        ),
      );

      expect(find.byType(FilterChip), findsNWidgets(2));
      expect(find.byType(ActionChip), findsOneWidget);
      expect(find.text('Esperanza'), findsOneWidget);
      expect(find.text('Fe'), findsOneWidget);
    });

    testWidgets('tapping a chip toggles scheduler active categories', (
      tester,
    ) async {
      final scheduler = SchedulerConfig();
      final provider = VerseProvider();

      await tester.runAsync(() async {
        provider.setCategoriesForTest([
          models.Category(id: 1, name: 'Esperanza'),
        ]);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SchedulerConfig>.value(value: scheduler),
            ChangeNotifierProvider<VerseProvider>.value(value: provider),
          ],
          child: wrapL10n(const Scaffold(body: CategoryChipBar())),
        ),
      );

      // Not selected initially.
      expect(scheduler.activeCategoryIds.contains(1), isFalse);

      // Tap the chip — toggleCategory is async (DB write), use runAsync.
      await tester.tap(find.text('Esperanza'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      // Now selected.
      expect(scheduler.activeCategoryIds.contains(1), isTrue);

      // Tap again — deselect.
      await tester.tap(find.text('Esperanza'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(scheduler.activeCategoryIds.contains(1), isFalse);
    });

    testWidgets('✚ chip opens create dialog', (tester) async {
      final scheduler = SchedulerConfig();
      final provider = VerseProvider();

      await tester.runAsync(() async {
        provider.setCategoriesForTest([]);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SchedulerConfig>.value(value: scheduler),
            ChangeNotifierProvider<VerseProvider>.value(value: provider),
          ],
          child: wrapL10n(const Scaffold(body: CategoryChipBar())),
        ),
      );

      await tester.tap(find.text('Agregar categoría'));
      await tester.pumpAndSettle();

      // Dialog is open.
      expect(find.text('Nueva categoría'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
