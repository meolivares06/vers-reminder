import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vers_reminder/l10n/generated/app_localizations.dart';

Widget buildTestApp(Locale locale) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          child: Column(
            children: [
              Text(l10n.settings),
              Text(l10n.save),
              Text(l10n.cancel),
              Text(l10n.verseListTitle),
              Text(l10n.noVerses),
              Text(l10n.changeNow),
              Text(l10n.generating),
              Text(l10n.wallpaperUpdated('John 3:16')),
              Text(l10n.generatingError),
              Text(l10n.selectCategoryStatus),
              Text(l10n.citation),
              Text(l10n.citationRequired),
              Text(l10n.textRequired),
            ],
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLocalizations', () {
    testWidgets('returns Spanish strings when locale is ES', (tester) async {
      await tester.pumpWidget(buildTestApp(const Locale('es')));

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Versículos'), findsOneWidget);
      expect(find.text('No hay versículos aún'), findsOneWidget);
      expect(find.text('Cambiar ahora'), findsOneWidget);
      expect(find.text('Generando...'), findsOneWidget);
      expect(find.text('Wallpaper actualizado: John 3:16'), findsOneWidget);
      expect(find.text('Error al generar el wallpaper'), findsOneWidget);
      expect(find.text('Selecciona al menos una categoría'), findsOneWidget);
      expect(find.text('Cita'), findsOneWidget);
      expect(find.text('La cita es requerida'), findsOneWidget);
      expect(find.text('El texto es requerido'), findsOneWidget);
    });

    testWidgets('returns Portuguese strings when locale is PT', (tester) async {
      await tester.pumpWidget(buildTestApp(const Locale('pt')));

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Versículos'), findsOneWidget);
      expect(find.text('Nenhum versículo ainda'), findsOneWidget);
      expect(find.text('Trocar agora'), findsOneWidget);
      expect(find.text('Gerando...'), findsOneWidget);
      expect(find.text('Wallpaper atualizado: John 3:16'), findsOneWidget);
      expect(find.text('Erro ao gerar o wallpaper'), findsOneWidget);
      expect(find.text('Selecione pelo menos uma categoria'), findsOneWidget);
      expect(find.text('Citação'), findsOneWidget);
      expect(find.text('A citação é obrigatória'), findsOneWidget);
      expect(find.text('O texto é obrigatório'), findsOneWidget);
    });

    testWidgets('returns English strings when locale is EN', (tester) async {
      await tester.pumpWidget(buildTestApp(const Locale('en')));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Verses'), findsOneWidget);
      expect(find.text('No verses yet'), findsOneWidget);
      expect(find.text('Change now'), findsOneWidget);
      expect(find.text('Generating...'), findsOneWidget);
      expect(find.text('Wallpaper updated: John 3:16'), findsOneWidget);
      expect(find.text('Error generating wallpaper'), findsOneWidget);
      expect(find.text('Select at least one category'), findsOneWidget);
      expect(find.text('Citation'), findsOneWidget);
      expect(find.text('Citation is required'), findsOneWidget);
      expect(find.text('Text is required'), findsOneWidget);
    });

    testWidgets('locale switching from ES to PT updates strings',
        (tester) async {
      await tester.pumpWidget(buildTestApp(const Locale('es')));

      // Verify ES strings are displayed
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      // Rebuild with PT locale
      await tester.pumpWidget(buildTestApp(const Locale('pt')));
      await tester.pumpAndSettle();

      // Now PT strings should be displayed
      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);

      // ES strings should no longer be present
      expect(find.text('Configuración'), findsNothing);
      expect(find.text('Guardar'), findsNothing);
    });
  });
}
