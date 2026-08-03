// Asserts that the localization ARB files for en/es/pt expose the exact same
// set of translation keys. Prevents a string from shipping in one locale but
// silently falling back in another.
//
// Only the user-facing keys (non-metadata) are compared; entries whose key
// starts with '@' are FLUTTER/ARB metadata (descriptions, placeholders) and
// are ignored here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _localesPaths = <String, String>{
  'en': 'lib/l10n/app_en.arb',
  'es': 'lib/l10n/app_es.arb',
  'pt': 'lib/l10n/app_pt.arb',
};

/// Loads a given ARB file and returns the sorted list of plain (non-`@`)
/// translation keys it defines.
Set<String> _plainKeys(String locale) {
  final file = File(_localesPaths[locale]!);
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return json.keys
      .where((key) => !key.startsWith('@'))
      .toSet();
}

void main() {
  final keysByLocale = <String, Set<String>>{
    for (final entry in _localesPaths.entries) entry.key: _plainKeys(entry.key),
  };

  group('ARB key parity', () {
    test('en, es and pt expose identical key sets', () {
      final reference = keysByLocale['en']!;
      for (final locale in ['es', 'pt']) {
        expect(
          keysByLocale[locale],
          reference,
          reason: '$locale ARB must define exactly the same keys as en',
        );
      }
    });

    test('supports every ui-ux-review batch key in all locales', () {
      const expectedKeys = <String>{
        'activeCategoriesCount', // UX-HOME-003
        'shareApp', // UX-HOME-004
        'emailCopied', // UX-HOME-004
        'currentWallpaperLabel', // UX-SET-003 / UX-HOME-001
        'previewLabel', // UX-SET-003
        'updatedAtLabel', // UX-HOME-001
        'offsetLabel', // UX-SET-002
        'timeMinutes', // UX-HOME-004
        'timeHours', // UX-HOME-004
        'disabledLabel',
      };
      for (final locale in keysByLocale.keys) {
        final keys = keysByLocale[locale]!;
        for (final key in expectedKeys) {
          expect(keys, contains(key),
              reason: '$locale ARB must define "$key"');
        }
      }
    });
  });
}