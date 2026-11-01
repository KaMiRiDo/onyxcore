import 'dart:async';

import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
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
      final totalUniqueCandidates = totalSources + totalDests;

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

      // Helper to safely get or generate fingerprint with caching and error handling
      Future<CandidateFingerprint?> getFingerprint(
        ComparisonCandidate candidate,
      ) async {
        if (token.isCancelled) return null;
        try {
          final fp = await cache.getOrGenerate(candidate, generator);
          processedCandidateCount++;
          progress.add(
            ComparisonProgress(
              requestId: request.sourceFolder,
              status: ComparisonStatus.fingerprinting,
              totalFiles: totalUniqueCandidates,
              processedFiles: processedCandidateCount,
              currentStageLabel: 'Generating 256-bit fingerprints',
            ),
          );
          return fp;
        } catch (e) {
          failures.add(
            ComparisonFailure(
              candidatePath: candidate.file.path,
              error: e.toString(),
            ),
          );
          return null;
        }
      }

      // 2. Iterate pairs and compare compatible source and destination files
      for (final pair in stage1Result.pairs) {
        if (token.isCancelled) break;

        final candidateComparisons =
            <(ComparisonCandidate, ComparisonCandidate)>[];

        if (identical(pair.clusterA, pair.clusterB)) {
          for (final s in pair.clusterA.sourceCandidates) {
            for (final d in pair.clusterA.destinationCandidates) {
              candidateComparisons.add((s, d));
            }
          }
        } else {
          for (final s in pair.clusterA.sourceCandidates) {
            for (final d in pair.clusterB.destinationCandidates) {
              candidateComparisons.add((s, d));
            }
          }
          for (final s in pair.clusterB.sourceCandidates) {
            for (final d in pair.clusterA.destinationCandidates) {
              candidateComparisons.add((s, d));
            }
          }
        }

        progress.add(
          ComparisonProgress(
            requestId: request.sourceFolder,
            status: ComparisonStatus.comparing,
            totalFiles: totalUniqueCandidates,
            processedFiles: processedCandidateCount,
            currentStageLabel: 'Comparing fingerprints',
          ),
        );

        for (final (source, dest) in candidateComparisons) {
          if (token.isCancelled) break;

          final fpSource = await getFingerprint(source);
          final fpDest = await getFingerprint(dest);

          if (fpSource == null || fpDest == null) continue;

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
