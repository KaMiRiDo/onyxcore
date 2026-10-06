import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_extractor.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeStage1Extractor extends Fake implements Stage1Extractor {

  _FakeStage1Extractor({required bool supports, Stage1Metadata? result})
    : _supports = supports,
      _result = result;
  final bool _supports;
  final Stage1Metadata? _result;

  @override
  bool supports(ComparisonCandidate candidate) => _supports;

  @override
  Future<Stage1Metadata> extract(ComparisonCandidate candidate) async {
    if (_result != null) return _result;
    throw Stage1ExtractionException(candidate.file.path, 'extraction failed');
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  final tModified = DateTime(2024, 6, 15);

  final tCandidate = ComparisonCandidate(
    file: FileItem(
      path: '/source/photo.jpg',
      name: 'photo.jpg',
      type: FileItemType.image,
      sizeBytes: 2048,
      modified: tModified,
    ),
    isSource: true,
  );

  const tMetadata = Stage1Metadata(
    candidatePath: '/source/photo.jpg',
    orientation: MediaOrientation.landscape,
    aspectRatioGroup: '16:9',
  );

  group('Stage1Extractor contract', () {
    test('supports returns true for supported candidate', () {
      final extractor = _FakeStage1Extractor(supports: true, result: tMetadata);
      expect(extractor.supports(tCandidate), isTrue);
    });

    test('supports returns false for unsupported candidate', () {
      final extractor = _FakeStage1Extractor(supports: false);
      expect(extractor.supports(tCandidate), isFalse);
    });

    test('extract returns Stage1Metadata for a supported candidate', () async {
      final extractor = _FakeStage1Extractor(supports: true, result: tMetadata);
      final result = await extractor.extract(tCandidate);
      expect(result, equals(tMetadata));
    });

    test('extract throws Stage1ExtractionException on failure', () async {
      final extractor = _FakeStage1Extractor(supports: true);
      expect(
        () => extractor.extract(tCandidate),
        throwsA(isA<Stage1ExtractionException>()),
      );
    });

    test('Stage1ExtractionException carries candidatePath and message', () {
      const ex = Stage1ExtractionException('/photo.jpg', 'cannot read header');
      expect(ex.candidatePath, '/photo.jpg');
      expect(ex.message, 'cannot read header');
      expect(ex.toString(), contains('/photo.jpg'));
      expect(ex.toString(), contains('cannot read header'));
    });
  });
}
