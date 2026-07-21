import 'package:flutter/foundation.dart';

/// Immutable snapshot of all display-relevant boolean flags and scalar values
/// used by overlay and HUD widgets.
///
/// The coordinator (`_VideoPreviewWidgetState`) builds one of these and passes
/// it down so child widgets never need to read from the state class directly.
/// This prevents unnecessary rebuilds — widgets only rebuild when the fields
/// they care about actually change.
@immutable
class VideoPlayerDisplayState {
  const VideoPlayerDisplayState({
    required this.isOpening,
    required this.isSeekingToInitial,
    required this.isSmartBuffering,
    required this.isSeekLoading,
    required this.isControlsVisible,
    required this.isMarkerEditorActive,
    required this.isMarkerMenuVisible,
    required this.isGlobalHudVisible,
    required this.isFastSeeking,
    required this.isScrubbing,
    required this.hasError,
    required this.errorMessage,
    required this.fps,
    required this.showRemainingTime,
    required this.isMuted,
    required this.isVolumeOverlayVisible,
    required this.showSpeedOverlayVisible,
    required this.isSeekIndicatorVisible,
    required this.showFlash,
    required this.showSnapshotToast,
    required this.isEmpty,
    required this.isNetworkStream,
    required this.playbackSpeed,
    required this.isAudioMenuVisible,
    required this.isSubtitleMenuVisible,
    required this.isSpeedMenuVisible,
    required this.scrollLockAxis,
    required this.windowId,
    required this.isStandalone,
  });

  // Loading / buffering
  final bool isOpening;
  final bool isSeekingToInitial;
  final bool isSmartBuffering;
  final bool isSeekLoading;

  // HUD visibility
  final bool isControlsVisible;
  final bool isMarkerEditorActive;
  final bool isMarkerMenuVisible;
  final bool isGlobalHudVisible;

  // Seek state
  final bool isFastSeeking;
  final bool isScrubbing;

  // Error / empty
  final bool hasError;
  final String errorMessage;
  final bool isEmpty;

  // Metadata
  final double? fps;
  final bool showRemainingTime;
  final bool isNetworkStream;
  final double playbackSpeed;

  // Audio
  final bool isMuted;

  // Overlays
  final bool isVolumeOverlayVisible;
  final bool showSpeedOverlayVisible;
  final bool isSeekIndicatorVisible;
  final bool showFlash;
  final bool showSnapshotToast;

  // Menu state
  final bool isAudioMenuVisible;
  final bool isSubtitleMenuVisible;
  final bool isSpeedMenuVisible;

  // Gesture lock axis — null means no active gesture
  final String? scrollLockAxis;

  // Window
  final String? windowId;
  final bool isStandalone;

  /// True when any dropdown/popup menu is visible.
  bool get isAnyMenuVisible =>
      isAudioMenuVisible ||
      isSubtitleMenuVisible ||
      isSpeedMenuVisible ||
      isMarkerMenuVisible;

  /// Whether the HUD (top bar, bottom controls) should currently be shown.
  ///
  /// Mirrors the `isVisible` computation in the original build() method.
  bool get isHudVisible =>
      (isControlsVisible || isMarkerEditorActive || isMarkerMenuVisible) &&
      scrollLockAxis == null &&
      (windowId != null || isStandalone || isGlobalHudVisible);

