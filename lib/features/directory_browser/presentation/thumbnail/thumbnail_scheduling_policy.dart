/// Centralised scheduling policy constants for thumbnail generation.
///
/// All queue limits, worker counts, debounce timings, and priority offsets
/// live here. The scheduler enforces these values regardless of viewport size,
/// zoom level, column count, or rapid scroll frequency.
class ThumbnailSchedulingPolicy {
  ThumbnailSchedulingPolicy._();

  // ── Prefetch window ────────────────────────────────────────────────────────

  /// Grid rows prefetched above the visible viewport.
  static const int prefetchRowsBefore = 2;

  /// Grid rows prefetched below the visible viewport.
  static const int prefetchRowsAfter = 2;

  // ── Priority values (lower numeric value = scheduled first) ────────────────

  /// Priority assigned to items directly visible in the viewport.
  static const int visiblePriority = 0;

  /// Base priority offset added to prefetch (buffer) items.
  /// Distance from viewport centre is added on top of this base.
  static const int bufferPriorityBase = 50;

  // ── Queue caps ─────────────────────────────────────────────────────────────

  /// Hard cap: maximum total pending jobs (image + video combined).
  ///
  /// Rationale: 4-column grid at zoom = 1 → ~32 visible + ~16 buffer ≈ 48
  /// typical candidates. 64 provides headroom for wider viewports and higher
  /// zoom levels without allowing unbounded growth.
  static const int maxPendingJobs = 64;

  /// Per-type cap for pending image jobs. Images are lighter-weight than video.
  static const int maxPendingImageJobs = 48;

  /// Per-type cap for pending video jobs. Video demux/decode is compute-heavy.
  static const int maxPendingVideoJobs = 16;

  // ── Worker limits ──────────────────────────────────────────────────────────

  /// Maximum concurrent image decode workers (Dart compute or FFmpeg).
  static const int maxImageWorkers = 2;

  /// Maximum concurrent video frame-extraction workers.
  static const int maxVideoWorkers = 1;

  // ── Timing ─────────────────────────────────────────────────────────────────

  /// Scroll-settle debounce in milliseconds before a full viewport interest
  /// update is triggered after the user stops scrolling.
  static const int scrollSettleDebounceMillis = 150;

  /// Grace period in milliseconds between SIGTERM and SIGKILL escalation when
  /// terminating a stale external thumbnailer process.
  static const int processGraceMillis = 300;

  // ── Generation threshold ───────────────────────────────────────────────────

  /// Maximum source-file size in bytes eligible for in-process Dart image
  /// decoding. Files above this threshold are routed to FFmpeg to preserve
  /// memory stability and UI responsiveness.
  static const int dartDecodeMaxBytes = 5 * 1024 * 1024; // 5 MB
}
