import 'package:equatable/equatable.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

/// Options for the trackpad speed control gesture.
enum SpeedControlOption {
  off('Off'),
  releaseToNormal('Release to Normal'),
  releaseToFix('Release to Fix');

  final String label;
  const SpeedControlOption(this.label);
}

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
    this.trackpadSpeedControl = SpeedControlOption.off,
    this.showMarkersOnTimeline = true,
    this.filePickerWidth = 1000.0,
    this.filePickerHeight = 650.0,
    this.settingsWidth = 760.0,
    this.settingsHeight = 560.0,
    this.downloaderWidth = 750.0,
    this.downloaderHeight = 560.0,
    this.confirmDeleteImage = true,
    this.confirmDeleteVideo = true,
    this.confirmDeleteDocument = true,
    this.confirmDeleteAudio = true,
    this.showHiddenAudioFiles = false,
    this.downloadBrowser,
  });

  /// Whether to automatically play the next video in the playlist.
  final bool autoPlayNext;

  /// Whether to show hidden files (starting with .) in the file manager.
  final bool showHiddenFiles;

  /// Whether to show hidden files (starting with .) in the audio player.
  final bool showHiddenAudioFiles;

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

  /// Whether vertical scroll on the left side of the screen controls playback speed, and how it behaves on release.
  final SpeedControlOption trackpadSpeedControl;

  /// Whether to render markers on the video timeline.
  final bool showMarkersOnTimeline;

  /// Default width for the custom file picker.
  final double filePickerWidth;

  /// Default height for the custom file picker.
  final double filePickerHeight;

  /// Default width for the settings dialog.
  final double settingsWidth;

  /// Default height for the settings dialog.
  final double settingsHeight;

  /// Default width for the media downloader dialog.
  final double downloaderWidth;

  /// Default height for the media downloader dialog.
  final double downloaderHeight;

  /// Whether to ask for confirmation when deleting images.
  final bool confirmDeleteImage;

  /// Whether to ask for confirmation when deleting videos.
  final bool confirmDeleteVideo;

  /// Whether to ask for confirmation when deleting documents.
  final bool confirmDeleteDocument;

  /// Whether to ask for confirmation when deleting audio files.
  final bool confirmDeleteAudio;

  /// The browser used for cookie extraction in the downloader. If null, use the default. If 'None', disable.
  final String? downloadBrowser;

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
    SpeedControlOption? trackpadSpeedControl,
    bool? showMarkersOnTimeline,
    double? filePickerWidth,
    double? filePickerHeight,
    double? settingsWidth,
    double? settingsHeight,
    double? downloaderWidth,
    double? downloaderHeight,
    bool? confirmDeleteImage,
    bool? confirmDeleteVideo,
    bool? confirmDeleteDocument,
    bool? confirmDeleteAudio,
    bool? showHiddenAudioFiles,
    String? downloadBrowser,
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
      trackpadSpeedControl: trackpadSpeedControl ?? this.trackpadSpeedControl,
      showMarkersOnTimeline: showMarkersOnTimeline ?? this.showMarkersOnTimeline,
      filePickerWidth: filePickerWidth ?? this.filePickerWidth,
      filePickerHeight: filePickerHeight ?? this.filePickerHeight,
      settingsWidth: settingsWidth ?? this.settingsWidth,
      settingsHeight: settingsHeight ?? this.settingsHeight,
      downloaderWidth: downloaderWidth ?? this.downloaderWidth,
      downloaderHeight: downloaderHeight ?? this.downloaderHeight,
      confirmDeleteImage: confirmDeleteImage ?? this.confirmDeleteImage,
      confirmDeleteVideo: confirmDeleteVideo ?? this.confirmDeleteVideo,
      confirmDeleteDocument: confirmDeleteDocument ?? this.confirmDeleteDocument,
      confirmDeleteAudio: confirmDeleteAudio ?? this.confirmDeleteAudio,
      showHiddenAudioFiles: showHiddenAudioFiles ?? this.showHiddenAudioFiles,
      downloadBrowser: downloadBrowser ?? this.downloadBrowser,
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
    trackpadSpeedControl,
    showMarkersOnTimeline,
    filePickerWidth,
    filePickerHeight,
    settingsWidth,
    settingsHeight,
    downloaderWidth,
    downloaderHeight,
    confirmDeleteImage,
    confirmDeleteVideo,
    confirmDeleteDocument,
    confirmDeleteAudio,
    showHiddenAudioFiles,
    downloadBrowser,
  ];
}
