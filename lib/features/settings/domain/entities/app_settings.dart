import 'package:equatable/equatable.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

/// Immutable application settings entity.
///
/// Only includes settings that are actually used in the Linux application.
/// Android-specific settings (biometric auth, vault, singleTapPlayPause)
/// have been removed.
class AppSettings extends Equatable {
  const AppSettings({
    this.autoPlayNext = true,
    this.showHiddenFiles = false,
    this.snapshotPrefix = 'snapshot',
    this.doubleTapSeekSeconds = 10,
    this.pinnedFolders = const [],
    this.gallerySortSettings = const {},
    this.maxConcurrentTasks = 3,
    this.globalSortOption = SortOption.aToZ,
    this.resumePlayback = true,
    this.audioSeekSeconds = 5,
    this.selectedHwDec = 'auto',
    this.cachedResolvedHwDec,
  });

  /// Whether to automatically play the next video in the playlist.
  final bool autoPlayNext;

  /// Whether to show hidden files (starting with .) in the file manager.
  final bool showHiddenFiles;

  /// Prefix for snapshot filenames (e.g., "snapshot_1234567890.png").
  final String snapshotPrefix;

  /// Number of seconds to seek on double-tap (left/right).
  final int doubleTapSeekSeconds;

  /// List of pinned folder paths (ordered).
  final List<String> pinnedFolders;

  /// Per-folder sort settings (path → sortKey).
  final Map<String, String> gallerySortSettings;

  /// Maximum number of simultaneous background tasks.
  final int maxConcurrentTasks;

  /// Global fallback sort option.
  final SortOption globalSortOption;
  
  /// Whether to resume video playback from last known position.
  final bool resumePlayback;

  /// Number of seconds to seek in audio player (left/right arrows).
  final int audioSeekSeconds;

  /// User selected hardware decoder option (e.g. 'auto', 'vaapi', 'nvdec', 'software').
  final String selectedHwDec;

  /// The actual hardware decoder driver resolved by the engine last time.
  final String? cachedResolvedHwDec;

  AppSettings copyWith({
    bool? autoPlayNext,
    bool? showHiddenFiles,
    String? snapshotPrefix,
    int? doubleTapSeekSeconds,
    List<String>? pinnedFolders,
    Map<String, String>? gallerySortSettings,
    int? maxConcurrentTasks,
    SortOption? globalSortOption,
    bool? resumePlayback,
    int? audioSeekSeconds,
    String? selectedHwDec,
    String? cachedResolvedHwDec,
  }) {
    return AppSettings(
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      snapshotPrefix: snapshotPrefix ?? this.snapshotPrefix,
      doubleTapSeekSeconds: doubleTapSeekSeconds ?? this.doubleTapSeekSeconds,
      pinnedFolders: pinnedFolders ?? this.pinnedFolders,
      gallerySortSettings: gallerySortSettings ?? this.gallerySortSettings,
      maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
      globalSortOption: globalSortOption ?? this.globalSortOption,
      resumePlayback: resumePlayback ?? this.resumePlayback,
      audioSeekSeconds: audioSeekSeconds ?? this.audioSeekSeconds,
      selectedHwDec: selectedHwDec ?? this.selectedHwDec,
      cachedResolvedHwDec: cachedResolvedHwDec ?? this.cachedResolvedHwDec,
    );
  }

  @override
  List<Object?> get props => [
    autoPlayNext,
    showHiddenFiles,
    snapshotPrefix,
    doubleTapSeekSeconds,
    pinnedFolders,
    gallerySortSettings,
    maxConcurrentTasks,
    globalSortOption,
    resumePlayback,
    audioSeekSeconds,
    selectedHwDec,
    cachedResolvedHwDec,
  ];
}
