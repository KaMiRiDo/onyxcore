import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart' show FileItem;
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_candidate.dart';

/// Outcome of a thumbnail generation or admission request.
enum ThumbnailJobOutcome {
  /// Thumbnail generated and committed to the persistent disk cache.
  success,

  /// Generation genuinely failed on a current-interest job (corrupt or unsupported
  /// media). A negative-cache entry has been written via [ThumbnailCacheService.markFailed].
  failed,

  /// The session was cancelled or disposed before or during generation.
  /// No cache entry is written.
  cancelled,

  /// The job was no longer in the current interest-paths window when the result
  /// was evaluated. A successful result may have been committed to disk for future
  /// reuse. Failures are not negative-cached because obsolescence is not evidence
  /// of corrupt media.
  obsolete,

  /// The candidate is still relevant (present in the current interest/visible window)
  /// but could not be admitted because the bounded queue is at its hard cap and no
  /// lower-priority non-visible prefetch job was available for eviction.
  ///
  /// This is a temporary condition. No job, no retained future, and no
  /// negative-cache entry are created. The caller must treat this as a no-op;
  /// the candidate will be re-evaluated when a worker slot is released.
  deferred,
}

/// Data-only descriptor of a pending thumbnail generation task.
///
/// Contains no task closure, no [FileItem] reference, no UI objects,
/// and no folder-list reference. Execution is owned by the queue runner.
class ThumbnailJob {
  ThumbnailJob({
    required this.candidate,
    required this.size,
    required this.priority,
    required this.generation,
  });

  final ThumbnailCandidate candidate;
  final ThumbnailSize size;

  /// Scheduling priority — lower numeric value = higher priority.
  /// Mutable to allow in-place reprioritization without queue removal.
  int priority;

  /// Monotonically increasing revision number at the time of admission.
  /// Used for ordering and diagnostics; not the sole relevance check.
  final int generation;

  bool get isVideo => candidate.isVideo;

  /// Unique stable key for this job, keyed by path and size tier.
  String get key => '${candidate.path}::${size.name}';
}
