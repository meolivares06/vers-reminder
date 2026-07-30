import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/settings_provider.dart';
import 'providers/verse_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/home_screen.dart';
import 'services/wallpaper_scheduler.dart';
import 'services/image_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cache screen dimensions (physical pixels) for wallpaper output sizing.
  // Using physical pixels ensures Android displays the wallpaper 1:1
  // without any scaling or cropping that would shift centered content.
  //
  // Version 2: physical pixels. Version 1: logical pixels (deprecated).
  // When the version changes, old cached values are invalidated.
  const currentDimVersion = 2;
  final prefs = await SharedPreferences.getInstance();

  final cachedVersion = prefs.getInt('screen_dim_version');
  if (cachedVersion != currentDimVersion) {
    // Clear stale dimensions and re-cache
    await prefs.remove('screen_width');
    await prefs.remove('screen_height');
    await prefs.setInt('screen_dim_version', currentDimVersion);
  }

  if (!prefs.containsKey('screen_width')) {
    final view = ui.PlatformDispatcher.instance.views.first;
    final screenWidth = view.physicalSize.width.round();
    final screenHeight = view.physicalSize.height.round();
    await prefs.setInt('screen_width', screenWidth);
    await prefs.setInt('screen_height', screenHeight);
  }

  await ImageCacheService.instance.init();
  await WallpaperScheduler.init();
  runApp(const VersReminderApp());
}

class VersReminderApp extends StatelessWidget {
  const VersReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VerseProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'Vers Reminder',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            locale: localeProvider.isInitialized
                ? localeProvider.locale
                : null,
            supportedLocales: const [
              Locale('es'),
              Locale('pt'),
              Locale('en'),
            ],
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            home: AppEntry(),
          );
        },
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final localeProvider = context.read<LocaleProvider>();
    await localeProvider.init();

    final verseProvider = context.read<VerseProvider>();
    await verseProvider.init(locale: localeProvider.locale.languageCode);

    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.init();
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final verseProvider = context.watch<VerseProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    if (!localeProvider.isInitialized ||
        verseProvider.isLoading ||
        settingsProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return HomeScreen();
  }
}