  VideoPlayerDisplayState copyWith({
    bool? isOpening,
    bool? isSeekingToInitial,
    bool? isSmartBuffering,
    bool? isSeekLoading,
    bool? isControlsVisible,
    bool? isMarkerEditorActive,
    bool? isMarkerMenuVisible,
    bool? isGlobalHudVisible,
    bool? isFastSeeking,
    bool? isScrubbing,
    bool? hasError,
    String? errorMessage,
    double? fps,
    bool? showRemainingTime,
    bool? isMuted,
    bool? isVolumeOverlayVisible,
    bool? showSpeedOverlayVisible,
    bool? isSeekIndicatorVisible,
    bool? showFlash,
    bool? showSnapshotToast,
    bool? isEmpty,
    bool? isNetworkStream,
    double? playbackSpeed,
    bool? isAudioMenuVisible,
    bool? isSubtitleMenuVisible,
    bool? isSpeedMenuVisible,
    String? scrollLockAxis,
    String? windowId,
    bool? isStandalone,
  }) {
    return VideoPlayerDisplayState(
      isOpening: isOpening ?? this.isOpening,
      isSeekingToInitial: isSeekingToInitial ?? this.isSeekingToInitial,
      isSmartBuffering: isSmartBuffering ?? this.isSmartBuffering,
      isSeekLoading: isSeekLoading ?? this.isSeekLoading,
      isControlsVisible: isControlsVisible ?? this.isControlsVisible,
      isMarkerEditorActive: isMarkerEditorActive ?? this.isMarkerEditorActive,
      isMarkerMenuVisible: isMarkerMenuVisible ?? this.isMarkerMenuVisible,
      isGlobalHudVisible: isGlobalHudVisible ?? this.isGlobalHudVisible,
      isFastSeeking: isFastSeeking ?? this.isFastSeeking,
      isScrubbing: isScrubbing ?? this.isScrubbing,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      fps: fps ?? this.fps,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      isMuted: isMuted ?? this.isMuted,
      isVolumeOverlayVisible:
          isVolumeOverlayVisible ?? this.isVolumeOverlayVisible,
      showSpeedOverlayVisible:
          showSpeedOverlayVisible ?? this.showSpeedOverlayVisible,
      isSeekIndicatorVisible:
          isSeekIndicatorVisible ?? this.isSeekIndicatorVisible,
      showFlash: showFlash ?? this.showFlash,
      showSnapshotToast: showSnapshotToast ?? this.showSnapshotToast,
      isEmpty: isEmpty ?? this.isEmpty,
      isNetworkStream: isNetworkStream ?? this.isNetworkStream,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isAudioMenuVisible: isAudioMenuVisible ?? this.isAudioMenuVisible,
      isSubtitleMenuVisible:
          isSubtitleMenuVisible ?? this.isSubtitleMenuVisible,
      isSpeedMenuVisible: isSpeedMenuVisible ?? this.isSpeedMenuVisible,
      scrollLockAxis: scrollLockAxis ?? this.scrollLockAxis,
      windowId: windowId ?? this.windowId,
      isStandalone: isStandalone ?? this.isStandalone,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoPlayerDisplayState &&
        other.isOpening == isOpening &&
        other.isSeekingToInitial == isSeekingToInitial &&
        other.isSmartBuffering == isSmartBuffering &&
        other.isSeekLoading == isSeekLoading &&
        other.isControlsVisible == isControlsVisible &&
        other.isMarkerEditorActive == isMarkerEditorActive &&
        other.isMarkerMenuVisible == isMarkerMenuVisible &&
        other.isGlobalHudVisible == isGlobalHudVisible &&
        other.isFastSeeking == isFastSeeking &&
        other.isScrubbing == isScrubbing &&
        other.hasError == hasError &&
        other.errorMessage == errorMessage &&
        other.fps == fps &&
        other.showRemainingTime == showRemainingTime &&
        other.isMuted == isMuted &&
        other.isVolumeOverlayVisible == isVolumeOverlayVisible &&
        other.showSpeedOverlayVisible == showSpeedOverlayVisible &&
        other.isSeekIndicatorVisible == isSeekIndicatorVisible &&
        other.showFlash == showFlash &&
        other.showSnapshotToast == showSnapshotToast &&
        other.isEmpty == isEmpty &&
        other.isNetworkStream == isNetworkStream &&
        other.playbackSpeed == playbackSpeed &&
        other.isAudioMenuVisible == isAudioMenuVisible &&
        other.isSubtitleMenuVisible == isSubtitleMenuVisible &&
        other.isSpeedMenuVisible == isSpeedMenuVisible &&
        other.scrollLockAxis == scrollLockAxis &&
        other.windowId == windowId &&
        other.isStandalone == isStandalone;
  }

  @override
  int get hashCode => Object.hashAll([
    isOpening,
    isSeekingToInitial,
    isSmartBuffering,
    isSeekLoading,
    isControlsVisible,
    isMarkerEditorActive,
    isMarkerMenuVisible,
    isGlobalHudVisible,
    isFastSeeking,
    isScrubbing,
    hasError,
    errorMessage,
    fps,
    showRemainingTime,
    isMuted,
    isVolumeOverlayVisible,
    showSpeedOverlayVisible,
    isSeekIndicatorVisible,
    showFlash,
    showSnapshotToast,
    isEmpty,
    isNetworkStream,
    playbackSpeed,
    isAudioMenuVisible,
    isSubtitleMenuVisible,
    isSpeedMenuVisible,
    scrollLockAxis,
    windowId,
    isStandalone,
  ]);
}
