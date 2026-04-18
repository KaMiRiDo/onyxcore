import 'package:equatable/equatable.dart';

/// Immutable application settings entity.
///
/// Only includes settings that are actually used in the Linux application.
/// Android-specific settings (biometric auth, vault, singleTapPlayPause)
/// have been removed.
class AppSettings extends Equatable {
  const AppSettings({
    this.autoPlayNext = false,
    this.snapshotPrefix = 'snapshot',
    this.doubleTapSeekSeconds = 10,
    this.pinnedFolders = const [],
    this.gallerySortSettings = const {},
  });

  /// Whether to automatically play the next video in the playlist.
  final bool autoPlayNext;

  /// Prefix for snapshot filenames (e.g., "snapshot_1234567890.png").
  final String snapshotPrefix;

  /// Number of seconds to seek on double-tap (left/right).
  final int doubleTapSeekSeconds;

  /// List of pinned folder paths (ordered).
  final List<String> pinnedFolders;

  /// Per-folder sort settings (path → sortKey).
  final Map<String, String> gallerySortSettings;

  AppSettings copyWith({
    bool? autoPlayNext,
    String? snapshotPrefix,
    int? doubleTapSeekSeconds,
    List<String>? pinnedFolders,
    Map<String, String>? gallerySortSettings,
  }) {
    return AppSettings(
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      snapshotPrefix: snapshotPrefix ?? this.snapshotPrefix,
      doubleTapSeekSeconds: doubleTapSeekSeconds ?? this.doubleTapSeekSeconds,
      pinnedFolders: pinnedFolders ?? this.pinnedFolders,
      gallerySortSettings: gallerySortSettings ?? this.gallerySortSettings,
    );
  }

  @override
  List<Object?> get props => [
    autoPlayNext,
    snapshotPrefix,
    doubleTapSeekSeconds,
    pinnedFolders,
    gallerySortSettings,
  ];
}
