import 'dart:async';
import 'dart:io' show Process;
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart' show ThumbnailSession;
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_candidate.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_job.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_scheduling_policy.dart';

/// Runs a [ThumbnailJob] to completion and returns its outcome.
/// Provided by [ThumbnailSession] via its internal scheduler.
typedef ThumbnailJobRunner = Future<ThumbnailJobOutcome> Function(ThumbnailJob job);

/// Requests the session to preempt (SIGTERM/SIGKILL) the external process
/// registered under [jobKey]. The queue owns no process map; it only passes
/// the key to the session, which owns the sole jobKey → Process mapping.
typedef ThumbnailPreemptCallback = void Function(String jobKey);

// ─────────────────────────────────────────────────────────────────────────────
// Private queue entry
// ─────────────────────────────────────────────────────────────────────────────

class _ThumbnailQueueEntry {
  _ThumbnailQueueEntry({required this.job, required this.completer});

  final ThumbnailJob job;
  final Completer<ThumbnailJobOutcome> completer;
}

// ─────────────────────────────────────────────────────────────────────────────
// ThumbnailBoundedQueue
// ─────────────────────────────────────────────────────────────────────────────

/// Bounded, interest-aware thumbnail job queue.
///
/// Enforces hard caps on pending jobs and ensures memory scales with
/// viewport interest, never with total folder size.
///
/// The queue owns no [Process] references. Preemption is requested via
/// [ThumbnailPreemptCallback]; the session terminates the actual process.
class ThumbnailBoundedQueue {
  ThumbnailBoundedQueue({
    required ThumbnailJobRunner runner,
    required ThumbnailPreemptCallback onPreemptRequest,
  })  : _runner = runner,
        _onPreemptRequest = onPreemptRequest;

  final ThumbnailJobRunner _runner;
  final ThumbnailPreemptCallback _onPreemptRequest;

  // ── Bounded path sets ──────────────────────────────────────────────────────

  /// Visible + prefetch paths — used by [cancelObsoletes] and relevance checks.
  Set<String> _interestPaths = const {};

  /// Exact viewport paths — used to guard eviction (visible jobs are never evicted).
  Set<String> _visiblePaths = const {};

  // ── Queue state ────────────────────────────────────────────────────────────

  /// Sorted pending entries; lowest priority value at index 0.
  final List<_ThumbnailQueueEntry> _queue = [];

  /// Fast lookup for pending entries by job key.
  final Map<String, _ThumbnailQueueEntry> _queueMap = {};

  /// Keys currently being executed by a worker.
  final Set<String> _runningKeys = {};

  /// Running jobs indexed by key — used for preemption priority checks.
  final Map<String, ThumbnailJob> _runningJobs = {};

  /// In-flight futures for deduplication (pending + running).
  final Map<String, Future<ThumbnailJobOutcome>> _inFlightFutures = {};

  // ── Worker counters ────────────────────────────────────────────────────────

  int _activeImageCount = 0;
  int _activeVideoCount = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Update both bounded path sets atomically.
  /// Must be called before [cancelObsoletes] on each interest update.
  void updateInterestPaths(Set<String> interestPaths, Set<String> visiblePaths) {
    _interestPaths = interestPaths;
    _visiblePaths = visiblePaths;
  }

  /// Remove pending-only jobs whose paths are absent from [interestPaths].
  /// Running jobs are not touched — they may still commit valid results.
  /// Removed entries have their completers resolved as [ThumbnailJobOutcome.obsolete].
  void cancelObsoletes(Set<String> interestPaths) {
    final toRemove = <_ThumbnailQueueEntry>[];
    for (final entry in _queue) {
      if (!interestPaths.contains(entry.job.candidate.path)) {
        toRemove.add(entry);
      }
    }
    for (final entry in toRemove) {
      final key = entry.job.key;
      _queue.remove(entry);
      _queueMap.remove(key);
      _inFlightFutures.remove(key);
      if (!entry.completer.isCompleted) {
        entry.completer.complete(ThumbnailJobOutcome.obsolete);
      }
    }
  }

