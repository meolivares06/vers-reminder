import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/wallpaper_status.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/verse_provider.dart';
import '../theme/app_theme.dart';
import 'backoffice/verse_form_screen.dart';
import 'backoffice/verse_list_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  WallpaperStatus _previousWallpaperStatus = WallpaperStatus.idle;

  Future<void> _openVerseForm(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VerseFormScreen()));
    if (mounted) {
      context.read<VerseProvider>().loadVerses(
        context.read<LocaleProvider>().locale.languageCode,
      );
    }
  }

  /// Shared permission-gated trigger for the gold Home FAB (mirrors the
  /// behavior of the removed full-width "Change now" button): shows the
  /// permission dialog when storage permission is missing, otherwise starts
  /// generation and reports the no-categories state via a snackbar.
  Future<void> _handleFabPressed() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final verseProvider = context.read<VerseProvider>();
    if (!settings.wallpaperPermissionGranted) {
      _showPermissionDialog(settings, verseProvider, l10n);
      return;
    }
    await settings.triggerNow(
      verseProvider: verseProvider,
      locale: context.read<LocaleProvider>().locale.languageCode,
    );
    if (!mounted) return;
    if (settings.status == WallpaperStatus.noCategories) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectCategoryStatus),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPermissionDialog(
    SettingsProvider settings,
    VerseProvider verseProvider,
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
              await settings.grantWallpaperPermission();
              settings.triggerNow(
                verseProvider: verseProvider,
                locale: context.read<LocaleProvider>().locale.languageCode,
              );
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
    final settings = context.watch<SettingsProvider>();

    // Show Snackbar when wallpaper generation fails
    if (settings.status == WallpaperStatus.error &&
        _previousWallpaperStatus != WallpaperStatus.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.generatingError}: ${settings.statusPayload ?? ''}',
              ),
            ),
          );
        }
      });
    }
    _previousWallpaperStatus = settings.status;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Vers Reminder' : l10n.verseListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            settings: settings,
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

class _HomeTab extends StatefulWidget {
  final SettingsProvider settings;
  final VoidCallback? onFabPressed;

  const _HomeTab({required this.settings, this.onFabPressed});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final l10n = AppLocalizations.of(context)!;
    final verseProvider = context.watch<VerseProvider>();

    // The wallpaper fills the available body height with a 12px margin.
    // The gold FAB is overlaid directly on the image — no fixed sizing needed.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            settings.lastWallpaperPath != null &&
                File(settings.lastWallpaperPath!).existsSync()
            ? Stack(
                fit: StackFit.expand,
                children: [
                  InkWell(
                    onTap: _triggerNow(settings, verseProvider, l10n),
                    child: Image.file(
                      File(settings.lastWallpaperPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.currentWallpaperLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (settings.lastWallpaperTimestamp
                              case final DateTime ts)
                            Text(
                              l10n.updatedAtLabel(
                                _relativeTime(ts, l10n),
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onFabPressed != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        onPressed: widget.onFabPressed,
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor: onGoldAccent,
                        tooltip: l10n.changeNow,
                        child: const Icon(Icons.refresh),
                      ),
                    ),
                ],
              )
            : InkWell(
                onTap: _triggerNow(settings, verseProvider, l10n),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wallpaper_outlined,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.noWallpaper,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Returns a trigger callback that kicks off generation when wallpaper
  /// permission was granted (shared by the wallpaper-card tap affordance and
  /// the empty-state tap, both of which remain silent when permission is off).
  VoidCallback _triggerNow(
    SettingsProvider settings,
    VerseProvider verseProvider,
    AppLocalizations l10n,
  ) {
    return () {
      if (settings.wallpaperPermissionGranted) {
        settings.triggerNow(
          verseProvider: verseProvider,
          locale: context.read<LocaleProvider>().locale.languageCode,
        );
      }
    };
  }

  /// Formats a wall timestamp as a compact localized relative phrase used as
  /// the argument of `updatedAtLabel(time)` (e.g. "0 min", "5 min", "2 h").
  String _relativeTime(DateTime time, AppLocalizations l10n) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return l10n.timeMinutes(0);
    if (diff.inMinutes < 60) return l10n.timeMinutes(diff.inMinutes);
    return l10n.timeHours(diff.inHours);
  }
}
