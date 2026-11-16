import 'dart:async';

import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_threshold_config.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_cache.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_comparator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/hamming_fingerprint_comparator.dart';

/// Stage 2 of the cross-folder duplicate detection pipeline.
///
/// Consumes candidate cluster pairs from Stage 1, generates 256-bit fingerprints,
/// compares fingerprints in-memory, and aggregates cross-folder duplicate matches.
class Stage2Pipeline {
  const Stage2Pipeline({
    required this.generator,
    this.comparator = const HammingFingerprintComparator(),
    this.thresholdConfig = const ComparisonThresholdConfig(),
    this.concurrency = 4,
  });

  final FingerprintGenerator generator;
  final FingerprintComparator comparator;
  final ComparisonThresholdConfig thresholdConfig;
  final int concurrency;

  Future<ComparisonResult> run(
    ComparisonRequest request, {
    required Stage1Result stage1Result,
    required StreamController<ComparisonProgress> progress,
    required CancellationToken token,
  }) async {
    final cache = FingerprintCache();
    final failures = <ComparisonFailure>[
      for (final f in stage1Result.failures)
        ComparisonFailure(candidatePath: f.candidate.file.path, error: f.error),
    ];

    if (token.isCancelled) {
      progress.add(ComparisonProgress.cancelled(request.sourceFolder));
      return ComparisonResult(
        requestId: request.sourceFolder,
        matches: const [],
        totalSourceCandidates: 0,
        totalDestinationCandidates: 0,
        completedAt: DateTime.now(),
        failures: failures,
      );
    }

    try {
      // 1. Collect all unique candidates from pairs
      final sourceCandidateMap = <String, ComparisonCandidate>{};
      final destCandidateMap = <String, ComparisonCandidate>{};

      for (final pair in stage1Result.pairs) {
        for (final s in pair.clusterA.sourceCandidates) {
          sourceCandidateMap[s.file.path] = s;
        }
        for (final d in pair.clusterA.destinationCandidates) {
          destCandidateMap[d.file.path] = d;
        }
        for (final s in pair.clusterB.sourceCandidates) {
          sourceCandidateMap[s.file.path] = s;
        }
        for (final d in pair.clusterB.destinationCandidates) {
          destCandidateMap[d.file.path] = d;
        }
      }

      final totalSources = sourceCandidateMap.length;
      final totalDests = destCandidateMap.length;
      final allUniqueCandidates = <String, ComparisonCandidate>{
        ...sourceCandidateMap,
        ...destCandidateMap,
      };
      final totalUniqueCandidates = allUniqueCandidates.length;

      progress.add(
        ComparisonProgress(
          requestId: request.sourceFolder,
          status: ComparisonStatus.fingerprinting,
          totalFiles: totalUniqueCandidates,
          currentStageLabel: 'Generating 256-bit fingerprints',
        ),
      );

      final matchedPairsMap = <String, Map<String, MatchedPair>>{};
      var processedCandidateCount = 0;
      final failedPaths = <String>{};

      // 2. Pre-generate fingerprints concurrently up-front in chunks of `concurrency`
      final candidateList = allUniqueCandidates.values.toList();
      final poolSize = concurrency.clamp(1, 16);

      for (var i = 0; i < candidateList.length; i += poolSize) {
        if (token.isCancelled) break;
        final chunk = candidateList.sublist(
          i,
          (i + poolSize).clamp(0, candidateList.length),
        );
        await Future.wait(
          chunk.map((candidate) async {
            if (token.isCancelled) return;
            try {
              await cache.getOrGenerate(candidate, generator);
            } catch (e) {
              failedPaths.add(candidate.file.path);
              failures.add(
                ComparisonFailure(
                  candidatePath: candidate.file.path,
                  error: e.toString(),
                ),
              );
            }
          }),
        );

        processedCandidateCount += chunk.length;
        progress.add(
          ComparisonProgress(
            requestId: request.sourceFolder,
            status: ComparisonStatus.fingerprinting,
            totalFiles: totalUniqueCandidates,
            processedFiles: processedCandidateCount,
            currentStageLabel: 'Generating 256-bit fingerprints',
          ),
        );
        // Yield to event loop so UI animations and loader can paint smoothly
        await Future<void>.delayed(Duration.zero);
      }

      // 3. Iterate pairs and compare compatible source and destination files in-memory
      progress.add(
        ComparisonProgress(
          requestId: request.sourceFolder,
          status: ComparisonStatus.comparing,
          totalFiles: totalUniqueCandidates,
          processedFiles: processedCandidateCount,
          currentStageLabel: 'Comparing fingerprints',
        ),
      );

      void comparePair(ComparisonCandidate source, ComparisonCandidate dest) {
        // Prevent self-matching when source and destination point to identical path
        if (source.file.path == dest.file.path) return;
        if (failedPaths.contains(source.file.path) ||
            failedPaths.contains(dest.file.path)) {
          return;
        }

        final fpSource = cache.get(source.file.path);
        final fpDest = cache.get(dest.file.path);
        if (fpSource == null || fpDest == null) return;

        final score = comparator.compare(fpSource, fpDest);
        final threshold = thresholdConfig.thresholdFor(source.file.type);

        if (score >= threshold) {
          final matchType = score >= 1.0
              ? MatchType.exact
              : MatchType.perceptual;
          final matchedPair = MatchedPair(
            sourcePath: source.file.path,
            destinationPath: dest.file.path,
            similarityScore: score,
            matchType: matchType,
          );

          matchedPairsMap.putIfAbsent(
            source.file.path,
            () => {},
          )[dest.file.path] = matchedPair;
        }
      }

      for (final pair in stage1Result.pairs) {
        if (token.isCancelled) break;

        if (identical(pair.clusterA, pair.clusterB)) {
          for (final s in pair.clusterA.sourceCandidates) {
            for (final d in pair.clusterA.destinationCandidates) {
              comparePair(s, d);
            }
          }
        } else {
          for (final s in pair.clusterA.sourceCandidates) {
            for (final d in pair.clusterB.destinationCandidates) {
              comparePair(s, d);
            }
          }
          for (final s in pair.clusterB.sourceCandidates) {
            for (final d in pair.clusterA.destinationCandidates) {
              comparePair(s, d);
            }
          }
        }
      }

      if (token.isCancelled) {
        progress.add(ComparisonProgress.cancelled(request.sourceFolder));
        return ComparisonResult(
          requestId: request.sourceFolder,
          matches: const [],
          totalSourceCandidates: totalSources,
          totalDestinationCandidates: totalDests,
          completedAt: DateTime.now(),
          failures: failures,
        );
      }

      // 3. Aggregate matches
      final duplicateMatches = <DuplicateMatch>[];
      for (final entry in matchedPairsMap.entries) {
        final destList = entry.value.values.toList()
          ..sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

        duplicateMatches.add(
          DuplicateMatch(
            sourcePath: entry.key,
            destinationMatches: List.unmodifiable(destList),
          ),
        );
      }
      duplicateMatches.sort((a, b) => a.sourcePath.compareTo(b.sourcePath));

      progress.add(
        ComparisonProgress(
          requestId: request.sourceFolder,
          status: ComparisonStatus.completed,
          totalFiles: totalUniqueCandidates,
          processedFiles: totalUniqueCandidates,
          currentStageLabel: 'Completed',
        ),
      );

      return ComparisonResult(
        requestId: request.sourceFolder,
        matches: List.unmodifiable(duplicateMatches),
        totalSourceCandidates: totalSources,
        totalDestinationCandidates: totalDests,
        completedAt: DateTime.now(),
        failures: List.unmodifiable(failures),
      );
    } finally {
      // Promptly release all in-memory fingerprints
      cache.clear();
    }
  }
}
