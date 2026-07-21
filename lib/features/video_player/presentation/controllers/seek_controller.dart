import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Typed callback bundle that gives [VideoSeekController] full access to the
/// coordinator's mutable state **without** holding a reference to the State class.
class VideoSeekCallbacks {
  const VideoSeekCallbacks({
    required this.getPlayer,
    required this.getRef,
    required this.getMounted,
    required this.getIsClosing,
    required this.getIsFastSeeking,
    required this.setIsFastSeeking,
    required this.getIsScrubbing,
    required this.setIsScrubbing,
    required this.getVirtualSeekPosition,
    required this.setVirtualSeekPosition,
    required this.getVirtualScrubPosition,
    required this.setVirtualScrubPosition,
    required this.getPendingScrubPosition,
    required this.setPendingScrubPosition,
    required this.getWasPlayingBeforeScrub,
    required this.setWasPlayingBeforeScrub,
    required this.getIsSmartBuffering,
    required this.setIsSmartBuffering,
    required this.getScrollLockAxis,
    required this.getActiveSeekKey,
    required this.setActiveSeekKey,
    required this.getLastEngineSeekTime,
    required this.setLastEngineSeekTime,
    required this.getThrottleMs,
    required this.getDebounceMs,
    required this.getCleanupRetryCount,
    required this.setCleanupRetryCount,
    required this.getEngineSeekTimer,
    required this.setEngineSeekTimer,
    required this.getVirtualSeekCleanupTimer,
    required this.setVirtualSeekCleanupTimer,
    required this.getFastSeekTimer,
    required this.setFastSeekTimer,
    required this.getSeekLoaderTimer,
    required this.setSeekLoaderTimer,
    required this.setIsSeekLoading,
    required this.setPreSeekPosition,
    required this.setLastSeekTime,
    required this.showSeekIndicator,
    required this.onInteraction,
    required this.setStateCallback,
  });

  final Player Function() getPlayer;
  final WidgetRef Function() getRef;
  final bool Function() getMounted;
  final bool Function() getIsClosing;
  final bool Function() getIsFastSeeking;
  final void Function(bool) setIsFastSeeking;
  final bool Function() getIsScrubbing;
  final void Function(bool) setIsScrubbing;
  final Duration? Function() getVirtualSeekPosition;
  final void Function(Duration?) setVirtualSeekPosition;
  final Duration? Function() getVirtualScrubPosition;
  final void Function(Duration?) setVirtualScrubPosition;
  final Duration? Function() getPendingScrubPosition;
  final void Function(Duration?) setPendingScrubPosition;
  final bool Function() getWasPlayingBeforeScrub;
  final void Function(bool) setWasPlayingBeforeScrub;
  final bool Function() getIsSmartBuffering;
  final void Function(bool) setIsSmartBuffering;
  final String? Function() getScrollLockAxis;
  final LogicalKeyboardKey? Function() getActiveSeekKey;
  final void Function(LogicalKeyboardKey?) setActiveSeekKey;
  final DateTime Function() getLastEngineSeekTime;
  final void Function(DateTime) setLastEngineSeekTime;
  final int Function() getThrottleMs;
  final int Function() getDebounceMs;
  final int Function() getCleanupRetryCount;
  final void Function(int) setCleanupRetryCount;
  final Timer? Function() getEngineSeekTimer;
  final void Function(Timer?) setEngineSeekTimer;
  final Timer? Function() getVirtualSeekCleanupTimer;
  final void Function(Timer?) setVirtualSeekCleanupTimer;
  final Timer? Function() getFastSeekTimer;
  final void Function(Timer?) setFastSeekTimer;
  final Timer? Function() getSeekLoaderTimer;
  final void Function(Timer?) setSeekLoaderTimer;
  final void Function(bool) setIsSeekLoading;
  final void Function(Duration?) setPreSeekPosition;
  final void Function(DateTime) setLastSeekTime;
  final void Function() showSeekIndicator;
  final void Function() onInteraction;
  final void Function(void Function()) setStateCallback;
}

