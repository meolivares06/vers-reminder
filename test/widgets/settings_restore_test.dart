import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/shared/locale_provider.dart';
import 'package:vers_reminder/shared/settings_provider.dart';
import 'package:vers_reminder/shared/widgets/async_action_button.dart';

/// Minimal widget that replicates the restore tile from SettingsScreen to
/// allow widget-level testing without the full screen's DB dependencies.
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
          AsyncActionButton(
            icon: Icons.restore,
            label: l10n.restoreOriginalWallpaper,
            style: AsyncActionButtonStyle.tile,
            enabled: settings.hasBackup,
            onPressed: () async {/* restore handler */},
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('restore tile disabled and not tappable when hasBackup is false',
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

    // The tile is rendered (visible) but disabled — no tap action available.
    expect(find.text('Restaurar wallpaper original'), findsAtLeastNWidgets(2),
        reason: 'Section header + tile label visible');
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNull,
        reason: 'restore tile is disabled (onTap null) when no backup');
  });

  testWidgets('restore tile is tappable when hasBackup is true',
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
        reason: 'Section header and tile label');
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNotNull,
        reason: 'restore tile is tappable when a backup exists');
  });
}
