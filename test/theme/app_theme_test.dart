import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vers_reminder/theme/app_theme.dart';

/// Files touched by the Batch A theme change — the surfaces this change is
/// responsible for keeping free of raw error literals (UX-THEME-004 / F9).
const List<String> _batchAEditableFiles = [
  'lib/main.dart',
  'lib/widgets/verse_tile.dart',
  'lib/screens/settings/settings_screen.dart',
  'lib/screens/home_screen.dart',
  'lib/widgets/async_action_button.dart',
];

void main() {
  group('appSeedColor', () {
    test('is deepPurple (seed stays — F2 non-goal is no recolor)', () {
      expect(
        appSeedColor,
        Colors.deepPurple,
        reason: 'base seed must remain deepPurple',
      );
    });
  });

  group('goldAccent', () {
    test('is the documented gold brand color', () {
      expect(goldAccent, const Color(0xFFEFB14D));
    });
  });

  group('gold surface contrast', () {
    test('onGoldAccent clears WCAG AA on the gold brand surface', () {
      expect(
        _contrastRatio(goldAccent, onGoldAccent),
        greaterThanOrEqualTo(4.5),
        reason: 'the CTA foreground/background pair must meet WCAG AA',
      );
    });

    test(
      'near-white foreground fails on gold (why onPrimary is not reused)',
      () {
        expect(
          _contrastRatio(goldAccent, Colors.white),
          lessThan(4.5),
          reason: 'documents the contrast bug the onGoldAccent pair fixes',
        );
      },
    );
  });

  group('appLightTheme (UX-THEME-001/002)', () {
    test('is light and Material 3', () {
      final theme = appLightTheme();
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('secondary resolves to the gold accent (F2 additive)', () {
      expect(appLightTheme().colorScheme.secondary, goldAccent);
    });
  });

  group('appDarkTheme (UX-THEME-001/002)', () {
    test('is dark and Material 3', () {
      final theme = appDarkTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('secondary resolves to the gold accent (F2 additive)', () {
      expect(appDarkTheme().colorScheme.secondary, goldAccent);
    });
  });

  group('UX-THEME-002: shared source of truth, no scattered literals', () {
    test('no literal deepPurple scattered outside app_theme.dart', () {
      expect(
        grepLib(RegExp(r'Colors\.deepPurple')),
        ['lib/theme/app_theme.dart'],
        reason: 'the only deepPurple literal is the seed constant itself',
      );
    });
  });

  group(
    'UX-THEME-004 / F9: no raw Colors.red in the batch-touched surfaces',
    () {
      test('main, verse_tile, settings, home and CTA are Colors.red-free', () {
        final hits = grepFiles(RegExp(r'Colors\.red\b'), _batchAEditableFiles);
        expect(
          hits,
          isEmpty,
          reason: 'errors in these surfaces must resolve from the ColorScheme',
        );
      });
    },
  );
}

/// Files (relative to project root) under `lib/` whose content matches
/// [pattern]. Only excludes nothing — used for the deepPurple check, which
/// expects exactly [lib/theme/app_theme.dart].
List<String> grepLib(RegExp pattern) {
  final dir = Directory('lib');
  final hits = <String>[];
  void walk(Directory d) {
    for (final e in d.listSync()) {
      if (e is Directory) {
        walk(e);
      } else if (e is File && e.path.endsWith('.dart')) {
        if (pattern.hasMatch(e.readAsStringSync())) {
          // Normalize to forward slashes so the assertion is cross-platform.
          hits.add(e.path.replaceAll(r'\', '/'));
        }
      }
    }
  }

  walk(dir);
  hits.sort();
  return hits;
}

/// Relative paths of [files] whose content matches [pattern].
List<String> grepFiles(RegExp pattern, List<String> files) {
  final hits = <String>[];
  for (final path in files) {
    final f = File(path);
    if (f.existsSync() && pattern.hasMatch(f.readAsStringSync())) {
      hits.add(path);
    }
  }
  return hits;
}

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG relative luminance of an opaque color.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}