/// Encapsulates all seek-related logic: throttle+debounce engine, fast-seek
/// timer, step-seek, and virtual-state cleanup.
///
/// Mirrors lines 1518–1691 of `video_preview_widget.dart`.
class VideoSeekController {
  const VideoSeekController(this.c);

  final VideoSeekCallbacks c;

  // ── Seek Engine Gateway (Throttle + Debounce) ─────────────────────

  void requestEngineSeek(Duration targetPosition) {
    // Clear lingering scrub state so displayPosition uses the seek target
    c.setIsScrubbing(false);
    c.setVirtualScrubPosition(null);
    c.setPendingScrubPosition(null);

    // 1. Instantly update the UI's source of truth
    c.setStateCallback(() => c.setVirtualSeekPosition(targetPosition));

    // 2. Prevent play/seek fighting during rapid inputs
    final player = c.getPlayer();
    if (player.state.playing && !c.getIsFastSeeking()) {
      c.setWasPlayingBeforeScrub(true);
      player.pause();
    }

    final now = DateTime.now();
    final timeSinceLastSeek =
        now.difference(c.getLastEngineSeekTime()).inMilliseconds;

    // Cancel any pending debounced seek
    c.getEngineSeekTimer()?.cancel();

    if (timeSinceLastSeek > c.getThrottleMs()) {
      // THROTTLE: Give the user a visual frame update right now.
      _dispatchToEngine(targetPosition);
    } else {
      // DEBOUNCE: Protect the engine from starvation. Wait for clicks to settle.
      c.setEngineSeekTimer(
        Timer(Duration(milliseconds: c.getDebounceMs()), () {
          final vp = c.getVirtualSeekPosition();
          if (vp != null && c.getMounted()) {
            _dispatchToEngine(vp);
          }
        }),
      );
    }
  }

  void performSeek(Duration target) {
    c.setPreSeekPosition(c.getPlayer().state.position);
    c.setLastSeekTime(DateTime.now());
    c.getSeekLoaderTimer()?.cancel();
    c.setSeekLoaderTimer(
      Timer(const Duration(milliseconds: 150), () {
        if (c.getMounted() && !c.getIsClosing()) {
          c.setStateCallback(() => c.setIsSeekLoading(true));
        }
      }),
    );
    c.getPlayer().seek(target);
  }

  void _dispatchToEngine(Duration target) {
    c.setLastEngineSeekTime(DateTime.now());
    performSeek(target);
    scheduleVirtualStateCleanup();
  }

  void scheduleVirtualStateCleanup({bool isRetry = false}) {
    // CRITICAL: Kill ghost timers to prevent snapbacks
    c.getVirtualSeekCleanupTimer()?.cancel();
    if (!isRetry) c.setCleanupRetryCount(0); // Reset only on fresh schedule

    // Wait 1200ms for mpv to lock onto the keyframe and update its stream
    c.setVirtualSeekCleanupTimer(
      Timer(const Duration(milliseconds: 1200), () {
        final engineTimer = c.getEngineSeekTimer();
        if (engineTimer?.isActive ?? false) {
          // Safety net: Prevent infinite reschedule loop
          final retries = c.getCleanupRetryCount();
          c.setCleanupRetryCount(retries + 1);
          if (retries + 1 < 5) {
            scheduleVirtualStateCleanup(isRetry: true);
            return;
          }
          // If we hit 5 retries, fall through and force cleanup anyway
        }

        if (!c.getMounted()) return;

        c.setStateCallback(() {
          c.setVirtualSeekPosition(null);
          c.setIsFastSeeking(false);
        });

        if (c.getWasPlayingBeforeScrub()) {
          c.getPlayer().play();
          c.setWasPlayingBeforeScrub(false);
        }
      }),
    );
  }

  // ── Seek Triggers ─────────────────────────────────────────────────

  void startFastSeek({required bool isForward}) {
    c.setStateCallback(() => c.setIsFastSeeking(true));

    performStepSeek(isForward: isForward);

    c.getFastSeekTimer()?.cancel();
    c.setFastSeekTimer(
      Timer.periodic(const Duration(milliseconds: 200), (_) {
        performStepSeek(isForward: isForward);
      }),
    );
  }

