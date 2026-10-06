import 'package:equatable/equatable.dart';

/// The lifecycle state of a comparison run.
enum ComparisonStatus {
  /// The comparison has been created but not yet started.
  idle,

  /// File discovery is in progress.
  discovering,

  /// Stage 1 metadata extraction / cluster building is in progress.
  clustering,

  /// Stage 2 fingerprint generation is in progress.
  fingerprinting,

  /// Fingerprint comparison is in progress.
  comparing,

  /// The comparison completed successfully.
  completed,

  /// The comparison was cancelled by the user or the system.
  cancelled,

  /// The comparison failed with an error.
  failed,
}

/// Immutable snapshot of the progress of an ongoing comparison run.
///
/// Progress snapshots are emitted by the orchestrator boundary on every
/// meaningful state transition and are safe to pass across isolate boundaries
/// because all fields are primitive or [Equatable].
class ComparisonProgress extends Equatable {
  const ComparisonProgress({
    required this.requestId,
    required this.status,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.currentStageLabel,
    this.errorMessage,
  });

  /// Creates an [idle] progress snapshot for the given [requestId].
  const ComparisonProgress.idle(String requestId)
    : this(requestId: requestId, status: ComparisonStatus.idle);

  /// Creates a [cancelled] progress snapshot for the given [requestId].
  const ComparisonProgress.cancelled(String requestId)
    : this(requestId: requestId, status: ComparisonStatus.cancelled);

  /// Creates a [failed] progress snapshot with the given [error].
  const ComparisonProgress.failed(String requestId, String error)
    : this(
        requestId: requestId,
        status: ComparisonStatus.failed,
        errorMessage: error,
      );

  /// Opaque identifier linking this snapshot to its originating request.
  final String requestId;

  /// Current lifecycle state.
  final ComparisonStatus status;

  /// Total number of files expected to be processed in the current stage.
  /// Zero when not yet known.
  final int totalFiles;

  /// Number of files processed so far in the current stage.
  final int processedFiles;

  /// Human-readable label for the current stage, suitable for display.
  /// [null] when [status] is [ComparisonStatus.idle].
  final String? currentStageLabel;

  /// Error description.  Non-null only when [status] is
  /// [ComparisonStatus.failed].
  final String? errorMessage;

  /// Fractional progress in [0.0, 1.0].  Returns 0.0 when [totalFiles] is
  /// zero to avoid division-by-zero.
  double get fractionComplete =>
      totalFiles == 0 ? 0.0 : processedFiles / totalFiles;

  /// [true] when the run has reached a terminal state.
  bool get isTerminal =>
      status == ComparisonStatus.completed ||
      status == ComparisonStatus.cancelled ||
      status == ComparisonStatus.failed;

  ComparisonProgress copyWith({
    String? requestId,
    ComparisonStatus? status,
    int? totalFiles,
    int? processedFiles,
    String? currentStageLabel,
    String? errorMessage,
  }) {
    return ComparisonProgress(
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      currentStageLabel: currentStageLabel ?? this.currentStageLabel,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    requestId,
    status,
    totalFiles,
    processedFiles,
    currentStageLabel,
    errorMessage,
  ];
}
