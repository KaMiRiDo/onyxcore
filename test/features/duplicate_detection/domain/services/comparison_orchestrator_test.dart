import 'dart:async';

import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeOrchestrator extends Fake implements ComparisonOrchestrator {

  _FakeOrchestrator({
    required ComparisonResult result,
    bool shouldCancel = false,
    bool shouldFail = false,
  }) : _result = result,
       _shouldCancel = shouldCancel,
       _shouldFail = shouldFail;
  final ComparisonResult _result;
  final bool _shouldCancel;
  final bool _shouldFail;

  @override
  Future<ComparisonResult> run(
    ComparisonRequest request, {
    required StreamController<ComparisonProgress> progress,
    required CancellationToken token,
  }) async {
    if (token.isCancelled || _shouldCancel) {
      progress.add(ComparisonProgress.cancelled(request.sourceFolder));
      return _result;
    }
    if (_shouldFail) {
      progress.add(
        ComparisonProgress.failed(request.sourceFolder, 'pipeline error'),
      );
      throw ComparisonOrchestratorException(
        request.sourceFolder,
        'pipeline error',
      );
    }
    progress
      ..add(
        ComparisonProgress(
          requestId: request.sourceFolder,
          status: ComparisonStatus.discovering,
          totalFiles: 100,
        ),
      )
      ..add(
        ComparisonProgress(
          requestId: request.sourceFolder,
          status: ComparisonStatus.completed,
          totalFiles: 100,
          processedFiles: 100,
        ),
      );
    return _result;
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

/// Creates a broadcast StreamController so events emitted before `listen` are
/// NOT buffered and tests do not hang on `await close()` with no subscribers.
StreamController<ComparisonProgress> _makeController() =>
    StreamController<ComparisonProgress>.broadcast();

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const tRequest = ComparisonRequest(
    sourceFolder: '/source',
    destinationFolder: '/destination',
    category: ComparisonCategory.all,
  );

  final tEmptyResult = ComparisonResult(
    requestId: '/source',
    matches: const [],
    totalSourceCandidates: 0,
    totalDestinationCandidates: 0,
    completedAt: DateTime(2024),
  );

  group('ComparisonOrchestrator contract', () {
    test('run emits discovering then completed progress events', () async {
      final orchestrator = _FakeOrchestrator(result: tEmptyResult);
      final progressCtrl = _makeController();
      final token = CancellationToken();

      final events = <ComparisonProgress>[];
      progressCtrl.stream.listen(events.add);

      await orchestrator.run(tRequest, progress: progressCtrl, token: token);
      await progressCtrl.close();

      expect(events.map((e) => e.status), [
        ComparisonStatus.discovering,
        ComparisonStatus.completed,
      ]);
    });

    test('run returns ComparisonResult on success', () async {
      final orchestrator = _FakeOrchestrator(result: tEmptyResult);
      final progressCtrl = _makeController();
      final token = CancellationToken();

      final result = await orchestrator.run(
        tRequest,
        progress: progressCtrl,
        token: token,
      );
      await progressCtrl.close();

      expect(result, equals(tEmptyResult));
    });

    test(
      'run emits cancelled event when token is cancelled before start',
      () async {
        final orchestrator = _FakeOrchestrator(result: tEmptyResult);
        final progressCtrl = _makeController();
        final token = CancellationToken()..cancel();

        final events = <ComparisonProgress>[];
        progressCtrl.stream.listen(events.add);

        await orchestrator.run(tRequest, progress: progressCtrl, token: token);
        await progressCtrl.close();

        expect(
          events.any((e) => e.status == ComparisonStatus.cancelled),
          isTrue,
        );
      },
    );

    test('run throws ComparisonOrchestratorException on failure', () async {
      final orchestrator = _FakeOrchestrator(
        result: tEmptyResult,
        shouldFail: true,
      );
      final progressCtrl = _makeController();
      final token = CancellationToken();

      expect(
        () => orchestrator.run(tRequest, progress: progressCtrl, token: token),
        throwsA(isA<ComparisonOrchestratorException>()),
      );
    });
  });

  group('CancellationToken', () {
    test('isCancelled is false initially', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('isCancelled becomes true after cancel()', () {
      final token = CancellationToken()..cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent', () {
      final token = CancellationToken()
        ..cancel()
        ..cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('ComparisonOrchestratorException', () {
    test('carries requestId and message', () {
      const ex = ComparisonOrchestratorException('req-1', 'fatal error');
      expect(ex.requestId, 'req-1');
      expect(ex.message, 'fatal error');
      expect(ex.toString(), contains('req-1'));
      expect(ex.toString(), contains('fatal error'));
    });
  });
}