  void performStepSeek({required bool isForward}) {
    // STRICT HANDOFF GUARD: If we have a valid scrub position, it means we
    // just finished scrubbing. Invalidate any dormant fast-seek state.
    if (c.getVirtualScrubPosition() != null) {
      c.setIsFastSeeking(false);
      c.setVirtualSeekPosition(null);
    }

    final currentBase =
        (c.getIsFastSeeking() ? c.getVirtualSeekPosition() : null) ??
        c.getVirtualScrubPosition() ??
        c.getPlayer().state.position;

    final seekSeconds =
        c.getRef().read(settingsProvider).value?.doubleTapSeekSeconds ?? 10;
    final step = Duration(seconds: seekSeconds);

    Duration target =
        isForward ? currentBase + step : currentBase - step;

    // Clamp to valid range
    if (target < Duration.zero) target = Duration.zero;
    final dur = c.getPlayer().state.duration;
    if (dur > Duration.zero && target > dur) target = dur;

    c.setStateCallback(() {
      c.setIsFastSeeking(true);
      // Clear scrub position now that we have safely used it as the base
      c.setVirtualScrubPosition(null);
      c.setIsScrubbing(false);
    });

    c.showSeekIndicator();
    c.onInteraction();
    requestEngineSeek(target);
  }

  void stopFastSeek() {
    c.getFastSeekTimer()?.cancel();
    c.setFastSeekTimer(null);
    c.setActiveSeekKey(null);

    // Force the debouncer to fire immediately on key release
    final engineTimer = c.getEngineSeekTimer();
    if (engineTimer?.isActive ?? false) {
      engineTimer?.cancel();
      final vp = c.getVirtualSeekPosition();
      if (vp != null) {
        _dispatchToEngine(vp);
      }
    }
  }

  // ── Shared Utilities ──────────────────────────────────────────────

  void cleanupVirtualSeeking() {
    if (!c.getMounted()) return;

    // If a trackpad gesture is still active (fingers on pad),
    // don't clear the virtual position yet.
    if (c.getScrollLockAxis() != null) return;

    c.setStateCallback(() {
      c.setIsFastSeeking(false);
      c.setVirtualSeekPosition(null);
      c.setIsScrubbing(false);
      c.setVirtualScrubPosition(null);
      c.setPendingScrubPosition(null);
      c.setIsSmartBuffering(false);
    });

    if (c.getWasPlayingBeforeScrub()) {
      c.getPlayer().play();
      c.setWasPlayingBeforeScrub(false);
    }
  }

  // ── Slider Handlers ───────────────────────────────────────────────

  void handleSliderChangeStart() {
    c.setStateCallback(() {
      c.setVirtualSeekPosition(null);
      c.setIsFastSeeking(false);
      c.getEngineSeekTimer()?.cancel();
      c.getVirtualSeekCleanupTimer()?.cancel();
      c.getFastSeekTimer()?.cancel();
      c.setIsScrubbing(true);
      c.setWasPlayingBeforeScrub(c.getPlayer().state.playing);
    });
    c.getPlayer().pause();
  }

  void handleSliderChanged(double v) {
    c.onInteraction();
    c.showSeekIndicator();
    final duration = c.getPlayer().state.duration;
    final targetMs = (v * duration.inMilliseconds).toInt();
    
    c.setStateCallback(() {
      c.setVirtualScrubPosition(Duration(milliseconds: targetMs));
      c.setPendingScrubPosition(Duration(milliseconds: targetMs));
    });
    
    // In our simplified slider handler, we just dispatch instantly because throttle is handled externally or we can implement it here.
    // For simplicity, we just perform seek.
    final pending = c.getPendingScrubPosition();
    if (pending != null) {
      performSeek(pending);
    }
  }

  void handleSliderChangeEnd(double v) {
    final duration = c.getPlayer().state.duration;
    performSeek(Duration(milliseconds: (v * duration.inMilliseconds).toInt()));
    
    if (c.getWasPlayingBeforeScrub()) {
      c.getPlayer().play();
      c.setWasPlayingBeforeScrub(false);
    }
    
    scheduleVirtualStateCleanup();
  }

}