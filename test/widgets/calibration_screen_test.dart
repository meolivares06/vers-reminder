import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/providers/settings_provider.dart';
import 'package:vers_reminder/providers/verse_provider.dart';
import 'package:vers_reminder/providers/locale_provider.dart';
import 'package:vers_reminder/screens/calibration/calibration_screen.dart';

/// Creates providers with pre-loaded data for widget testing.
/// Avoids real database by using providers with known initial state.
Widget _buildTestApp() {
  SharedPreferences.setMockInitialValues({});

  final settingsProvider = SettingsProvider();
  // Manually set fields that init() would normally load from DB
  settingsProvider.setCalibratedInset(0);

  final verseProvider = VerseProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
      ),
      ChangeNotifierProvider<VerseProvider>.value(
        value: verseProvider,
      ),
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider()..init(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const CalibrationScreen(),
    ),
  );
}

void main() {
  // ── Covers R-CU-003 (no crash on null preview) ──
  testWidgets('CalibrationScreen renders without crashing', (tester) async {
    // Set up mock SharedPreferences before any provider reads them
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // "Calibrar wallpaper" appears in both AppBar and card title (pre-existing)
    expect(find.text('Calibrar wallpaper'), findsAtLeastNWidgets(1),
        reason: 'title should appear at least once');
    expect(find.byType(Slider), findsNWidgets(2),
        reason: 'crop inset + horizontal offset sliders should be present');
    expect(find.byType(FilledButton), findsOneWidget,
        reason: 'Aplicar y verificar button should be present');
    expect(find.text('Guardar calibración'), findsOneWidget,
        reason: 'save button should be present');
    expect(find.text('Resetear a 0'), findsOneWidget,
        reason: 'reset button should be present');
  });

  // ── Covers R-CU-003 (placeholder shown on first null preview) ──
  testWidgets('shows preview area without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // The preview area renders without throwing.
    // If no verse is available, the placeholder shows.
    // If verse IS available, the preview still triggers but may
    // return null (no image cache) -> placeholder keeps showing.
    expect(find.byType(AspectRatio), findsOneWidget,
        reason: 'preview area should render');
    expect(find.byType(Image), findsNothing,
        reason:
            'no Image widget should appear without preview bytes');
  });

  // ── Covers R-CU-001 (slider interaction doesn't crash) ──
  testWidgets('slider interaction does not crash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_buildTestApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    // Find and interact with the first slider (crop inset)
    final slider = find.byType(Slider).first;
    expect(slider, findsOneWidget);
    await tester.ensureVisible(slider);
    await tester.pump();

    // Drag slider
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();

    // After slider interaction, screen should still be intact
    expect(find.byType(CalibrationScreen), findsOneWidget,
        reason: 'screen should remain after slider drag');

    // Pump past the 300ms debounce period
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Screen should still be intact after debounce fires
    expect(find.byType(CalibrationScreen), findsOneWidget,
        reason:
            'screen should remain after debounce preview request');
  });
}