  bool isQueuedOrRunning(String key) {
    return _queueMap.containsKey(key) || _runningKeys.contains(key);
  }

  /// Unified admission entry point.
  ///
  /// Applies cache lookup then cap precedence (see plan §Cap precedence).
  /// Returns an immediately resolved future for cache hits, duplicates, and
  /// rejected candidates; returns a deferred future for admitted jobs.
  Future<ThumbnailJobOutcome> admit(
    ThumbnailCandidate candidate,
    int priority,
    int generation,
    ThumbnailCacheService cacheService,
  ) {
    // Step 1 — Cache lookup: hit/failed short-circuit; miss continues.
    final lookup = cacheService.lookup(
      filePath: candidate.path,
      mtime: candidate.modifiedEpochMs,
      sizeBytes: candidate.sizeBytes,
    );
    if (lookup == ThumbnailLookupResult.hit) {
      return Future.value(ThumbnailJobOutcome.success);
    }
    if (lookup == ThumbnailLookupResult.failed) {
      return Future.value(ThumbnailJobOutcome.failed);
    }

    final key = '${candidate.path}::${ThumbnailSize.normal.name}';

    // Step 2 — Running dedup.
    if (_runningKeys.contains(key)) {
      return _inFlightFutures[key] ?? Future.value(ThumbnailJobOutcome.cancelled);
    }

    // Step 3 — Pending dedup / promote.
    final existing = _queueMap[key];
    if (existing != null) {
      if (priority < existing.job.priority) {
        existing.job.priority = priority;
        _sortQueue();
      }
      return _inFlightFutures[key]!;
    }

    // Step 4 — Enforce per-type cap.
    final isVideo = candidate.isVideo;
    final typeCap = isVideo
        ? ThumbnailSchedulingPolicy.maxPendingVideoJobs
        : ThumbnailSchedulingPolicy.maxPendingImageJobs;
    final typePending = _queue.where((e) => e.job.isVideo == isVideo).length;
    final totalPending = _queue.length;

    final needsRoom = typePending >= typeCap ||
        totalPending >= ThumbnailSchedulingPolicy.maxPendingJobs;

    if (needsRoom) {
      // Step 5 — Try to evict one lower-priority non-visible prefetch job.
      final evicted = _tryEvict(priority, isVideo);
      if (!evicted) {
        // Step 6 — No eligible eviction candidate.
        final isVisible = _visiblePaths.contains(candidate.path);
        return Future.value(
          isVisible
              ? ThumbnailJobOutcome.deferred
              : ThumbnailJobOutcome.obsolete,
        );
      }
    }

    // Admit.
    final completer = Completer<ThumbnailJobOutcome>();
    final job = ThumbnailJob(
      candidate: candidate,
      size: ThumbnailSize.normal,
      priority: priority,
      generation: generation,
    );
    final entry = _ThumbnailQueueEntry(job: job, completer: completer);
    _queue.add(entry);
    _queueMap[key] = entry;
    _inFlightFutures[key] = completer.future;

    _sortQueue();
    _preemptLowPriorityJobsIfNeeded();
    _processNext();

    return completer.future;
  }

