import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';

void main() {
  group('ComparisonProgress', () {
    // ── named constructors ──────────────────────────────────────────────────

    test('idle constructor sets correct status', () {
      const p = ComparisonProgress.idle('req-1');
      expect(p.status, ComparisonStatus.idle);
      expect(p.requestId, 'req-1');
    });

    test('cancelled constructor sets correct status', () {
      const p = ComparisonProgress.cancelled('req-2');
      expect(p.status, ComparisonStatus.cancelled);
    });

    test('failed constructor sets correct status and error', () {
      const p = ComparisonProgress.failed('req-3', 'disk error');
      expect(p.status, ComparisonStatus.failed);
      expect(p.errorMessage, 'disk error');
    });

    // ── fractionComplete ────────────────────────────────────────────────────

    test('fractionComplete returns 0.0 when totalFiles is zero', () {
      const p = ComparisonProgress(
        requestId: 'req-1',
        status: ComparisonStatus.discovering,
      );
      expect(p.fractionComplete, 0.0);
    });

    test('fractionComplete computes correct ratio', () {
      const p = ComparisonProgress(
        requestId: 'req-1',
        status: ComparisonStatus.fingerprinting,
        totalFiles: 100,
        processedFiles: 75,
      );
      expect(p.fractionComplete, closeTo(0.75, 0.001));
    });

    test('fractionComplete is 1.0 when all files processed', () {
      const p = ComparisonProgress(
        requestId: 'req-1',
        status: ComparisonStatus.completed,
        totalFiles: 50,
        processedFiles: 50,
      );
      expect(p.fractionComplete, 1.0);
    });

    // ── isTerminal ──────────────────────────────────────────────────────────

    test('isTerminal is true for completed', () {
      const p = ComparisonProgress(
        requestId: 'r',
        status: ComparisonStatus.completed,
      );
      expect(p.isTerminal, isTrue);
    });

    test('isTerminal is true for cancelled', () {
      const p = ComparisonProgress(
        requestId: 'r',
        status: ComparisonStatus.cancelled,
      );
      expect(p.isTerminal, isTrue);
    });

    test('isTerminal is true for failed', () {
      const p = ComparisonProgress(
        requestId: 'r',
        status: ComparisonStatus.failed,
        errorMessage: 'error',
      );
      expect(p.isTerminal, isTrue);
    });

    test('isTerminal is false for non-terminal statuses', () {
      final nonTerminal = [
        ComparisonStatus.idle,
        ComparisonStatus.discovering,
        ComparisonStatus.clustering,
        ComparisonStatus.fingerprinting,
        ComparisonStatus.comparing,
      ];
      for (final status in nonTerminal) {
        final p = ComparisonProgress(requestId: 'r', status: status);
        expect(
          p.isTerminal,
          isFalse,
          reason: 'Expected $status to be non-terminal',
        );
      }
    });

    // ── copyWith ────────────────────────────────────────────────────────────

    test('copyWith updates status and processedFiles', () {
      const initial = ComparisonProgress(
        requestId: 'req-1',
        status: ComparisonStatus.discovering,
        totalFiles: 200,
        currentStageLabel: 'Discovering files',
      );
      final updated = initial.copyWith(
        status: ComparisonStatus.clustering,
        processedFiles: 200,
        currentStageLabel: 'Building clusters',
      );
      expect(updated.status, ComparisonStatus.clustering);
      expect(updated.processedFiles, 200);
      expect(updated.currentStageLabel, 'Building clusters');
      expect(updated.totalFiles, 200);
      expect(updated.requestId, 'req-1');
    });

    // ── value equality ──────────────────────────────────────────────────────

    test('supports value equality via Equatable', () {
      const p1 = ComparisonProgress(
        requestId: 'req-1',
        status: ComparisonStatus.comparing,
        totalFiles: 100,
        processedFiles: 50,
      );
      const p2 = ComparisonProgress(
        requestId: 'req-1',
        status: ComparisonStatus.comparing,
        totalFiles: 100,
        processedFiles: 50,
      );
      expect(p1, equals(p2));
    });

    // ── ComparisonStatus enum ───────────────────────────────────────────────

    test('ComparisonStatus has all expected variants', () {
      expect(
        ComparisonStatus.values,
        containsAll([
          ComparisonStatus.idle,
          ComparisonStatus.discovering,
          ComparisonStatus.clustering,
          ComparisonStatus.fingerprinting,
          ComparisonStatus.comparing,
          ComparisonStatus.completed,
          ComparisonStatus.cancelled,
          ComparisonStatus.failed,
        ]),
      );
    });
  });
}
