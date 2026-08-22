import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';

void main() {
  group('CustomExtractor', () {
    // ── Existing Phase 1 tests (regression) ─────────────────────────────────

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

    // ── Phase 2: metadata field ──────────────────────────────────────────────

    test('metadata defaults to null for script extractors', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      final extractor = CustomExtractor(
        id: '1',
        name: 'Script Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: date,
        modifiedAt: date,
      );
      expect(extractor.metadata, isNull);
    });

    test('accepts a metadata string for default extractors', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      const metadata =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final extractor = CustomExtractor(
        id: '1',
        name: 'HTML Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: date,
        modifiedAt: date,
        metadata: metadata,
      );
      expect(extractor.metadata, metadata);
    });

    test('copyWith preserves metadata when not overridden', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      const metadata = '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final a = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: metadata,
      );
      final b = a.copyWith(name: 'new name');
      expect(b.metadata, metadata);
    });

    test('copyWith can override metadata', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      const metadata = '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final a = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: metadata,
      );
      final b = a.copyWith(metadata: null);
      expect(b.metadata, isNull);
    });

    test('toMap includes metadata when present', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      const metadata =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final extractor = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: metadata,
      );
      final map = extractor.toMap();
      expect(map['metadata'], metadata);
    });

    test('toMap omits metadata key when null (Phase 1 compat)', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      final extractor = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
      );
      final map = extractor.toMap();
      expect(map.containsKey('metadata'), isFalse);
    });

    test('fromMap restores metadata', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      const metadata =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final original = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: metadata,
      );
      final restored = CustomExtractor.fromMap(original.toMap());
      expect(restored.metadata, metadata);
    });

    test('fromMap treats missing metadata key as null (Phase 1 compat)', () {
      final map = <String, dynamic>{
        'id': '1',
        'name': 'test',
        'script': 'script',
        'createdAt': 1000,
        'modifiedAt': 1000,
        // no 'metadata' key
      };
      final extractor = CustomExtractor.fromMap(map);
      expect(extractor.metadata, isNull);
    });

    test('fromMap treats explicit null metadata as null', () {
      final map = <String, dynamic>{
        'id': '1',
        'name': 'test',
        'script': 'script',
        'createdAt': 1000,
        'modifiedAt': 1000,
        'metadata': null,
      };
      final extractor = CustomExtractor.fromMap(map);
      expect(extractor.metadata, isNull);
    });

    test('equality considers metadata — equal when both have same metadata', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      const meta =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final a = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: meta,
      );
      final b = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: meta,
      );
      expect(a, equals(b));
    });

    test('equality considers metadata — not equal when metadata differs', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1000);
      final withMeta = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
        metadata: '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}',
      );
      final withoutMeta = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'script',
        createdAt: date,
        modifiedAt: date,
      );
      expect(withMeta, isNot(equals(withoutMeta)));
    });
  });
}
