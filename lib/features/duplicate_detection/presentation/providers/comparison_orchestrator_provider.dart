import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/duplicate_detection/data/repositories/local_candidate_discovery_repository.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/audio_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/other_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/video_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/composite_fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/default_comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_pipeline.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage2_pipeline.dart';

final comparisonOrchestratorProvider = Provider<ComparisonOrchestrator>((ref) {
  final discoveryRepo = LocalCandidateDiscoveryRepository();
  final strategies = <MediaTypeStrategy>[
    ImageMediaStrategy(),
    VideoMediaStrategy(),
    AudioMediaStrategy(),
    OtherMediaStrategy(),
  ];
  final registry = MediaStrategyRegistry(strategies);
  final stage1Pipeline = Stage1Pipeline(discoveryRepo, registry);

  final fingerprintGen = CompositeFingerprintGenerator(registry);
  final stage2Pipeline = Stage2Pipeline(generator: fingerprintGen);

  return DefaultComparisonOrchestrator(
    stage1Pipeline: stage1Pipeline,
    stage2Pipeline: stage2Pipeline,
  );
});
