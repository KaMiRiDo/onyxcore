import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Manages the lifecycle of thumbnail generation sessions.
///
/// Ensures:
/// 1. Only the active tab owns a live ThumbnailSession.
/// 2. Navigating to a new folder cancels the previous session and creates a new one.
/// 3. Switching active tabs cancels background sessions and creates/activates the active tab's session.
/// 4. Disposing the manager or application cancels and cleans up running/pending thumbnail jobs.
/// 5. Browsing inside the thumbnail cache directory does not spawn a thumbnail session (prevents recursive generation).
class ThumbnailSessionManager extends Notifier<ThumbnailSession?> {
  ThumbnailSession? _currentSession;

  @override
  ThumbnailSession? build() {
    final activeTabId = ref.watch(activeTabIdProvider);
    final currentTabId = ref.watch(tabIdProvider);
    ref.watch(refreshCountProvider);

    // Cancel existing session whenever build() re-runs
    _cancelCurrentSession();

    // If this provider instance is scoped to a non-active tab, do not create a session
    if (activeTabId != currentTabId) {
      return null;
    }

    final currentPath = ref.watch(currentPathProvider);

    // Check if the current folder is inside the thumbnail cache directory
    if (ThumbnailCacheService.isThumbnailCachePath(currentPath)) {
      return null;
    }

    final cacheService = ref.watch(thumbnailCacheServiceProvider);
    final session = ThumbnailSession(
      folderPath: currentPath,
      tabId: currentTabId,
      cacheService: cacheService,
    );
    _currentSession = session;

    ref.onDispose(() {
      session.dispose();
      if (identical(_currentSession, session)) {
        _currentSession = null;
      }
    });

    return session;
  }

  void _cancelCurrentSession() {
    _currentSession?.cancel();
    _currentSession = null;
  }

  /// Explicitly disposes the current session on application shutdown.
  void disposeCurrentSession() {
    _currentSession?.dispose();
    _currentSession = null;
    state = null;
  }

  static bool isThumbnailCacheDir(String path) {
    return ThumbnailCacheService.isThumbnailCachePath(path);
  }
}

/// Provider for the active thumbnail session.
final activeThumbnailSessionProvider =
    NotifierProvider<ThumbnailSessionManager, ThumbnailSession?>(
      ThumbnailSessionManager.new,
    );
