import 'dart:async';

import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_pipeline.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage2_pipeline.dart';

/// Top-level comparison orchestrator driving Stage 1 and Stage 2 pipelines.
class DefaultComparisonOrchestrator implements ComparisonOrchestrator {
  const DefaultComparisonOrchestrator({
    required this.stage1Pipeline,
    required this.stage2Pipeline,
  });

  final Stage1Pipeline stage1Pipeline;
  final Stage2Pipeline stage2Pipeline;

  @override
  Future<ComparisonResult> run(
    ComparisonRequest request, {
    required StreamController<ComparisonProgress> progress,
    required CancellationToken token,
  }) async {
    if (token.isCancelled) {
      progress.add(ComparisonProgress.cancelled(request.sourceFolder));
      return ComparisonResult(
        requestId: request.sourceFolder,
        matches: const [],
        totalSourceCandidates: 0,
        totalDestinationCandidates: 0,
        completedAt: DateTime.now(),
      );
    }

    try {
      // 1. Run Stage 1 (Discovery, Metadata extraction, Clustering, Pairing)
      final stage1Result = await stage1Pipeline.run(
        request,
        progress: progress,
        token: token,
      );

      if (token.isCancelled) {
        progress.add(ComparisonProgress.cancelled(request.sourceFolder));
        return ComparisonResult(
          requestId: request.sourceFolder,
          matches: const [],
          totalSourceCandidates: 0,
          totalDestinationCandidates: 0,
          completedAt: DateTime.now(),
        );
      }

      // 2. Run Stage 2 (Fingerprinting, In-memory comparison, Match aggregation)
      final result = await stage2Pipeline.run(
        request,
        stage1Result: stage1Result,
        progress: progress,
        token: token,
      );

      return result;
    } catch (e) {
      if (e is ComparisonOrchestratorException) rethrow;
      progress.add(
        ComparisonProgress.failed(request.sourceFolder, e.toString()),
      );
      throw ComparisonOrchestratorException(request.sourceFolder, e.toString());
    }
  }
}
