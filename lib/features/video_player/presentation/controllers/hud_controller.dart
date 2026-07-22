import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';

/// Typed callback bundle for [VideoHudController].
class VideoHudCallbacks {
  const VideoHudCallbacks({
    required this.getMounted,
    required this.getIsClosing,
    required this.getIsControlsVisible,
    required this.setIsControlsVisible,
    required this.getIsScrubbing,
    required this.getIsMarkerEditorActive,
    required this.getIsHoveringMarker,
    required this.getIsAnyMenuVisible,
    required this.getIsAudioMenuVisible,
    required this.setIsAudioMenuVisible,
    required this.getIsSubtitleMenuVisible,
    required this.setIsSubtitleMenuVisible,
    required this.getIsSpeedMenuVisible,
    required this.setIsSpeedMenuVisible,
    required this.getIsVolumeOverlayVisible,
    required this.setIsVolumeOverlayVisible,
    required this.getIsSeekIndicatorVisible,
    required this.setIsSeekIndicatorVisible,
    required this.getShowSpeedOverlayVisible,
    required this.setShowSpeedOverlayVisible,
    required this.getHideTimer,
    required this.setHideTimer,
    required this.getVolumeOverlayTimer,
    required this.setVolumeOverlayTimer,
    required this.getSpeedOverlayTimer,
    required this.setSpeedOverlayTimer,
    required this.getSeekIndicatorTimer,
    required this.setSeekIndicatorTimer,
    required this.getActiveMenuEntry,
    required this.setActiveMenuEntry,
    required this.getWindowId,
    required this.getRef,
    required this.setStateCallback,
    required this.getOverlayContext,
  });

  final bool Function() getMounted;
  final bool Function() getIsClosing;
  final bool Function() getIsControlsVisible;
  final void Function(bool) setIsControlsVisible;
  final bool Function() getIsScrubbing;
  final bool Function() getIsMarkerEditorActive;
  final bool Function() getIsHoveringMarker;
  final bool Function() getIsAnyMenuVisible;
  final bool Function() getIsAudioMenuVisible;
  final void Function(bool) setIsAudioMenuVisible;
  final bool Function() getIsSubtitleMenuVisible;
  final void Function(bool) setIsSubtitleMenuVisible;
  final bool Function() getIsSpeedMenuVisible;
  final void Function(bool) setIsSpeedMenuVisible;
  final bool Function() getIsVolumeOverlayVisible;
  final void Function(bool) setIsVolumeOverlayVisible;
  final bool Function() getIsSeekIndicatorVisible;
  final void Function(bool) setIsSeekIndicatorVisible;
  final bool Function() getShowSpeedOverlayVisible;
  final void Function(bool) setShowSpeedOverlayVisible;
  final Timer? Function() getHideTimer;
  final void Function(Timer?) setHideTimer;
  final Timer? Function() getVolumeOverlayTimer;
  final void Function(Timer?) setVolumeOverlayTimer;
  final Timer? Function() getSpeedOverlayTimer;
  final void Function(Timer?) setSpeedOverlayTimer;
  final Timer? Function() getSeekIndicatorTimer;
  final void Function(Timer?) setSeekIndicatorTimer;
  final OverlayEntry? Function() getActiveMenuEntry;
  final void Function(OverlayEntry?) setActiveMenuEntry;
  final String? Function() getWindowId;
  final WidgetRef Function() getRef;
  final void Function(void Function()) setStateCallback;
  final BuildContext Function() getOverlayContext;
}

/// Handles all HUD visibility timers, the overlay menu lifecycle, and the
/// interaction-triggered hide-timer.
///
/// Mirrors lines 1206–1344 of `video_preview_widget.dart`.
class VideoHudController {
  const VideoHudController(this.c);

  final VideoHudCallbacks c;

  void startHideTimer() {
    c.getHideTimer()?.cancel();
    if (c.getIsAnyMenuVisible() ||
        c.getIsMarkerEditorActive() ||
        c.getIsHoveringMarker()) {
      return;
    }
    c.setHideTimer(
      Timer(const Duration(seconds: 2), () {
        if (c.getMounted() &&
            c.getIsControlsVisible() &&
            !c.getIsScrubbing() &&
            !c.getIsMarkerEditorActive() &&
            !c.getIsHoveringMarker() &&
            !c.getIsAnyMenuVisible()) {
          c.setStateCallback(() => c.setIsControlsVisible(false));
        }
      }),
    );
  }

