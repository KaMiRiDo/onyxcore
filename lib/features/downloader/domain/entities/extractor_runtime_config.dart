import 'package:flutter/foundation.dart';

/// Immutable configuration for the extractor runtime.
///
/// All timeouts are in milliseconds. Defaults are conservative but suitable
/// for real-world pages. Phase 1.1 hardcodes these; future phases may expose
/// them in Settings.
@immutable
class ExtractorRuntimeConfig {
  const ExtractorRuntimeConfig({
    this.navigationTimeoutMs = 30000,
    this.extractorTimeoutMs = 30000,
    this.settleDelayMs = 500,
    this.maxResults = 500,
  });

  /// Maximum time to wait for page navigation to complete (ms).
  final int navigationTimeoutMs;

  /// Maximum time to allow the extractor script to run (ms).
  final int extractorTimeoutMs;

  /// Fixed settle delay after page load before executing the
  /// extractor. Allows SPAs to finish client-side rendering (hardcoded for
  /// Phase 1.1).
  final int settleDelayMs;

  /// Maximum number of URLs an extractor may return. Excess results are
  /// rejected with a clear error rather than silently truncated.
  final int maxResults;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractorRuntimeConfig &&
          other.navigationTimeoutMs == navigationTimeoutMs &&
          other.extractorTimeoutMs == extractorTimeoutMs &&
          other.settleDelayMs == settleDelayMs &&
          other.maxResults == maxResults;

  @override
  int get hashCode => Object.hash(
        navigationTimeoutMs,
        extractorTimeoutMs,
        settleDelayMs,
        maxResults,
      );
}
