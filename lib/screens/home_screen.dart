import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/wallpaper_status.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/verse_provider.dart';
import '../widgets/app_version.dart';
import '../widgets/async_action_button.dart';
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const VerseFormScreen(),
      ),
    );
    if (mounted) {
      context.read<VerseProvider>().loadVerses(
            context.read<LocaleProvider>().locale.languageCode,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final locale = context.watch<LocaleProvider>().locale.languageCode;

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
          _HomeTab(settings: settings, locale: locale),
          const VerseListScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => _openVerseForm(context),
              child: const Icon(Icons.add),
            )
          : null,
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
  final String locale;

  const _HomeTab({required this.settings, required this.locale});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await resolveAppVersionString();
      if (mounted) {
        setState(() => _appVersion = version);
      }
    } catch (_) {
      // Leave the version field empty — the About tile renders no stale string
      // when the platform lookup fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final locale = widget.locale;
    final l10n = AppLocalizations.of(context)!;
    final verseProvider = context.watch<VerseProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Wallpaper preview card ──
        Card(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            height: 200,
            child: settings.lastWallpaperPath != null &&
                    File(settings.lastWallpaperPath!).existsSync()
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(settings.lastWallpaperPath!),
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: Text(
                          settings.statusPayload ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black87),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () {
                      if (settings.wallpaperPermissionGranted) {
                        settings.triggerNow(
                          verseProvider: verseProvider,
                          locale:
                              context.read<LocaleProvider>().locale.languageCode,
                        );
                      }
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wallpaper_outlined,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.5),
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
        ),

        const SizedBox(height: 16),

        // ── Change now button ──
        SizedBox(
          width: double.infinity,
          child: AsyncActionButton(
            icon: Icons.refresh,
            label: l10n.changeNow,
            style: AsyncActionButtonStyle.filled,
            onPressed: () async {
              if (!settings.wallpaperPermissionGranted) {
                _showPermissionDialog(context, settings, verseProvider, l10n);
              } else {
                await settings.triggerNow(
                  verseProvider: verseProvider,
                  locale:
                      context.read<LocaleProvider>().locale.languageCode,
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
            },
          ),
        ),

        const SizedBox(height: 24),

        // ── Status section ──
        _SectionHeader(
          title: l10n.sectionScheduling,
          subtitle: l10n.sectionSchedulingSub,
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(settings.isEnabled
              ? '${l10n.autoChange}: ${_formatMinutes(settings.frequencyMinutes, l10n)}'
              : l10n.autoChange),
          subtitle: Text(
              settings.isEnabled ? l10n.sectionSchedulingSub : 'Desactivado'),
          trailing: Switch(
            value: settings.isEnabled,
            onChanged: (v) => settings.setEnabled(v),
          ),
        ),

        // Active categories
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(l10n.categoriesLabel),
          subtitle: Text('${settings.activeCategoryIds.length} activas'),
        ),

        // Language
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          subtitle: Text(
            locale == 'es'
                ? l10n.spanish
                : locale == 'pt'
                    ? l10n.portuguese
                    : 'English',
          ),
          onTap: () {
            final localeProvider = context.read<LocaleProvider>();
            final newLocale = localeProvider.locale.languageCode == 'es'
                ? const Locale('pt')
                : const Locale('es');
            localeProvider.setLocale(newLocale);
          },
        ),

        const SizedBox(height: 8),

        // ── About ──
        _SectionHeader(
          title: l10n.sectionAbout,
          subtitle: l10n.aboutDescription,
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(_appVersion),
        ),
        ListTile(
          leading: const Icon(Icons.share),
          title: Text(l10n.aboutShare),
          onTap: () {
            Share.share(
              'Descargá Vers Reminder: '
              'https://github.com/meolivares06/vers-reminder/releases/latest',
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('meolivares06@gmail.com'),
          subtitle: Text(l10n.aboutContact),
          onTap: () {
            Clipboard.setData(
              const ClipboardData(text: 'meolivares06@gmail.com'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email copiado al portapapeles'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  String _formatMinutes(int minutes, AppLocalizations l10n) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    return '$h ${h == 1 ? 'hora' : 'horas'}';
  }

  void _showPermissionDialog(
    BuildContext context,
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
                locale:
                    context.read<LocaleProvider>().locale.languageCode,
              );
            },
            child: Text(l10n.changeNow),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
