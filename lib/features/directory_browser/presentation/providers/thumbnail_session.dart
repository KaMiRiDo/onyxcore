import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_candidate.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_generation.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_job.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_queue.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_scheduling_policy.dart';

export 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_candidate.dart';
export 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_generation.dart'
    show ThumbnailProcessController;
export 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_job.dart';
export 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_scheduling_policy.dart';

/// Session-scoped thumbnail scheduler for a single active folder in a tab.
///
/// ## Bounded admission
/// Only candidates within the current viewport + prefetch window are ever
/// admitted to the queue. Total pending jobs are capped at
/// [ThumbnailSchedulingPolicy.maxPendingJobs].
///
/// ## Memory guarantee
/// Scheduling memory scales with:
///   visible media + bounded prefetch media + bounded running workers
/// and never with the total media count in the active folder.
///
/// ## Process ownership
/// This session is the single owner of the jobKey → [Process] map.
/// The queue requests preemption via a narrow callback; it never holds
/// process references directly.
class ThumbnailSession implements ThumbnailProcessController {
  ThumbnailSession({
    required this.folderPath,
    required this.tabId,
    this.cacheService,
  }) {
    _queue = ThumbnailBoundedQueue(
      runner: _runJob,
      onPreemptRequest: _preemptProcess,
    );
  }

  // ── Forwarding constants for backward test compatibility ───────────────────
  // These preserve the exact values expected by existing hardening tests and
  // delegate to ThumbnailSchedulingPolicy as the single source of truth.

  /// Grace period between SIGTERM and SIGKILL escalation (ms).
  static const int graceMillis = ThumbnailSchedulingPolicy.processGraceMillis;

  /// Scroll-settle debounce before a full viewport interest update (ms).
  static const int scrollSettleDebounceMillis =
      ThumbnailSchedulingPolicy.scrollSettleDebounceMillis;

  /// Maximum source-file size eligible for in-process Dart image decoding.
  static const int dartDecodeMaxBytes = ThumbnailSchedulingPolicy.dartDecodeMaxBytes;

  /// Maximum concurrent image decode workers.
  static const int maxImageWorkers = ThumbnailSchedulingPolicy.maxImageWorkers;

  /// Maximum concurrent video frame-extraction workers.
  static const int maxVideoWorkers = ThumbnailSchedulingPolicy.maxVideoWorkers;

  /// Returns true for file extensions eligible for in-process Dart decoding.
  static bool isCommonImageFormat(String filePath) =>
      _isCommonImageFormatForward(filePath);

  /// Returns the external thumbnailer command for the given file.
  static List<String> getThumbnailerCommand(
    String filePath,
    String tempThumbPath, {
    required bool isImage,
  }) =>
      _getThumbnailerCommandForward(
        filePath,
        tempThumbPath,
        isImage: isImage,
      );

  // ── Session identity ───────────────────────────────────────────────────────

  final String folderPath;
  final String tabId;
  final ThumbnailCacheService? cacheService;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isCancelled = false;
  bool _isDisposed = false;

  /// Monotonically increasing revision counter; incremented on each
  /// [updateViewportInterest] call (diagnostic use only).
  int _revision = 0;

  /// Visible + prefetch paths — the current interest window.
  Set<String> _interestPaths = const {};

  /// Exact viewport paths — used by eviction guard and relevance display.
  Set<String> _visiblePaths = const {};

  late final ThumbnailBoundedQueue _queue;

  /// Single owner of jobKey → external [Process] handles.
  final Map<String, Process> _runningProcesses = {};

  // ── Public state accessors ─────────────────────────────────────────────────

  bool get isCancelled => _isCancelled;
  bool get isDisposed => _isDisposed;

  // ──────────────────────────────────────────────────────────────────────────
  // Primary scheduling API
  // ──────────────────────────────────────────────────────────────────────────

  /// Update the viewport interest window and admit bounded candidates.
  ///
  /// [candidates] must be pre-sliced to the buffer window by [FileGrid].
  /// [visiblePaths] is the exact viewport subset.
  ///
  /// Ordering contract:
  ///   1. Replace both bounded path sets atomically.
  ///   2. Remove now-obsolete pending jobs.
  ///   3. Admit visible candidates first (priority 0..N from center outward).
  ///   4. Admit prefetch candidates second (priority 50+..M from center outward).
  void updateViewportInterest({
    required List<ThumbnailCandidate> candidates,
    required Set<String> visiblePaths,
  }) {
    if (_isCancelled || _isDisposed) return;

    _revision++;
    final interestPaths = candidates.map((c) => c.path).toSet();

    // 1. Replace sets atomically.
    _interestPaths = Set.unmodifiable(interestPaths);
    _visiblePaths = Set.unmodifiable(visiblePaths);
    _queue.updateInterestPaths(_interestPaths, _visiblePaths);

    // 2. Cancel pending jobs outside the new interest window.
    _queue.cancelObsoletes(_interestPaths);

    final cs = cacheService;
    if (cs == null) return;

    // 3 & 4. Admit visible first, then prefetch.
    final visible = candidates.where((c) => visiblePaths.contains(c.path)).toList();
    final prefetch = candidates.where((c) => !visiblePaths.contains(c.path)).toList();

    for (final candidate in visible) {
      _queue.admit(candidate, ThumbnailSchedulingPolicy.visiblePriority, _revision, cs);
    }
    for (final candidate in prefetch) {
      _queue.admit(
        candidate,
        ThumbnailSchedulingPolicy.bufferPriorityBase,
        _revision,
        cs,
      );
    }
  }

