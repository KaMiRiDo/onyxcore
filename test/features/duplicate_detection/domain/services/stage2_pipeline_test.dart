import 'dart:async';

import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_cluster.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage2_pipeline.dart';

class _FakeGenerator implements FingerprintGenerator {
  _FakeGenerator(this.fingerprints, {this.failingPaths = const {}});

  final Map<String, List<int>> fingerprints;
  final Set<String> failingPaths;
  final Map<String, int> callCounts = {};

  @override
  bool supports(ComparisonCandidate candidate) => true;

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) async {
    final path = candidate.file.path;
    callCounts[path] = (callCounts[path] ?? 0) + 1;

    if (failingPaths.contains(path)) {
      throw FingerprintGenerationException(path, 'corrupt file');
    }

    final bytes = fingerprints[path] ?? List.filled(32, 0);
    return CandidateFingerprint(candidatePath: path, bytes: bytes);
  }
}

ComparisonCandidate _makeCandidate(String path, {required bool isSource}) {
  return ComparisonCandidate(
    file: FileItem(
      path: path,
      name: path.split('/').last,
      type: FileItemType.image,
      modified: DateTime(2024),
      sizeBytes: 1000,
    ),
    isSource: isSource,
  );
}

void main() {
  group('Stage2Pipeline', () {
    const tRequest = ComparisonRequest(
      sourceFolder: '/source',
      destinationFolder: '/dest',
      category: ComparisonCategory.images,
    );

    const clusterKey = ClusterKey(
      type: FileItemType.image,
      orientation: MediaOrientation.landscape,
      aspectRatioGroup: '16:9',
    );

    test('matches identical candidates within paired clusters', () async {
      final src = _makeCandidate('/source/a.jpg', isSource: true);
      final dst = _makeCandidate('/dest/a_copy.jpg', isSource: false);

      final cluster = Stage1Cluster(
        key: clusterKey,
        sourceCandidates: [src],
        destinationCandidates: [dst],
      );
      final stage1Result = Stage1Result(
        pairs: [ClusterPair(cluster, cluster)],
        failures: const [],
      );

      final identicalBytes = List.filled(32, 0x55);
      final generator = _FakeGenerator({
        '/source/a.jpg': identicalBytes,
        '/dest/a_copy.jpg': identicalBytes,
      });

      final progressCtrl = StreamController<ComparisonProgress>.broadcast();
      final token = CancellationToken();
      final pipeline = Stage2Pipeline(generator: generator);

      final result = await pipeline.run(
        tRequest,
        stage1Result: stage1Result,
        progress: progressCtrl,
        token: token,
      );

      expect(result.matches.length, 1);
      final match = result.matches.first;
      expect(match.sourcePath, '/source/a.jpg');
      expect(match.matchCount, 1);
      expect(
        match.destinationMatches.first.destinationPath,
        '/dest/a_copy.jpg',
      );
      expect(match.destinationMatches.first.similarityScore, 1.0);
      expect(match.destinationMatches.first.matchType, MatchType.exact);
    });

    test(
      'supports one-to-many matching sorted by similarity descending',
      () async {
        final src = _makeCandidate('/source/hero.jpg', isSource: true);
        final dst1 = _makeCandidate('/dest/hero_exact.jpg', isSource: false);
        final dst2 = _makeCandidate(
          '/dest/hero_compressed.jpg',
          isSource: false,
        );

        final cluster = Stage1Cluster(
          key: clusterKey,
          sourceCandidates: [src],
          destinationCandidates: [dst1, dst2],
        );
        final stage1Result = Stage1Result(
          pairs: [ClusterPair(cluster, cluster)],
          failures: const [],
        );

        final srcBytes = List.filled(32, 0x00);
        final dst1Bytes = List.filled(32, 0x00); // 1.0 match
        final dst2Bytes = List.filled(32, 0x00)
          ..first = 0x01; // 1 bit diff (~0.996)

        final generator = _FakeGenerator({
          '/source/hero.jpg': srcBytes,
          '/dest/hero_exact.jpg': dst1Bytes,
          '/dest/hero_compressed.jpg': dst2Bytes,
        });

        final pipeline = Stage2Pipeline(generator: generator);

        final result = await pipeline.run(
          tRequest,
          stage1Result: stage1Result,
          progress: StreamController<ComparisonProgress>.broadcast(),
          token: CancellationToken(),
        );

        expect(result.matches.length, 1);
        final match = result.matches.first;
        expect(match.matchCount, 2);
        expect(
          match.destinationMatches[0].destinationPath,
          '/dest/hero_exact.jpg',
        );
        expect(match.destinationMatches[0].similarityScore, 1.0);
        expect(
          match.destinationMatches[1].destinationPath,
          '/dest/hero_compressed.jpg',
        );
        expect(
          match.destinationMatches[1].similarityScore,
          closeTo(0.996, 0.001),
        );
      },
    );

    test(
      'reuses fingerprint when candidate appears in multiple pairs',
      () async {
        final src = _makeCandidate('/source/shared.jpg', isSource: true);
        final dst1 = _makeCandidate('/dest/d1.jpg', isSource: false);
        final dst2 = _makeCandidate('/dest/d2.jpg', isSource: false);

        final clusterA = Stage1Cluster(
          key: clusterKey,
          sourceCandidates: [src],
          destinationCandidates: [dst1],
        );
        final clusterB = Stage1Cluster(
          key: clusterKey,
          sourceCandidates: [src],
          destinationCandidates: [dst2],
        );

        final stage1Result = Stage1Result(
          pairs: [
            ClusterPair(clusterA, clusterA),
            ClusterPair(clusterB, clusterB),
          ],
          failures: const [],
        );

        final generator = _FakeGenerator({
          '/source/shared.jpg': List.filled(32, 1),
          '/dest/d1.jpg': List.filled(32, 1),
          '/dest/d2.jpg': List.filled(32, 1),
        });

        final pipeline = Stage2Pipeline(generator: generator);

        await pipeline.run(
          tRequest,
          stage1Result: stage1Result,
          progress: StreamController<ComparisonProgress>.broadcast(),
          token: CancellationToken(),
        );

        // Verify source was fingerprinted at most once!
        expect(generator.callCounts['/source/shared.jpg'], 1);
      },
    );

    test(
      'recovers from individual candidate failures without aborting',
      () async {
        final src1 = _makeCandidate('/source/corrupt.jpg', isSource: true);
        final src2 = _makeCandidate('/source/good.jpg', isSource: true);
        final dst = _makeCandidate('/dest/good.jpg', isSource: false);

        final cluster = Stage1Cluster(
          key: clusterKey,
          sourceCandidates: [src1, src2],
          destinationCandidates: [dst],
        );
        final stage1Result = Stage1Result(
          pairs: [ClusterPair(cluster, cluster)],
          failures: const [],
        );

        final generator = _FakeGenerator(
          {
            '/source/good.jpg': List.filled(32, 7),
            '/dest/good.jpg': List.filled(32, 7),
          },
          failingPaths: {'/source/corrupt.jpg'},
        );

        final pipeline = Stage2Pipeline(generator: generator);

        final result = await pipeline.run(
          tRequest,
          stage1Result: stage1Result,
          progress: StreamController<ComparisonProgress>.broadcast(),
          token: CancellationToken(),
        );

        expect(result.matches.length, 1);
        expect(result.matches.first.sourcePath, '/source/good.jpg');
        expect(
          result.failures.any((f) => f.candidatePath == '/source/corrupt.jpg'),
          isTrue,
        );
      },
    );

    test('respects CancellationToken during execution', () async {
      final src = _makeCandidate('/source/a.jpg', isSource: true);
      final dst = _makeCandidate('/dest/a.jpg', isSource: false);

      final cluster = Stage1Cluster(
        key: clusterKey,
        sourceCandidates: [src],
        destinationCandidates: [dst],
      );
      final stage1Result = Stage1Result(
        pairs: [ClusterPair(cluster, cluster)],
        failures: const [],
      );

      final token = CancellationToken()..cancel(); // cancelled before start
      final progressCtrl = StreamController<ComparisonProgress>.broadcast();
      final events = <ComparisonProgress>[];
      progressCtrl.stream.listen(events.add);

      final pipeline = Stage2Pipeline(generator: _FakeGenerator({}));

      final result = await pipeline.run(
        tRequest,
        stage1Result: stage1Result,
        progress: progressCtrl,
        token: token,
      );

      expect(result.matches, isEmpty);
      expect(events.any((e) => e.status == ComparisonStatus.cancelled), isTrue);
    });
  });
}
