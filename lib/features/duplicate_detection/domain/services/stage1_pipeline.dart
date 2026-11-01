import 'dart:async';

import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/repositories/candidate_discovery_repository.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/cluster_pair_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_cluster_builder.dart';

class Stage1Pipeline {
  const Stage1Pipeline(this.discoveryRepository, this.strategyRegistry);

  final CandidateDiscoveryRepository discoveryRepository;
  final MediaStrategyRegistry strategyRegistry;

  Future<Stage1Result> run(
    ComparisonRequest request, {
    required StreamController<ComparisonProgress> progress,
    required CancellationToken token,
  }) async {
    final builder = Stage1ClusterBuilder();
    final failures = <Stage1Failure>[];

    progress.add(
      ComparisonProgress(
        requestId: request.sourceFolder,
        status: ComparisonStatus.discovering,
      ),
    );

    // 1. Discover Source
    await _discoverAndExtract(
      request.sourceFolder,
      request.category,
      request.recursive,
      true, // isSource
      builder,
      failures,
      token,
    );
    if (token.isCancelled) {
      return Stage1Result(pairs: const [], failures: failures);
    }

    // 2. Discover Dest (if different)
    if (request.sourceFolder != request.destinationFolder) {
      await _discoverAndExtract(
        request.destinationFolder,
        request.category,
        request.recursive,
        false, // isSource
        builder,
        failures,
        token,
      );
      if (token.isCancelled) {
        return Stage1Result(pairs: const [], failures: failures);
      }
    }

    // 3. Cluster and Pair
    final clusters = builder.build();
    final pairs = ClusterPairGenerator.generatePairs(clusters);

    return Stage1Result(pairs: pairs, failures: failures);
  }

  Future<void> _discoverAndExtract(
    String path,
    ComparisonCategory category,
    bool recursive,
    bool isSource,
    Stage1ClusterBuilder builder,
    List<Stage1Failure> failures,
    CancellationToken token,
  ) async {
    final stream = discoveryRepository.discover(
      folderPath: path,
      category: category,
      recursive: recursive,
      isSource: isSource,
    );

    await for (final candidate in stream) {
      if (token.isCancelled) return;

      try {
        final strategy = strategyRegistry.getStrategy(candidate);
        final meta = await strategy.extractMetadata(candidate);
        final key = strategy.buildClusterKey(candidate, meta);
        builder.add(candidate, key);
      } catch (e) {
        failures.add(Stage1Failure(candidate, e.toString()));
      }
    }
  }
}
