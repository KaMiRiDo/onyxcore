import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/repositories/candidate_discovery_repository.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_pipeline.dart';

class MockDiscoveryRepo implements CandidateDiscoveryRepository {
  List<ComparisonCandidate> candidates = [];
  @override
  Stream<ComparisonCandidate> discover({
    required String folderPath,
    required ComparisonCategory category,
    required bool recursive,
    required bool isSource,
  }) async* {
    for (final c in candidates) {
      if (c.isSource == isSource) yield c;
    }
  }
}

class MockStrategy implements MediaTypeStrategy {
  @override
  bool supports(ComparisonCandidate candidate) => true;

  @override
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate) async {
    return Stage1Metadata(
      candidatePath: candidate.file.path,
      orientation: MediaOrientation.landscape,
      aspectRatioGroup: 'ar10',
      durationSeconds: 10,
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

void main() {
  group('Stage1Pipeline', () {
    test('runs discovery, extraction, clustering and pairing', () async {
      final repo = MockDiscoveryRepo()
        ..candidates = [
          ComparisonCandidate(
            file: FileItem(
              path: 's1',
              name: 's1',
              type: FileItemType.image,
              modified: DateTime.now(),
              sizeBytes: 1,
            ),
            isSource: true,
          ),
          ComparisonCandidate(
            file: FileItem(
              path: 'd1',
              name: 'd1',
              type: FileItemType.image,
              modified: DateTime.now(),
              sizeBytes: 1,
            ),
            isSource: false,
          ),
        ];
      final registry = MediaStrategyRegistry([MockStrategy()]);
      final pipeline = Stage1Pipeline(repo, registry);

      const req = ComparisonRequest(
        sourceFolder: 's',
        destinationFolder: 'd',
        category: ComparisonCategory.images,
      );
      final streamController = StreamController<ComparisonProgress>();
      final token = CancellationToken();

      final result = await pipeline.run(
        req,
        progress: streamController,
        token: token,
      );

      expect(result.pairs.length, 1);
      expect(result.failures.length, 0);
      expect(result.pairs.first.clusterA.sourceCandidates.length, 1);
      expect(result.pairs.first.clusterB.destinationCandidates.length, 1);
    });

    test('cancels gracefully', () async {
      final repo = MockDiscoveryRepo()
        ..candidates = [
          ComparisonCandidate(
            file: FileItem(
              path: 's1',
              name: 's1',
              type: FileItemType.image,
              modified: DateTime.now(),
              sizeBytes: 1,
            ),
            isSource: true,
          ),
        ];
      final registry = MediaStrategyRegistry([MockStrategy()]);
      final pipeline = Stage1Pipeline(repo, registry);

      const req = ComparisonRequest(
        sourceFolder: 's',
        destinationFolder: 'd',
        category: ComparisonCategory.images,
      );
      final streamController = StreamController<ComparisonProgress>();
      final token = CancellationToken()..cancel();

      final result = await pipeline.run(
        req,
        progress: streamController,
        token: token,
      );

      expect(result.pairs.length, 0); // aborted early
    });
  });
}