  /// Admit a single candidate from a visible widget (e.g. [MediaThumbnailPreview]).
  ///
  /// Adds the candidate's path to both [_interestPaths] and [_visiblePaths] before
  /// admission to prevent the race where a visible widget's job is treated as
  /// obsolete before the grid has called [updateViewportInterest].
  ///
  /// The next [updateViewportInterest] call replaces both sets, pruning paths
  /// no longer in the bounded grid window.
  Future<ThumbnailJobOutcome> enqueueCandidate(
    ThumbnailCandidate candidate, {
    int priority = ThumbnailSchedulingPolicy.visiblePriority,
  }) {
    if (_isCancelled || _isDisposed) {
      return Future.value(ThumbnailJobOutcome.cancelled);
    }

    final cs = cacheService;
    if (cs == null) return Future.value(ThumbnailJobOutcome.cancelled);

    // Extend interest to include this directly-admitted visible candidate.
    _interestPaths = {..._interestPaths, candidate.path};
    _visiblePaths = {..._visiblePaths, candidate.path};
    _queue.updateInterestPaths(_interestPaths, _visiblePaths);

    return _queue.admit(candidate, priority, _revision, cs);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Job relevance (used by generation layer)
  // ──────────────────────────────────────────────────────────────────────────

  bool _isJobRelevant(ThumbnailJob job) {
    return !_isCancelled &&
        !_isDisposed &&
        _interestPaths.contains(job.candidate.path);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Process ownership (implements ThumbnailProcessController)
  // ──────────────────────────────────────────────────────────────────────────

  /// Registers [process] under [jobKey]. If the session is already
  /// cancelled/disposed, terminates [process] immediately without storing it.
  @override
  void registerRunningProcess(String jobKey, Process process) {
    if (_isCancelled || _isDisposed) {
      _terminateProcess(process);
      return;
    }
    _runningProcesses[jobKey] = process;
  }

  /// Removes the process registered under [jobKey].
  @override
  void unregisterRunningProcess(String jobKey) {
    _runningProcesses.remove(jobKey);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Test-compatibility accessors
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns true if a job for [filePath]/[size] is currently pending or running.
  /// No production callers — retained for test assertions.
  bool isJobActiveOrQueued(String filePath, ThumbnailSize size) {
    final key = '$filePath::${size.name}';
    return _queue.isQueuedOrRunning(key);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Runner — called by ThumbnailBoundedQueue for each dequeued job
  // ──────────────────────────────────────────────────────────────────────────

  Future<ThumbnailJobOutcome> _runJob(ThumbnailJob job) async {
    final cs = cacheService;
    if (cs == null || _isCancelled || _isDisposed) {
      return ThumbnailJobOutcome.cancelled;
    }

    try {
      return await generateMediaThumbnail(
        job: job,
        cacheService: cs,
        processController: this,
        isCancelledOrDisposed: () => _isCancelled || _isDisposed,
        isJobRelevant: () => _isJobRelevant(job),
      );
    } finally {
      // Runner cleanup here if needed
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Preemption (called by queue via callback)
  // ──────────────────────────────────────────────────────────────────────────

  void _preemptProcess(String jobKey) {
    final process = _runningProcesses[jobKey];
    if (process != null) _terminateProcess(process);
  }

  void _terminateProcess(Process process) {
    try {
      var hasExited = false;
      process.exitCode.then((_) {
        hasExited = true;
      }).catchError((dynamic _) => null);

      // Graceful SIGTERM first.
      process.kill();

      // Escalate to SIGKILL after grace period if still running.
      Future<void>.delayed(Duration(milliseconds: graceMillis), () {
        if (!hasExited) {
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('[ThumbnailSession] Error terminating process: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  /// Cancels all pending jobs and terminates all registered external processes.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;

    // Clear bounded path sets.
    _interestPaths = const {};
    _visiblePaths = const {};

    // Drain queue; resolve completers as cancelled.
    _queue.clearOnCancellation();

    // Terminate all registered external processes.
    for (final process in _runningProcesses.values) {
      _terminateProcess(process);
    }
    _runningProcesses.clear();
  }

  /// Disposes the session, cancelling all work first.
  void dispose() {
    if (_isDisposed) return;
    cancel();
    _isDisposed = true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private forwarding aliases — camelCase to satisfy lints
// ─────────────────────────────────────────────────────────────────────────────

bool _isCommonImageFormatForward(String filePath) =>
    isCommonImageFormat(filePath);

List<String> _getThumbnailerCommandForward(
  String filePath,
  String tempThumbPath, {
  required bool isImage,
}) =>
    getThumbnailerCommand(filePath, tempThumbPath, isImage: isImage);
