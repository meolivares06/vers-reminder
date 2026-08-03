import 'package:flutter/material.dart';

/// Single source of truth for the app's base seed color.
///
/// F2: the seed STAYS `deepPurple` — the gold brand identity is added via
/// [goldAccent] on [ColorScheme.secondary], never by recoloring the base.
const Color appSeedColor = Colors.deepPurple;

/// Additive brand accent used for low-risk active surfaces (primary CTA,
/// selected controls). Applied through [ColorScheme.secondary].
final Color goldAccent = const Color(0xFFEFB14D);

/// Light [ThemeData] built from the shared [appSeedColor] scheme.
ThemeData appLightTheme() => _base(Brightness.light);

/// Dark [ThemeData] built from the shared [appSeedColor] scheme.
ThemeData appDarkTheme() => _base(Brightness.dark);

ThemeData _base(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appSeedColor,
        brightness: brightness,
      ).copyWith(secondary: goldAccent),
      useMaterial3: true,
    );
