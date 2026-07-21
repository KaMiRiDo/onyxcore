import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/state/video_player_state.dart';

void main() {
  group('VideoPlayerDisplayState', () {
    const defaultState = VideoPlayerDisplayState(
      isOpening: false,
      isSeekingToInitial: false,
      isSmartBuffering: false,
      isSeekLoading: false,
      isControlsVisible: true,
      isMarkerEditorActive: false,
      isMarkerMenuVisible: false,
      isGlobalHudVisible: false,
      isFastSeeking: false,
      isScrubbing: false,
      hasError: false,
      errorMessage: '',
      fps: null,
      showRemainingTime: false,
      isMuted: false,
      isVolumeOverlayVisible: false,
      showSpeedOverlayVisible: false,
      isSeekIndicatorVisible: false,
      showFlash: false,
      showSnapshotToast: false,
      isEmpty: false,
      isNetworkStream: false,
      playbackSpeed: 1.0,
      isAudioMenuVisible: false,
      isSubtitleMenuVisible: false,
      isSpeedMenuVisible: false,
      scrollLockAxis: null,
      windowId: null,
      isStandalone: false,
    );

    test('isAnyMenuVisible returns true if any menu is visible', () {
      expect(defaultState.isAnyMenuVisible, isFalse);
      expect(defaultState.copyWith(isAudioMenuVisible: true).isAnyMenuVisible, isTrue);
      expect(defaultState.copyWith(isSubtitleMenuVisible: true).isAnyMenuVisible, isTrue);
      expect(defaultState.copyWith(isSpeedMenuVisible: true).isAnyMenuVisible, isTrue);
      expect(defaultState.copyWith(isMarkerMenuVisible: true).isAnyMenuVisible, isTrue);
    });

    test('isHudVisible correctly calculates visibility based on dependencies', () {
      // By default isControlsVisible is true, scrollLockAxis is null
      // But windowId == null && isStandalone == false && isGlobalHudVisible == false
      // So isHudVisible should be false for a standard embedded widget unless global hud is visible
      expect(defaultState.isHudVisible, isFalse);

      // If it's standalone, it should be visible
      expect(defaultState.copyWith(isStandalone: true).isHudVisible, isTrue);

      // If it has a windowId, it should be visible
      expect(defaultState.copyWith(windowId: '1').isHudVisible, isTrue);

      // If global hud is visible, it should be visible
      expect(defaultState.copyWith(isGlobalHudVisible: true).isHudVisible, isTrue);

      // If scroll lock axis is active, hud should be hidden regardless
      expect(
        defaultState.copyWith(isGlobalHudVisible: true, scrollLockAxis: 'vertical').isHudVisible,
        isFalse,
      );

      // If controls, marker editor and menu are all false, hud is hidden
      expect(
        defaultState.copyWith(isGlobalHudVisible: true, isControlsVisible: false).isHudVisible,
        isFalse,
      );
    });

    test('copyWith updates properties', () {
      final updated = defaultState.copyWith(
        isOpening: true,
        errorMessage: 'Error',
        playbackSpeed: 2.0,
        scrollLockAxis: 'horizontal',
      );

      expect(updated.isOpening, isTrue);
      expect(updated.errorMessage, 'Error');
      expect(updated.playbackSpeed, 2.0);
      expect(updated.scrollLockAxis, 'horizontal');

      // Unchanged properties remain the same
      expect(updated.isMuted, defaultState.isMuted);
      expect(updated.isControlsVisible, defaultState.isControlsVisible);
    });

    test('equality and hashCode works', () {
      final state1 = defaultState.copyWith(isMuted: true);
      final state2 = defaultState.copyWith(isMuted: true);
      final state3 = defaultState.copyWith(isMuted: false);

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      expect(state1, isNot(equals(state3)));
      expect(state1.hashCode, isNot(equals(state3.hashCode)));
    });
  });
}
