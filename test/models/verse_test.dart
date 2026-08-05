import 'package:flutter_test/flutter_test.dart';
import 'package:vers_reminder/verses/domain/verse.dart';

void main() {
  group('Verse', () {
    test('fromMap/toMap roundtrip', () {
      final map = {
        'id': 1,
        'textEs': 'Porque de tal manera amó Dios al mundo',
        'textPt': 'Porque Deus amou o mundo de tal maneira',
        'citation': 'Juan 3:16',
        'createdAt': '2026-07-29T10:00:00.000',
      };
      final verse = Verse.fromMap(map);
      expect(verse.id, 1);
      expect(verse.textEs, 'Porque de tal manera amó Dios al mundo');
      expect(verse.textPt, 'Porque Deus amou o mundo de tal maneira');
      expect(verse.citation, 'Juan 3:16');
      expect(verse.createdAt, DateTime(2026, 7, 29, 10, 0));

      final outMap = verse.toMap();
      expect(outMap['id'], 1);
      expect(outMap['textEs'], map['textEs']);
      expect(outMap['textPt'], map['textPt']);
    });

    test('fromMap handles null textPt', () {
      final map = {
        'textEs': 'El que cree en el Hijo tiene vida eterna',
        'textPt': null,
        'citation': 'Juan 3:36',
        'createdAt': '2026-07-29T10:00:00.000',
      };
      final verse = Verse.fromMap(map);
      expect(verse.textPt, isNull);
    });

    test('toMap omits id when null', () {
      final verse = Verse(
        textEs: 'Test',
        citation: 'Test 1:1',
      );
      final map = verse.toMap();
      expect(map.containsKey('id'), false);
    });

    test('copyWith preserves unset fields', () {
      final verse = Verse(
        id: 1,
        textEs: 'Original',
        citation: 'Orig 1:1',
      );
      final copy = verse.copyWith(textEs: 'Modificado');
      expect(copy.id, 1);
      expect(copy.textEs, 'Modificado');
      expect(copy.citation, 'Orig 1:1');
    });

    group('textFor', () {
      test('UX-HOME-005 returns textPt when locale is pt and textPt non-empty',
          () {
        final verse = Verse(
          textEs: 'Texto en ES',
          textPt: 'Texto em PT',
          citation: 'Juan 3:16',
        );
        expect(verse.textFor('pt'), 'Texto em PT');
      });

      test('UX-HOME-005 falls back to textEs when locale is pt and textPt null',
          () {
        final verse = Verse(
          textEs: 'Texto en ES',
          textPt: null,
          citation: 'Juan 3:16',
        );
        expect(verse.textFor('pt'), 'Texto en ES',
            reason: 'null textPt must not render an empty string');
      });

      test('UX-HOME-005 falls back to textEs when locale is pt and textPt empty',
          () {
        final verse = Verse(
          textEs: 'Texto en ES',
          textPt: '',
          citation: 'Juan 3:16',
        );
        expect(verse.textFor('pt'), 'Texto en ES',
            reason: 'empty textPt must not render an empty string');
      });

      test('UX-HOME-005 returns textEs for es locale', () {
        final verse = Verse(
          textEs: 'Texto en ES',
          textPt: 'Texto em PT',
          citation: 'Juan 3:16',
        );
        expect(verse.textFor('es'), 'Texto en ES');
      });

      test('UX-HOME-005 returns textEs for non-pt/non-es locales (e.g. en)',
          () {
        final verse = Verse(
          textEs: 'Texto en ES',
          textPt: 'Texto em PT',
          citation: 'Juan 3:16',
        );
        expect(verse.textFor('en'), 'Texto en ES',
            reason: 'no textEn field — other locales fall back to Spanish');
      });
    });
  });
}
