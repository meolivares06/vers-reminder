import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/providers/locale_provider.dart';
import 'package:vers_reminder/providers/settings_provider.dart';

/// Minimal widget that replicates the restore section from SettingsScreen
/// to allow widget-level testing without the full screen's DB dependencies.
class _RestoreSection extends StatelessWidget {
  const _RestoreSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Divider(),
          Text(l10n.restoreOriginalWallpaper,
              style: Theme.of(context).textTheme.titleMedium),
          Text(l10n.restoreOriginalWallpaperSubtitle,
              style: Theme.of(context).textTheme.bodySmall),
          if (settings.hasBackup)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.restore),
                label: Text(l10n.restoreOriginalWallpaper),
                onPressed: () {},
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('restore button hidden when hasBackup is false',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final settingsProvider = SettingsProvider();
    final localeProvider = LocaleProvider();
    await tester.runAsync(() => localeProvider.init());

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: MaterialApp(
        locale: localeProvider.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const _RestoreSection(),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Restaurar wallpaper original'), findsOneWidget,
        reason: 'Section header visible, button hidden');
    expect(find.byType(TextButton), findsNothing,
        reason: 'Restore button should be absent');
  });

  testWidgets('restore button visible when hasBackup is true',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final settingsProvider = SettingsProvider();
    settingsProvider.setHasBackup(true);

    final localeProvider = LocaleProvider();
    await tester.runAsync(() => localeProvider.init());

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: MaterialApp(
        locale: localeProvider.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const _RestoreSection(),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Restaurar wallpaper original'), findsAtLeastNWidgets(2),
        reason: 'Section header and button label');
    expect(find.byType(TextButton), findsOneWidget,
        reason: 'Restore button should be visible');
  });
}
