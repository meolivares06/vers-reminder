import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vers_reminder/shared/event_bus/event_bus.dart';
import 'package:vers_reminder/shared/event_bus/events.dart';
import 'package:vers_reminder/shared/l10n/generated/app_localizations.dart';
import 'package:vers_reminder/shared/application/locale_provider.dart';
import 'package:vers_reminder/wallpaper/application/wallpaper_state.dart';
import 'package:vers_reminder/verses/application/verse_provider.dart';
import 'package:vers_reminder/verses/widgets/verse_form_screen.dart';
import 'package:vers_reminder/verses/widgets/verse_list_screen.dart';
import 'package:vers_reminder/settings/infrastructure/settings_screen.dart';
import 'package:vers_reminder/home/widgets/wallpaper_card.dart';

/// Smart container — reads providers, handles FAB logic and permission dialog.
/// Delegates rendering to [WallpaperCard] (dumb widget).
class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  State<HomeContainer> createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  int _currentIndex = 0;
  bool _lastWallpaperError = false;
  bool _lastWallpaperNoCategories = false;
  String? _lastErrorPayload;

  @override
  void initState() {
    super.initState();
    final bus = EventBus.instance;
    bus.on<WallpaperGenerated>((event) async {
      if (!mounted) return;
      setState(() {
        _lastWallpaperError = false;
        _lastErrorPayload = null;
      });
    });
    bus.on<SettingChanged>((event) async {
      if (!mounted) return;
      if (event.key == 'wallpaper_error') {
        setState(() {
          _lastWallpaperError = true;
        });
      } else if (event.key == 'no_categories') {
        setState(() {
          _lastWallpaperNoCategories = true;
        });
      }
    });
  }

  Future<void> _openVerseForm(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const VerseFormScreen()));
    if (mounted) {
      context.read<VerseProvider>().loadVerses(
            context.read<LocaleProvider>().locale.languageCode,
          );
    }
  }

  Future<void> _handleFabPressed() async {
    final l10n = AppLocalizations.of(context)!;
    final wallpaper = context.read<WallpaperState>();
    if (!wallpaper.wallpaperPermissionGranted) {
      _showPermissionDialog(wallpaper, l10n);
      return;
    }
    final locale = context.read<LocaleProvider>().locale.languageCode;
    try {
      await context.read<EventBus>().emit(RefreshWallpaper(locale: locale));
    } catch (e) {
      debugPrint('RefreshWallpaper emit failed: $e');
    }
    if (!mounted) return;
    if (_lastWallpaperNoCategories) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectCategoryStatus),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _lastWallpaperNoCategories = false;
    }
  }

  void _showPermissionDialog(
    WallpaperState wallpaper,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permissionTitle),
        content: Text(l10n.permissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await wallpaper.grantPermission();
              try {
                final locale =
                    context.read<LocaleProvider>().locale.languageCode;
                await context
                    .read<EventBus>()
                    .emit(RefreshWallpaper(locale: locale));
              } catch (e) {
                debugPrint('RefreshWallpaper emit failed: $e');
              }
            },
            child: Text(l10n.changeNow),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wallpaper = context.watch<WallpaperState>();
    final localeProvider = context.watch<LocaleProvider>();

    if (_lastWallpaperError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.generatingError}: ${_lastErrorPayload ?? ''}',
              ),
            ),
          );
        }
      });
      _lastWallpaperError = false;
      _lastErrorPayload = null;
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_currentIndex == 0 ? 'Vers Reminder' : l10n.verseListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          WallpaperCard(
            path: wallpaper.lastWallpaperPath,
            timestamp: wallpaper.lastWallpaperTimestamp,
            wallpaperPermissionGranted: wallpaper.wallpaperPermissionGranted,
            onTap: () {
              if (wallpaper.wallpaperPermissionGranted) {
                try {
                  final locale = localeProvider.locale.languageCode;
                  context
                      .read<EventBus>()
                      .emit(RefreshWallpaper(locale: locale));
                } catch (e) {
                  debugPrint('RefreshWallpaper emit failed: $e');
                }
              }
            },
            onFabPressed: _handleFabPressed,
          ),
          const VerseListScreen(),
        ],
      ),
      floatingActionButton: switch (_currentIndex) {
        0 => null,
        _ => FloatingActionButton(
            onPressed: () => _openVerseForm(context),
            child: const Icon(Icons.add),
          ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.verseListTitle,
          ),
        ],
      ),
    );
  }
}
