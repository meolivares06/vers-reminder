import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vers_reminder/shared/shared.dart';
import 'package:vers_reminder/wallpaper/wallpaper.dart';
import 'package:vers_reminder/verses/verses.dart';
import 'package:vers_reminder/settings/settings.dart';
import 'package:vers_reminder/scheduler/scheduler.dart';
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
  Timer? _countdownTimer;

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
    bus.on<BackupRestored>((event) async {
      if (!mounted) return;
      setState(() {});
    });

    // Live countdown — ticks every second so the "Next in ~MM:SS" stays
    // current without rebuilding the heavyweight wallpaper card.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
    final scheduler = context.watch<SchedulerConfig>();

    // Live countdown — recalculated every second by the _countdownTimer.
    final lastTimestamp = wallpaper.lastWallpaperTimestamp;
    String? countdownText;
    if (scheduler.isEnabled && lastTimestamp != null) {
      final elapsed = DateTime.now().difference(lastTimestamp).inSeconds;
      final remaining = scheduler.frequencyMinutes * 60 - elapsed;
      if (remaining > 0) {
        final mins = remaining ~/ 60;
        final secs = remaining % 60;
        countdownText = '~${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      }
    }

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentIndex == 0 ? 'Vers Reminder' : l10n.verseListTitle),
            if (countdownText != null)
              Text(
                countdownText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        actions: [
          if (scheduler.isEnabled)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.circle, size: 10, color: Colors.green),
            ),
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
            isGenerating: wallpaper.status == WallpaperStatus.generating,
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
