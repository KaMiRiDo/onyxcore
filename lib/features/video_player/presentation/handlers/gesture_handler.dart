import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Typed callback bundle for [VideoGestureHandler].
class VideoGestureCallbacks {
  const VideoGestureCallbacks({
    required this.getPlayer,
    required this.getRef,
    required this.getMounted,
    required this.getIsClosing,
    required this.getIsScrubbing,
    required this.setIsScrubbing,
    required this.getIsFastSeeking,
    required this.setIsFastSeeking,
    required this.getVirtualSeekPosition,
    required this.setVirtualSeekPosition,
    required this.getVirtualScrubPosition,
    required this.setVirtualScrubPosition,
    required this.getPendingScrubPosition,
    required this.setPendingScrubPosition,
    required this.getVirtualVolume,
    required this.setVirtualVolume,
    required this.getVirtualSpeed,
    required this.setVirtualSpeed,
    required this.getScrollLockAxis,
    required this.setScrollLockAxis,
    required this.getWasPlayingBeforeScrub,
    required this.setWasPlayingBeforeScrub,
    required this.getLastKeyEventTime,
    required this.getEngineSeekTimer,
    required this.getVirtualSeekCleanupTimer,
    required this.setVirtualSeekCleanupTimer,
    required this.getFastSeekTimer,
    required this.getScrollResetTimer,
    required this.setScrollResetTimer,
    required this.getScrollVolumeTimer,
    required this.setScrollVolumeTimer,
    required this.getScrollSpeedTimer,
    required this.setScrollSpeedTimer,
    required this.getScrubThrottleTimer,
    required this.setScrubThrottleTimer,
    required this.getContextSize,
    required this.showVolumeOverlay,
    required this.showSpeedOverlay,
    required this.showSeekIndicator,
    required this.onInteraction,
    required this.cleanupVirtualSeeking,
    required this.setStateCallback,
  });

  final Player Function() getPlayer;
  final WidgetRef Function() getRef;
  final bool Function() getMounted;
  final bool Function() getIsClosing;
  final bool Function() getIsScrubbing;
  final void Function(bool) setIsScrubbing;
  final bool Function() getIsFastSeeking;
  final void Function(bool) setIsFastSeeking;
  final Duration? Function() getVirtualSeekPosition;
  final void Function(Duration?) setVirtualSeekPosition;
  final Duration? Function() getVirtualScrubPosition;
  final void Function(Duration?) setVirtualScrubPosition;
  final Duration? Function() getPendingScrubPosition;
  final void Function(Duration?) setPendingScrubPosition;
  final double? Function() getVirtualVolume;
  final void Function(double?) setVirtualVolume;
  final double? Function() getVirtualSpeed;
  final void Function(double?) setVirtualSpeed;
  final String? Function() getScrollLockAxis;
  final void Function(String?) setScrollLockAxis;
  final bool Function() getWasPlayingBeforeScrub;
  final void Function(bool) setWasPlayingBeforeScrub;
  final DateTime? Function() getLastKeyEventTime;
  final Timer? Function() getEngineSeekTimer;
  final Timer? Function() getVirtualSeekCleanupTimer;
  final void Function(Timer?) setVirtualSeekCleanupTimer;
  final Timer? Function() getFastSeekTimer;
  final Timer? Function() getScrollResetTimer;
  final void Function(Timer?) setScrollResetTimer;
  final Timer? Function() getScrollVolumeTimer;
  final void Function(Timer?) setScrollVolumeTimer;
  final Timer? Function() getScrollSpeedTimer;
  final void Function(Timer?) setScrollSpeedTimer;
  final Timer? Function() getScrubThrottleTimer;
  final void Function(Timer?) setScrubThrottleTimer;
  final Size? Function() getContextSize;
  final void Function() showVolumeOverlay;
  final void Function() showSpeedOverlay;
  final void Function() showSeekIndicator;
  final void Function() onInteraction;
  final void Function() cleanupVirtualSeeking;
  final void Function(void Function()) setStateCallback;
}

/// Encapsulates all pointer-scroll and trackpad pan-zoom gesture logic.
///
/// Mirrors lines 1508–1732 of `video_preview_widget.dart`.
class VideoGestureHandler {
  const VideoGestureHandler(this.c);

