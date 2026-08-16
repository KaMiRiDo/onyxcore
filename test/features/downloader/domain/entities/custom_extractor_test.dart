import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';

void main() {
  group('CustomExtractor', () {
    test('supports value equality', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      final a = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'console.log();',
        createdAt: date,
        modifiedAt: date,
      );
      final b = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'console.log();',
        createdAt: date,
        modifiedAt: date,
      );
      expect(a, equals(b));
    });

    test('copyWith works', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      final a = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'console.log();',
        createdAt: date,
        modifiedAt: date,
      );
      final b = a.copyWith(name: 'new name');
      expect(b.name, 'new name');
      expect(b.id, '1');
    });

    test('toMap and fromMap work', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      final a = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'console.log();',
        createdAt: date,
        modifiedAt: date,
      );
      final map = a.toMap();
      final b = CustomExtractor.fromMap(map);
      expect(a, equals(b));
    });
  });
}
