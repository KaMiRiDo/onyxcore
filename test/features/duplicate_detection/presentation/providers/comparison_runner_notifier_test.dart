import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_orchestrator_provider.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_runner_notifier.dart';

class _FakeOrchestrator implements ComparisonOrchestrator {
  _FakeOrchestrator({this.delay = Duration.zero, this.shouldFail = false});

  final Duration delay;
  final bool shouldFail;
  int runCallCount = 0;
  CancellationToken? capturedToken;

  @override
  Future<ComparisonResult> run(
    ComparisonRequest request, {
    required StreamController<ComparisonProgress> progress,
    required CancellationToken token,
  }) async {
    runCallCount++;
    capturedToken = token;

    progress.add(
      ComparisonProgress(
        requestId: request.sourceFolder,
        status: ComparisonStatus.discovering,
        processedFiles: 1,
        totalFiles: 10,
      ),
    );

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

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

    if (shouldFail) {
      progress.add(
        ComparisonProgress.failed(request.sourceFolder, 'Simulated failure'),
      );
      throw const ComparisonOrchestratorException('test', 'Simulated failure');
    }

    progress.add(
      ComparisonProgress(
        requestId: request.sourceFolder,
        status: ComparisonStatus.completed,
        processedFiles: 10,
        totalFiles: 10,
      ),
    );

    return ComparisonResult(
      requestId: request.sourceFolder,
      matches: const [],
      totalSourceCandidates: 5,
      totalDestinationCandidates: 5,
      completedAt: DateTime.now(),
    );
  }
}

void main() {
  group('ComparisonRunnerNotifier', () {
    const tRequest = ComparisonRequest(
      sourceFolder: '/src',
      destinationFolder: '/dst',
      category: ComparisonCategory.all,
    );

    test('initial state is idle and not processing', () {
      final fake = _FakeOrchestrator();
      final container = ProviderContainer(
        overrides: [comparisonOrchestratorProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final state = container.read(comparisonRunnerProvider);
      expect(state.isProcessing, isFalse);
      expect(state.progress, isNull);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('executes comparison and updates progress and result', () async {
      final fake = _FakeOrchestrator();
      final container = ProviderContainer(
        overrides: [comparisonOrchestratorProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final runner = container.read(comparisonRunnerProvider.notifier);
      await runner.startComparison(tRequest);

      final state = container.read(comparisonRunnerProvider);
      expect(fake.runCallCount, 1);
      expect(state.isProcessing, isFalse);
      expect(state.result, isNotNull);
      expect(state.result!.totalSourceCandidates, 5);
      expect(state.error, isNull);
    });

    test('protects against duplicate repeated startComparison calls', () async {
      final fake = _FakeOrchestrator(delay: const Duration(milliseconds: 50));
      final container = ProviderContainer(
        overrides: [comparisonOrchestratorProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final runner = container.read(comparisonRunnerProvider.notifier);
      final future1 = runner.startComparison(tRequest);
      final future2 = runner.startComparison(
        tRequest,
      ); // duplicate call while processing

      await Future.wait([future1, future2]);

      expect(fake.runCallCount, 1); // Only executed once!
    });

    test('supports cancellation during processing', () async {
      final fake = _FakeOrchestrator(delay: const Duration(milliseconds: 100));
      final container = ProviderContainer(
        overrides: [comparisonOrchestratorProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final runner = container.read(comparisonRunnerProvider.notifier);
      final future = runner.startComparison(tRequest);
      expect(container.read(comparisonRunnerProvider).isProcessing, isTrue);

      runner.cancel();

      await future;

      expect(fake.capturedToken?.isCancelled, isTrue);
      expect(container.read(comparisonRunnerProvider).isProcessing, isFalse);
    });

    test(
      'handles orchestrator failure safely without throwing unhandled error',
      () async {
        final fake = _FakeOrchestrator(shouldFail: true);
        final container = ProviderContainer(
          overrides: [comparisonOrchestratorProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final runner = container.read(comparisonRunnerProvider.notifier);
        await runner.startComparison(tRequest);

        final state = container.read(comparisonRunnerProvider);
        expect(state.isProcessing, isFalse);
        expect(state.error, contains('Simulated failure'));
        expect(state.result, isNull);
      },
    );

    test('dispose cancels any ongoing processing', () async {
      final fake = _FakeOrchestrator(delay: const Duration(milliseconds: 100));
      final container = ProviderContainer(
        overrides: [comparisonOrchestratorProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final runner = container.read(comparisonRunnerProvider.notifier);
      unawaited(runner.startComparison(tRequest));
      expect(container.read(comparisonRunnerProvider).isProcessing, isTrue);

      container.dispose();

      expect(fake.capturedToken?.isCancelled, isTrue);
    });
  });
}
