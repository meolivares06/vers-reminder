import 'package:flutter_test/flutter_test.dart';
import 'package:vers_reminder/shared/domain/category.dart';

void main() {
  group('Category', () {
    test('fromMap/toMap roundtrip', () {
      final map = {
        'id': 1,
        'name': 'Salvación',
        'isSeed': 1,
      };
      final cat = Category.fromMap(map);
      expect(cat.id, 1);
      expect(cat.name, 'Salvación');
      expect(cat.isSeed, true);

      final outMap = cat.toMap();
      expect(outMap['name'], 'Salvación');
      expect(outMap['isSeed'], 1);
    });

    test('isSeed defaults to false', () {
      final cat = Category(name: 'Fe');
      expect(cat.isSeed, false);
    });

    test('toMap omits id when null', () {
      final cat = Category(name: 'Paz');
      final map = cat.toMap();
      expect(map.containsKey('id'), false);
    });

    test('copyWith', () {
      final cat = Category(id: 1, name: 'Fe', isSeed: true);
      final copy = cat.copyWith(name: 'Amor');
      expect(copy.id, 1);
      expect(copy.name, 'Amor');
      expect(copy.isSeed, true);
    });
  });
}
