import 'dart:async';

import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/repositories/candidate_discovery_repository.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/default_comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_pipeline.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage2_pipeline.dart';

class _FakeDiscoveryRepository implements CandidateDiscoveryRepository {
  _FakeDiscoveryRepository(this.candidates);
  final List<ComparisonCandidate> candidates;

  @override
  Stream<ComparisonCandidate> discover({
    required String folderPath,
    required ComparisonCategory category,
    required bool recursive,
    required bool isSource,
  }) {
    return Stream.fromIterable(candidates.where((c) => c.isSource == isSource));
  }
}

void main() {
  group('DefaultComparisonOrchestrator', () {
    const tRequest = ComparisonRequest(
      sourceFolder: '/source',
      destinationFolder: '/dest',
      category: ComparisonCategory.images,
    );

    test(
      'orchestrates full Stage 1 + Stage 2 lifecycle and emits progress events',
      () async {
        final imgStrategy = ImageMediaStrategy();
        final registry = MediaStrategyRegistry([imgStrategy]);

        // We'll provide two candidates with known mockable paths
        final candidateSource = ComparisonCandidate(
          file: FileItem(
            path: '/source/a.jpg',
            name: 'a.jpg',
            type: FileItemType.image,
            modified: DateTime(2024),
            sizeBytes: 100,
          ),
          isSource: true,
        );
        final candidateDest = ComparisonCandidate(
          file: FileItem(
            path: '/dest/a.jpg',
            name: 'a.jpg',
            type: FileItemType.image,
            modified: DateTime(2024),
            sizeBytes: 100,
          ),
          isSource: false,
        );

        final discovery = _FakeDiscoveryRepository([
          candidateSource,
          candidateDest,
        ]);
        final stage1 = Stage1Pipeline(discovery, registry);

        // Stage2 with custom fake generator producing matching bytes
        final stage2 = Stage2Pipeline(generator: _FakeFingerprintGen());

        final orchestrator = DefaultComparisonOrchestrator(
          stage1Pipeline: stage1,
          stage2Pipeline: stage2,
        );

        final progressCtrl = StreamController<ComparisonProgress>.broadcast();
        final events = <ComparisonProgress>[];
        progressCtrl.stream.listen(events.add);

        final token = CancellationToken();
        final result = await orchestrator.run(
          tRequest,
          progress: progressCtrl,
          token: token,
        );

        await progressCtrl.close();

        expect(result.requestId, '/source');
        expect(result.matches.length, 1);
        expect(
          events.map((e) => e.status),
          contains(ComparisonStatus.discovering),
        );
        expect(
          events.map((e) => e.status),
          contains(ComparisonStatus.completed),
        );
      },
    );

    test(
      'aborts cleanly and emits cancelled event when token is cancelled',
      () async {
        final imgStrategy = ImageMediaStrategy();
        final registry = MediaStrategyRegistry([imgStrategy]);
        final discovery = _FakeDiscoveryRepository([]);
        final stage1 = Stage1Pipeline(discovery, registry);
        final stage2 = Stage2Pipeline(generator: _FakeFingerprintGen());

        final orchestrator = DefaultComparisonOrchestrator(
          stage1Pipeline: stage1,
          stage2Pipeline: stage2,
        );

        final progressCtrl = StreamController<ComparisonProgress>.broadcast();
        final events = <ComparisonProgress>[];
        progressCtrl.stream.listen(events.add);

        final token = CancellationToken()..cancel();
        final result = await orchestrator.run(
          tRequest,
          progress: progressCtrl,
          token: token,
        );
        await progressCtrl.close();

        expect(result.isEmpty, isTrue);
        expect(
          events.any((e) => e.status == ComparisonStatus.cancelled),
          isTrue,
        );
      },
    );
  });
}

class _FakeFingerprintGen implements FingerprintGenerator {
  @override
  bool supports(ComparisonCandidate candidate) => true;

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) async {
    return CandidateFingerprint(
      candidatePath: candidate.file.path,
      bytes: List.filled(32, 0x99),
    );
  }
}