  void showVolumeOverlay() {
    c.getVolumeOverlayTimer()?.cancel();
    if (c.getMounted() && !c.getIsVolumeOverlayVisible()) {
      c.setStateCallback(() => c.setIsVolumeOverlayVisible(true));
    }
    c.setVolumeOverlayTimer(
      Timer(const Duration(seconds: 3), () {
        if (c.getMounted()) {
          c.setStateCallback(() => c.setIsVolumeOverlayVisible(false));
        }
      }),
    );
  }

  void showSpeedOverlay() {
    c.getSpeedOverlayTimer()?.cancel();
    if (c.getMounted() && !c.getShowSpeedOverlayVisible()) {
      c.setStateCallback(() => c.setShowSpeedOverlayVisible(true));
    }
    c.setSpeedOverlayTimer(
      Timer(const Duration(seconds: 3), () {
        if (c.getMounted()) {
          c.setStateCallback(() => c.setShowSpeedOverlayVisible(false));
        }
      }),
    );
  }

  void showSeekIndicator() {
    c.getSeekIndicatorTimer()?.cancel();
    if (c.getMounted() && !c.getIsSeekIndicatorVisible()) {
      c.setStateCallback(() => c.setIsSeekIndicatorVisible(true));
    }
    c.setSeekIndicatorTimer(
      Timer(const Duration(milliseconds: 1200), () {
        if (c.getMounted()) {
          c.setStateCallback(() => c.setIsSeekIndicatorVisible(false));
        }
      }),
    );
  }

  void onInteraction() {
    if (c.getIsClosing() || !c.getMounted()) return;

    // Wake up global HUD if it was manually hidden
    final ref = c.getRef();
    if (c.getWindowId() == null && !ref.read(previewHudVisibleProvider)) {
      // Immediate update is safe here because listeners handle 'mounted' check
      // ignore: inference_failure_on_function_invocation
      ref.read(previewHudVisibleProvider.notifier).state = true;
    }

    if (c.getMounted() && !c.getIsControlsVisible()) {
      c.setStateCallback(() => c.setIsControlsVisible(true));
    }

    // If marker editor or any menu is active, we don't start the hide timer
    if (c.getIsMarkerEditorActive() ||
        c.getIsAnyMenuVisible() ||
        c.getIsHoveringMarker()) {
      return;
    }

    startHideTimer();
  }

  void hideMenu() {
    c.getActiveMenuEntry()?.remove();
    c.setActiveMenuEntry(null);
    if (c.getMounted()) {
      c.setStateCallback(() {
        c.setIsAudioMenuVisible(false);
        c.setIsSubtitleMenuVisible(false);
        c.setIsSpeedMenuVisible(false);
      });
    }
    startHideTimer();
  }

  void showMenu({
    required GlobalKey key,
    required Widget child,
    required String type,
  }) {
    // Close existing menu first but don't trigger a hide timer yet
    c.getActiveMenuEntry()?.remove();
    c.setActiveMenuEntry(null);
    c.getHideTimer()?.cancel();

    if (!c.getMounted()) return;
    c.setStateCallback(() {
      c.setIsAudioMenuVisible(type == 'audio');
      c.setIsSubtitleMenuVisible(type == 'subtitle');
      c.setIsSpeedMenuVisible(type == 'speed');
    });

    final ctx = c.getOverlayContext();
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final isSpeed = type == 'speed';

    final entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Block interaction with other layers while menu is open
          Positioned.fill(
            child: GestureDetector(
              onTap: hideMenu,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: isSpeed ? null : position.dx,
            right: isSpeed
                ? (MediaQuery.of(context).size.width -
                      position.dx -
                      renderBox.size.width)
                : null,
            top: position.dy - 12, // Gap above button
            child: FractionalTranslation(
              translation: const Offset(0, -1), // Move menu above the button
              child: Material(color: Colors.transparent, child: child),
            ),
          ),
        ],
      ),
    );

    c.setActiveMenuEntry(entry);
    Overlay.of(ctx).insert(entry);
  }
}
