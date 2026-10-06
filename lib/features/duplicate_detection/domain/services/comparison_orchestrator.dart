import 'dart:async';

import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';

/// Cancellation token passed to the orchestrator to allow the caller to
/// request early termination of a comparison run.
///
/// The orchestrator must poll [isCancelled] at each pipeline stage boundary
/// and abort cleanly when it is [true].
class CancellationToken {
  CancellationToken() : _cancelled = false;

  bool _cancelled;

  /// [true] after [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Requests cancellation.  Idempotent — calling more than once is safe.
  void cancel() => _cancelled = true;
}

/// Contract for the top-level comparison orchestrator.
///
/// The orchestrator drives the full pipeline:
///
/// ```
/// Discovery
///   → Stage 1 filtering / metadata extraction
///   → Cluster creation
///   → Matching cluster pairs
///   → Stage 2 fingerprinting
///   → Comparison
///   → Results
/// ```
///
/// Progress is emitted as a [Stream] so the caller can update the UI without
/// blocking the main thread.  The orchestrator itself may delegate heavy work
/// to background isolates in later phases.
///
/// Phase 1 defines the contract only.  No pipeline logic is implemented here.
abstract interface class ComparisonOrchestrator {
  /// Runs the full comparison pipeline for [request].
  ///
  /// - Progress events are emitted on [progress] throughout the run.
  /// - The returned [Future] resolves with the final [ComparisonResult] when
  ///   the run completes successfully.
  /// - If [token.isCancelled] becomes [true], the run MUST abort and emit a
  ///   [ComparisonStatus.cancelled] progress event before returning.
  /// - On any unrecoverable error the run MUST emit a
  ///   [ComparisonStatus.failed] progress event and throw a
  ///   [ComparisonOrchestratorException].
  Future<ComparisonResult> run(
    ComparisonRequest request, {
    required StreamController<ComparisonProgress> progress,
    required CancellationToken token,
  });
}

/// Thrown by [ComparisonOrchestrator.run] on an unrecoverable pipeline error.
class ComparisonOrchestratorException implements Exception {
  const ComparisonOrchestratorException(this.requestId, this.message);

  final String requestId;
  final String message;

  @override
  String toString() => 'ComparisonOrchestratorException($requestId): $message';
}
