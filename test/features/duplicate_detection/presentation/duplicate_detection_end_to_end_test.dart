import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:image/image.dart' as img;
import 'package:onyxcore/features/duplicate_detection/data/repositories/local_candidate_discovery_repository.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/other_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/composite_fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/default_comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_pipeline.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage2_pipeline.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_results_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/file_comparison_tile.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Cross-Folder Duplicate Detection End-to-End Integration', () {
    late Directory rootDir;
    late Directory sourceDir;
    late Directory destDir;

    setUp(() {
      rootDir = Directory.systemTemp.createTempSync('e2e_dup_test_');
      sourceDir = Directory(p.join(rootDir.path, 'source'))..createSync();
      destDir = Directory(p.join(rootDir.path, 'destination'))..createSync();
    });

    tearDown(() {
      try {
        rootDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    List<int> createPatternPngBytes({int mode = 0}) {
      final image = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final int val;
          switch (mode) {
            case 0:
              // Checkerboard pattern
              val = ((x ~/ 4) + (y ~/ 4)).isEven ? 240 : 20;
            case 1:
              // Inverted checkerboard pattern
              val = ((x ~/ 4) + (y ~/ 4)).isEven ? 20 : 240;
            case 2:
              // Vertical stripes pattern
              val = (x ~/ 4).isEven ? 240 : 20;
            default:
              // Diagonal gradient
              val = ((x * 4) + (y * 4)) % 256;
          }
          image.setPixelRgb(x, y, val, val, val);
        }
      }
      return img.encodePng(image);
    }

    test(
      'End-to-End: discovers real files, clusters, fingerprints, matches one-to-many across folders, and excludes distinct files',
      () async {
        // 1. Prepare files in source directory
        final sourceImgBytes = createPatternPngBytes(); // mode 0
        final uniqueSourceBytes = createPatternPngBytes(mode: 2); // mode 2

        final srcImg1 = File(p.join(sourceDir.path, 'original_photo.png'))
          ..writeAsBytesSync(sourceImgBytes);
        final srcImg2 = File(p.join(sourceDir.path, 'unrelated_photo.png'))
          ..writeAsBytesSync(uniqueSourceBytes);
        File(
          p.join(sourceDir.path, 'notes.txt'),
        ).writeAsStringSync('text notes in source');

        // 2. Prepare files in destination directory (including nested subfolder for recursion)
        final destSubdir = Directory(p.join(destDir.path, 'nested'))
          ..createSync();

        // Exact match with different filename in root of destination
        final destImgCopy1 = File(p.join(destDir.path, 'backup_photo.png'))
          ..writeAsBytesSync(sourceImgBytes);

        // Same image in subfolder with different filename -> one-to-many match
        final destImgCopy2 = File(p.join(destSubdir.path, 'deep_copy.png'))
          ..writeAsBytesSync(sourceImgBytes);

        // Distinct image in destination (mode 1: inverted gradient)
        final destDistinct = File(p.join(destDir.path, 'different_pic.png'))
          ..writeAsBytesSync(createPatternPngBytes(mode: 1));

        // Other document in destination
        File(
          p.join(destDir.path, 'dest_notes.txt'),
        ).writeAsStringSync('text notes in destination');

        // 3. Assemble real production pipeline
        final discoveryRepo = LocalCandidateDiscoveryRepository();
        final imgStrategy = ImageMediaStrategy();
        final otherStrategy = OtherMediaStrategy();

        final strategyRegistry = MediaStrategyRegistry([
          imgStrategy,
          otherStrategy,
        ]);

        final stage1 = Stage1Pipeline(discoveryRepo, strategyRegistry);
        final compositeGen = CompositeFingerprintGenerator(strategyRegistry);

        final stage2 = Stage2Pipeline(generator: compositeGen);

        final orchestrator = DefaultComparisonOrchestrator(
          stage1Pipeline: stage1,
          stage2Pipeline: stage2,
        );

        // 4. Run end-to-end comparison with Category = Images
        final request = ComparisonRequest(
          sourceFolder: sourceDir.path,
          destinationFolder: destDir.path,
          category: ComparisonCategory.images,
        );

        final progressController =
            StreamController<ComparisonProgress>.broadcast();
        final progressEvents = <ComparisonProgress>[];
        progressController.stream.listen(progressEvents.add);

        final token = CancellationToken();
        final result = await orchestrator.run(
          request,
          progress: progressController,
          token: token,
        );

        await progressController.close();

        // 5. Verify domain results
        expect(result.requestId, sourceDir.path);
        expect(result.failures, isEmpty);

        // Total source candidates evaluated should be 2 (images only, notes.txt excluded)
        expect(result.totalSourceCandidates, 2);
        // Total destination candidates evaluated should be 3 (2 copies + 1 distinct, dest_notes.txt excluded)
        expect(result.totalDestinationCandidates, 3);

        // Exactly 1 duplicate group: srcImg1
        expect(result.matches.length, 1);
        final match = result.matches.first;
        expect(match.sourcePath, srcImg1.path);

        // One-to-many: matched both copies in destination despite different names and paths!
        expect(match.matchCount, 2);
        final matchedDestPaths = match.destinationMatches
            .map((m) => m.destinationPath)
            .toSet();
        expect(matchedDestPaths, contains(destImgCopy1.path));
        expect(matchedDestPaths, contains(destImgCopy2.path));

        // Exact matches
        for (final pair in match.destinationMatches) {
          expect(pair.matchType, MatchType.exact);
          expect(pair.similarityScore, 1);
        }

        // Unmatched files must NOT be in matches
        expect(
          result.matches.any((m) => m.sourcePath == srcImg2.path),
          isFalse,
        );
        expect(matchedDestPaths.contains(destDistinct.path), isFalse);

        // Progress events reached completed status
        expect(
          progressEvents.any((e) => e.status == ComparisonStatus.completed),
          isTrue,
        );
      },
    );

    test(
      'End-to-End: Category All compares images and skips unsupported file types safely without false positives',
      () async {
        final imgBytes = createPatternPngBytes();

        final srcImg = File(p.join(sourceDir.path, 'pic.png'))
          ..writeAsBytesSync(imgBytes);
        final srcDoc = File(p.join(sourceDir.path, 'doc.txt'))
          ..writeAsStringSync('sample');

        final destImg = File(p.join(destDir.path, 'pic_copy.png'))
          ..writeAsBytesSync(imgBytes);
        final destDoc = File(p.join(destDir.path, 'doc_copy.txt'))
          ..writeAsStringSync('sample');

        final discoveryRepo = LocalCandidateDiscoveryRepository();
        final imgStrategy = ImageMediaStrategy();
        final otherStrategy = OtherMediaStrategy();

        final strategyRegistry = MediaStrategyRegistry([
          imgStrategy,
          otherStrategy,
        ]);

        final stage1 = Stage1Pipeline(discoveryRepo, strategyRegistry);
        final compositeGen = CompositeFingerprintGenerator(strategyRegistry);

        final stage2 = Stage2Pipeline(generator: compositeGen);

        final orchestrator = DefaultComparisonOrchestrator(
          stage1Pipeline: stage1,
          stage2Pipeline: stage2,
        );

        final request = ComparisonRequest(
          sourceFolder: sourceDir.path,
          destinationFolder: destDir.path,
          category: ComparisonCategory.all,
        );

        final progressController =
            StreamController<ComparisonProgress>.broadcast();
        final token = CancellationToken();

        final result = await orchestrator.run(
          request,
          progress: progressController,
          token: token,
        );

        await progressController.close();

        // Image match is successfully found
        expect(result.matches.length, 1);
        expect(result.matches.first.sourcePath, srcImg.path);
        expect(
          result.matches.first.destinationMatches.first.destinationPath,
          destImg.path,
        );

        // Other documents were evaluated; unsupported fingerprinting is captured as failure, not false match
        expect(
          result.failures.any(
            (f) =>
                f.candidatePath == srcDoc.path ||
                f.candidatePath == destDoc.path,
          ),
          isTrue,
        );
      },
    );

    test(
      'End-to-End: Cancellation cleanly stops orchestrator and produces cancelled result',
      () async {
        final imgBytes = createPatternPngBytes();
        File(p.join(sourceDir.path, 'a.png')).writeAsBytesSync(imgBytes);
        File(p.join(destDir.path, 'b.png')).writeAsBytesSync(imgBytes);

        final discoveryRepo = LocalCandidateDiscoveryRepository();
        final imgStrategy = ImageMediaStrategy();
        final otherStrategy = OtherMediaStrategy();

        final registry = MediaStrategyRegistry([imgStrategy, otherStrategy]);
        final orchestrator = DefaultComparisonOrchestrator(
          stage1Pipeline: Stage1Pipeline(discoveryRepo, registry),
          stage2Pipeline: Stage2Pipeline(
            generator: CompositeFingerprintGenerator(registry),
          ),
        );

        final progressController =
            StreamController<ComparisonProgress>.broadcast();
        final token = CancellationToken()..cancel(); // Pre-cancelled

        final result = await orchestrator.run(
          ComparisonRequest(
            sourceFolder: sourceDir.path,
            destinationFolder: destDir.path,
            category: ComparisonCategory.images,
          ),
          progress: progressController,
          token: token,
        );

        await progressController.close();

        expect(result.isEmpty, isTrue);
      },
    );

    testWidgets(
      'End-to-End UI Integration: CompareResultsView renders real comparison results correctly',
      (tester) async {
        final imgBytes = createPatternPngBytes();
        final src = File(p.join(sourceDir.path, 'sunset.png'))
          ..writeAsBytesSync(imgBytes);
        final dest1 = File(p.join(destDir.path, 'sunset_backup.png'))
          ..writeAsBytesSync(imgBytes);
        final dest2 = File(p.join(destDir.path, 'sunset_cloud.png'))
          ..writeAsBytesSync(imgBytes);

        final e2eResult = ComparisonResult(
          requestId: sourceDir.path,
          matches: [
            DuplicateMatch(
              sourcePath: src.path,
              destinationMatches: [
                MatchedPair(
                  sourcePath: src.path,
                  destinationPath: dest1.path,
                  similarityScore: 1,
                ),
                MatchedPair(
                  sourcePath: src.path,
                  destinationPath: dest2.path,
                  similarityScore: 0.98,
                  matchType: MatchType.perceptual,
                ),
              ],
            ),
          ],
          totalSourceCandidates: 1,
          totalDestinationCandidates: 2,
          completedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: CompareResultsView(result: e2eResult)),
          ),
        );

        // Summary bar
        expect(find.textContaining('1 Duplicate Group'), findsOneWidget);
        expect(find.textContaining('2 Total Matches'), findsOneWidget);
        expect(find.textContaining('1 source / 2 destination'), findsOneWidget);

        // Group card
        expect(find.byType(DuplicateGroupCard), findsOneWidget);
        expect(find.text('sunset.png'), findsWidgets);
        expect(find.text('2 Matches'), findsOneWidget);

        // Side-by-side tiles: 1 source + 2 destinations = 3 tiles
        expect(find.byType(FileComparisonTile), findsNWidgets(3));
        expect(find.text('SOURCE'), findsOneWidget);
        expect(find.text('DESTINATION'), findsNWidgets(2));
        expect(find.text('sunset_backup.png'), findsOneWidget);
        expect(find.text('sunset_cloud.png'), findsOneWidget);
        expect(find.text('Exact Match'), findsWidgets);
        expect(find.text('98% Similarity'), findsOneWidget);
      },
    );
  });
}