  /// Clear all state on session cancellation or disposal.
  /// Resolves all pending completers as [ThumbnailJobOutcome.cancelled].
  void clearOnCancellation() {
    _interestPaths = const {};
    _visiblePaths = const {};

    for (final entry in _queue) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(ThumbnailJobOutcome.cancelled);
      }
    }
    _queue.clear();
    _queueMap.clear();
    _inFlightFutures.clear();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Attempt to evict the lowest-priority pending non-visible job of [isVideo]
  /// type whose priority is worse (higher) than [newPriority].
  /// Returns true if an eviction was performed.
  bool _tryEvict(int newPriority, bool isVideo) {
    _ThumbnailQueueEntry? victim;
    var worstPriority = newPriority; // only evict something lower-priority

    for (final entry in _queue) {
      if (entry.job.isVideo != isVideo) continue;
      if (_visiblePaths.contains(entry.job.candidate.path)) continue;
      if (entry.job.priority > worstPriority) {
        worstPriority = entry.job.priority;
        victim = entry;
      }
    }

    if (victim == null) return false;

    final key = victim.job.key;
    _queue.remove(victim);
    _queueMap.remove(key);
    _inFlightFutures.remove(key);
    if (!victim.completer.isCompleted) {
      victim.completer.complete(ThumbnailJobOutcome.obsolete);
    }
    return true;
  }

  void _sortQueue() {
    _queue.sort((a, b) => a.job.priority.compareTo(b.job.priority));
  }

  /// If high-priority viewport work is waiting and workers are busy on
  /// lower-priority jobs, request the session to preempt the lowest-priority
  /// running external process.
  void _preemptLowPriorityJobsIfNeeded() {
    for (final entry in _queue) {
      if (entry.job.priority >= ThumbnailSchedulingPolicy.bufferPriorityBase) break;

      final isVideo = entry.job.isVideo;
      final poolFull = isVideo
          ? _activeVideoCount >= ThumbnailSchedulingPolicy.maxVideoWorkers
          : _activeImageCount >= ThumbnailSchedulingPolicy.maxImageWorkers;

      if (!poolFull) continue;

      // Find the worst-priority running job of the same type.
      String? victimKey;
      var worstPriority = -1;
      for (final running in _runningJobs.entries) {
        if (running.value.isVideo == isVideo &&
            running.value.priority >= ThumbnailSchedulingPolicy.bufferPriorityBase &&
            running.value.priority > worstPriority) {
          worstPriority = running.value.priority;
          victimKey = running.key;
        }
      }

      if (victimKey != null) {
        _onPreemptRequest(victimKey);
      }
    }
  }

  /// Start workers for all eligible pending entries up to worker limits.
  void _processNext() {
    for (var i = 0; i < _queue.length;) {
      final entry = _queue[i];
      final isVideo = entry.job.isVideo;

      final canRun = isVideo
          ? _activeVideoCount < ThumbnailSchedulingPolicy.maxVideoWorkers
          : _activeImageCount < ThumbnailSchedulingPolicy.maxImageWorkers;

      if (!canRun) {
        i++;
        continue;
      }

      _queue.removeAt(i);
      final key = entry.job.key;
      _queueMap.remove(key);
      _runningKeys.add(key);
      _runningJobs[key] = entry.job;

      if (isVideo) {
        _activeVideoCount++;
      } else {
        _activeImageCount++;
      }

      unawaited(() async {
        var outcome = ThumbnailJobOutcome.cancelled;
        try {
          outcome = await _runner(entry.job);
        } catch (e) {
          debugPrint('[ThumbnailBoundedQueue] Runner error for ${entry.job.candidate.path}: $e');
          outcome = ThumbnailJobOutcome.failed;
        } finally {
          _runningJobs.remove(key);
          _runningKeys.remove(key);
          _inFlightFutures.remove(key)?.ignore();

          if (isVideo) {
            _activeVideoCount--;
          } else {
            _activeImageCount--;
          }

          if (!entry.completer.isCompleted) {
            entry.completer.complete(outcome);
          }

          // Re-evaluate interest window so deferred visible candidates can be admitted.
          _processNext();
        }
      }());

      i = 0; // restart scan from highest-priority pending entry
    }
  }

  // ── Diagnostic accessors (used by tests) ───────────────────────────────────

  int get pendingCount => _queue.length;
  int get runningCount => _runningKeys.length;
  Set<String> get currentInterestPaths => Set.unmodifiable(_interestPaths);
  Set<String> get currentVisiblePaths => Set.unmodifiable(_visiblePaths);
}
