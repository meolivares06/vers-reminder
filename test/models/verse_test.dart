import 'package:flutter_test/flutter_test.dart';
import 'package:vers_reminder/models/verse.dart';

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
  });
}
