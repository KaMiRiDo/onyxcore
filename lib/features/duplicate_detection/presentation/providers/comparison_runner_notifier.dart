import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/comparison_orchestrator.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_orchestrator_provider.dart';

/// Presentation state representing an ongoing, completed, or failed comparison.
class ComparisonRunnerState extends Equatable {
  const ComparisonRunnerState({
    this.isProcessing = false,
    this.progress,
    this.result,
    this.error,
  });

  final bool isProcessing;
  final ComparisonProgress? progress;
  final ComparisonResult? result;
  final String? error;

  ComparisonRunnerState copyWith({
    bool? isProcessing,
    ComparisonProgress? progress,
    ComparisonResult? result,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return ComparisonRunnerState(
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isProcessing, progress, result, error];
}

/// Controls the comparison lifecycle, stream subscriptions, cancellation, and errors.
class ComparisonRunnerNotifier extends Notifier<ComparisonRunnerState> {
  ComparisonRunnerNotifier({
    ComparisonOrchestrator? orchestrator,
    ComparisonRunnerState initialState = const ComparisonRunnerState(),
  }) : _orchestrator = orchestrator,
       _initialState = initialState;

  final ComparisonOrchestrator? _orchestrator;
  final ComparisonRunnerState _initialState;

  CancellationToken? _cancellationToken;
  StreamSubscription<ComparisonProgress>? _progressSubscription;
  StreamController<ComparisonProgress>? _progressController;

  @override
  ComparisonRunnerState build() {
    ref.onDispose(dispose);
    return _initialState;
  }

  Future<void> startComparison(ComparisonRequest request) async {
    // Repeated action protection: ignore if a job is already in flight
    if (state.isProcessing) return;

    _cleanup();

    final token = CancellationToken();
    final controller = StreamController<ComparisonProgress>.broadcast();

    _cancellationToken = token;
    _progressController = controller;

    state = ComparisonRunnerState(
      isProcessing: true,
      progress: ComparisonProgress(
        requestId: request.sourceFolder,
        status: ComparisonStatus.discovering,
      ),
    );

    _progressSubscription = controller.stream.listen((event) {
      state = state.copyWith(progress: event);
    });

    final orchestrator =
        _orchestrator ?? ref.read(comparisonOrchestratorProvider);

    try {
      final result = await orchestrator!.run(
        request,
        progress: controller,
        token: token,
      );

      if (token.isCancelled) {
        state = state.copyWith(
          isProcessing: false,
          progress: ComparisonProgress.cancelled(request.sourceFolder),
        );
      } else {
        state = state.copyWith(
          isProcessing: false,
          result: result,
          clearError: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
        clearResult: true,
      );
    } finally {
      _cleanup();
    }
  }

  void cancel() {
    _cancellationToken?.cancel();
    if (state.isProcessing) {
      state = state.copyWith(
        isProcessing: false,
        progress: ComparisonProgress.cancelled(state.progress?.requestId ?? ''),
      );
    }
    _cleanup();
  }

  void reset() {
    cancel();
    state = const ComparisonRunnerState();
  }

  void dispose() {
    _cancellationToken?.cancel();
    _cleanup();
  }

  void _cleanup() {
    unawaited(_progressSubscription?.cancel());
    _progressSubscription = null;
    if (_progressController != null && !_progressController!.isClosed) {
      unawaited(_progressController!.close());
    }
    _progressController = null;
  }
}

final comparisonRunnerProvider =
    NotifierProvider<ComparisonRunnerNotifier, ComparisonRunnerState>(
      ComparisonRunnerNotifier.new,
    );
