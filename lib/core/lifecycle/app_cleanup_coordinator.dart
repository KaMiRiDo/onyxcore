import 'package:flutter/foundation.dart';

/// Centralized coordinator for application lifecycle teardown and cleanup.
///
/// Orchestrates cleanup callbacks across subsystems without containing
/// subsystem-specific business logic.
class AppCleanupCoordinator {
  AppCleanupCoordinator({
    required this.thumbnailCleanup,
    required this.archiveCleanup,
  });

  /// Cleanup callback for active thumbnail sessions and worker processes.
  final VoidCallback thumbnailCleanup;

  /// Cleanup callback for archive extraction processes (e.g. 7z processes).
  final VoidCallback archiveCleanup;

  /// Executes all registered cleanup operations safely in sequence.
  void runAll() {
    try {
      thumbnailCleanup();
    } catch (e, st) {
      debugPrint('[AppCleanupCoordinator] Error during thumbnail cleanup: $e\n$st');
    }

    try {
      archiveCleanup();
    } catch (e, st) {
      debugPrint('[AppCleanupCoordinator] Error during archive cleanup: $e\n$st');
    }
  }
}