  final VideoGestureCallbacks c;

  void handlePointerScroll(PointerSignalEvent signal) {
    if (signal is PointerScrollEvent) {
      _processTrackpadGesture(
        signal.scrollDelta.dx,
        signal.scrollDelta.dy,
        signal.localPosition,
        isDiscrete: true,
      );
    }
  }

  void handlePointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _processTrackpadGesture(
      event.panDelta.dx,
      event.panDelta.dy,
      event.localPosition,
      isDiscrete: false,
    );
  }

  void handlePointerPanZoomEnd(PointerPanZoomEndEvent event) {
    resetTrackpadGesture();
  }

  void _processTrackpadGesture(
    double dx,
    double dy,
    Offset localPosition, {
    required bool isDiscrete,
  }) {
    final player = c.getPlayer();
    if (c.getScrollLockAxis() == null) {
      final settings = c.getRef().read(settingsProvider).value;
      final speedControlOption =
          settings?.trackpadSpeedControl ?? SpeedControlOption.off;
      final contextSize = c.getContextSize();
      final screenWidth = contextSize?.width ?? 0;

      if (dx.abs() > dy.abs() && dx.abs() > 0.5) {
        // Explicitly kill all step-seek state before initializing scrub
        c.setVirtualSeekPosition(null);
        c.setIsFastSeeking(false);
        c.getEngineSeekTimer()?.cancel();
        c.getVirtualSeekCleanupTimer()?.cancel();
        c.getFastSeekTimer()?.cancel();

        c.setScrollLockAxis('h');
        c.setIsScrubbing(true);
        if (c.getVirtualScrubPosition() == null) {
          c.setVirtualScrubPosition(player.state.position);
        }
        c.setWasPlayingBeforeScrub(player.state.playing);
        player.pause();
      } else if (dy.abs() > dx.abs() && dy.abs() > 0.5) {
        if (speedControlOption != SpeedControlOption.off &&
            localPosition.dx < screenWidth / 2) {
          c.setScrollLockAxis('speed');
          c.setVirtualSpeed(player.state.rate);
        } else {
          c.setScrollLockAxis('v');
          c.setVirtualVolume(player.state.volume);
        }
      } else {
        return;
      }
    }

    c.getScrollResetTimer()?.cancel();
    if (isDiscrete) {
      // For discrete scrolls (mouse wheel), use a timer because there's no "End" signal.
      c.setScrollResetTimer(
        Timer(const Duration(milliseconds: 1000), () {
          resetTrackpadGesture();
        }),
      );
    }
    // For continuous pan-zoom (trackpad), wait for the "End" event from the OS.

    if (c.getScrollLockAxis() == 'h') {
      _handleScrubScroll(dx);
    } else if (c.getScrollLockAxis() == 'v') {
      _handleVolumeScroll(dy);
    } else if (c.getScrollLockAxis() == 'speed') {
      _handleSpeedScroll(dy);
    }
  }

  void resetTrackpadGesture() {
    if (!c.getMounted()) return;

    // EPX-006: Ultra-tight 50ms window for blip rejection.
    final lastKeyTime = c.getLastKeyEventTime();
    if (lastKeyTime != null &&
        DateTime.now().difference(lastKeyTime).inMilliseconds < 50) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (c.getMounted()) resetTrackpadGesture();
      });
      return;
    }

    // Trigger the actual player speed change immediately BEFORE setState
    // to minimize perceived latency from the Flutter build/re-layout cycle.
    final player = c.getPlayer();
    if (c.getScrollLockAxis() == 'speed') {
      final settings = c.getRef().read(settingsProvider).value;
      final option = settings?.trackpadSpeedControl ?? SpeedControlOption.off;
      if (option == SpeedControlOption.releaseToNormal) {
        player.setRate(1.0);
      }
    }

    c.setStateCallback(() {
      if (c.getScrollLockAxis() == 'speed') {
        final settings = c.getRef().read(settingsProvider).value;
        final option =
            settings?.trackpadSpeedControl ?? SpeedControlOption.off;
        if (option == SpeedControlOption.releaseToNormal) {
          c.setVirtualSpeed(1.0);
          c.showSpeedOverlay();
        }
      }

      c.setScrollLockAxis(null);
      c.setVirtualVolume(null);
      c.setVirtualSpeed(null);

      if (c.getWasPlayingBeforeScrub()) {
        player.play();
        c.setWasPlayingBeforeScrub(false);
      }

      // Start the cleanup timer now that the physical gesture has ended.
      c.getVirtualSeekCleanupTimer()?.cancel();
      c.setVirtualSeekCleanupTimer(
        Timer(const Duration(seconds: 1), () {
          c.cleanupVirtualSeeking();
        }),
      );
    });
  }

  void _handleScrubScroll(double dx) {
    final player = c.getPlayer();
    final duration = player.state.duration;
    final scrubPos = c.getVirtualScrubPosition();
    if (duration > Duration.zero && scrubPos != null) {
      // 200ms per unit of dx is the sensitivity
      int newMs = scrubPos.inMilliseconds + (dx * 200).toInt();
      newMs = newMs.clamp(0, duration.inMilliseconds);
      c.setStateCallback(() {
        c.setVirtualScrubPosition(Duration(milliseconds: newMs));
        c.setPendingScrubPosition(c.getVirtualScrubPosition());
      });

      c.showSeekIndicator();
      c.onInteraction();

      // Reset cleanup timer to keep virtual position alive during gesture
      c.getVirtualSeekCleanupTimer()?.cancel();
      c.setVirtualSeekCleanupTimer(
        Timer(const Duration(seconds: 1), () {
          c.cleanupVirtualSeeking();
        }),
      );

      final pending = c.getPendingScrubPosition();
      if (c.getScrubThrottleTimer()?.isActive != true && pending != null) {
        player.seek(pending);
        c.setScrubThrottleTimer(
          Timer(const Duration(milliseconds: 100), () {
            final p = c.getPendingScrubPosition();
            if (p != null && c.getMounted() && c.getIsScrubbing()) {
              player.seek(p);
            }
          }),
        );
      }
    }
  }

  void _handleVolumeScroll(double dy) {
    final player = c.getPlayer();
    // Invert dy so that "scrolling up" (negative dy) increases volume.
    final isIncrease = dy < 0;
    final step = dy.abs() * 0.05;

    // Clamp resulting volume between 0.0 and 200.0.
    final currentVolume = c.getVirtualVolume() ?? player.state.volume;
    c.setVirtualVolume(
      (currentVolume + (isIncrease ? step : -step)).clamp(0.0, 200.0),
    );

    c.showVolumeOverlay();
    c.onInteraction();

    final vv = c.getVirtualVolume();
    if (c.getScrollVolumeTimer()?.isActive != true) {
      if (vv != null) player.setVolume(vv);
      c.setScrollVolumeTimer(
        Timer(const Duration(milliseconds: 30), () {
          if (c.getIsClosing() || !c.getMounted()) return;
          final v = c.getVirtualVolume();
          if (v != null) player.setVolume(v);
        }),
      );
    }
  }

  void _handleSpeedScroll(double dy) {
    final player = c.getPlayer();
    // Invert dy so that "scrolling up" (negative dy) increases speed.
    final isIncrease = dy < 0;
    // 0.005 means 200 pixels = 1.0x speed change.
    final step = dy.abs() * 0.005;

    // Clamp resulting speed between 0.25 and 4.0.
    final currentSpeed = c.getVirtualSpeed() ?? player.state.rate;
    c.setVirtualSpeed(
      (currentSpeed + (isIncrease ? step : -step)).clamp(0.25, 4.0),
    );

    c.showSpeedOverlay();
    c.onInteraction();

    final vs = c.getVirtualSpeed();
    if (c.getScrollSpeedTimer()?.isActive != true) {
      if (vs != null) player.setRate(vs);
      c.setScrollSpeedTimer(
        Timer(const Duration(milliseconds: 30), () {
          if (c.getIsClosing() || !c.getMounted()) return;
          final v = c.getVirtualSpeed();
          if (v != null) player.setRate(v);
        }),
      );
    }
  }
}
