import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _ImageMediaTypeStrategy extends Fake implements MediaTypeStrategy {
  @override
  bool supports(ComparisonCandidate candidate) =>
      candidate.file.type == FileItemType.image;

  @override
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate) async {
    return Stage1Metadata(
      candidatePath: candidate.file.path,
      orientation: MediaOrientation.landscape,
      aspectRatioGroup: '16:9',
    );
  }

  @override
  ClusterKey buildClusterKey(
    ComparisonCandidate candidate,
    Stage1Metadata metadata,
  ) {
    return ClusterKey.fromMetadata(candidate.file.type, metadata);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final tModified = DateTime(2024, 6, 15);

  final imageCandidate = ComparisonCandidate(
    file: FileItem(
      path: '/source/photo.jpg',
      name: 'photo.jpg',
      type: FileItemType.image,
      sizeBytes: 2048,
      modified: tModified,
    ),
    isSource: true,
  );

  final videoCandidate = ComparisonCandidate(
    file: FileItem(
      path: '/source/clip.mp4',
      name: 'clip.mp4',
      type: FileItemType.video,
      sizeBytes: 102400,
      modified: tModified,
    ),
    isSource: true,
  );

  group('MediaTypeStrategy contract', () {
    late _ImageMediaTypeStrategy strategy;

    setUp(() {
      strategy = _ImageMediaTypeStrategy();
    });

    test('supports returns true for the matching media type', () {
      expect(strategy.supports(imageCandidate), isTrue);
    });

    test('supports returns false for a non-matching media type', () {
      expect(strategy.supports(videoCandidate), isFalse);
    });

    test(
      'extractMetadata returns Stage1Metadata for a supported candidate',
      () async {
        final meta = await strategy.extractMetadata(imageCandidate);
        expect(meta.candidatePath, imageCandidate.file.path);
        expect(meta.orientation, MediaOrientation.landscape);
      },
    );

    test('buildClusterKey produces a ClusterKey from metadata', () async {
      final meta = await strategy.extractMetadata(imageCandidate);
      final key = strategy.buildClusterKey(imageCandidate, meta);
      expect(key.type, FileItemType.image);
      expect(key.orientation, MediaOrientation.landscape);
      expect(key.aspectRatioGroup, '16:9');
    });

    test('same metadata produces deterministic cluster key', () async {
      final meta = await strategy.extractMetadata(imageCandidate);
      final key1 = strategy.buildClusterKey(imageCandidate, meta);
      final key2 = strategy.buildClusterKey(imageCandidate, meta);
      expect(key1, equals(key2));
    });

    test('multiple strategies can coexist — each handles its own type', () {
      // This test ensures the strategy boundary supports polymorphism.
      final strategies = <MediaTypeStrategy>[_ImageMediaTypeStrategy()];

      // Only one strategy handles image candidates
      final handlers = strategies
          .where((s) => s.supports(imageCandidate))
          .toList();
      expect(handlers.length, 1);

      // No strategy handles video (not registered in this test)
      final videoHandlers = strategies
          .where((s) => s.supports(videoCandidate))
          .toList();
      expect(videoHandlers, isEmpty);
    });
  });
}
