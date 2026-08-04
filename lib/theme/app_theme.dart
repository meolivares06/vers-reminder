import 'package:flutter/material.dart';

/// Single source of truth for the app's base seed color.
///
/// The seed STAYS `deepPurple` — the gold brand identity is added via
/// [goldAccent] on [ColorScheme.secondary], never by recoloring the base.
const Color appSeedColor = Colors.deepPurple;

/// Additive brand accent used for low-risk active surfaces (primary CTA,
/// selected controls). Applied through [ColorScheme.secondary].
const Color goldAccent = Color(0xFFEFB14D);

/// Foreground for the gold brand surface ([goldAccent] via
/// [ColorScheme.secondary]).
///
/// A fixed, opaque dark tone: the gold surface is identical in both themes,
/// so a single foreground clears WCAG AA (>= 4.5:1) everywhere, including
/// light mode where the scheme's `onSecondary` is near-white.
const Color onGoldAccent = Color(0xFF2B1F0E);

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
