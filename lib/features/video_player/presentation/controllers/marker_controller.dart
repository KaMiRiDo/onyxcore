import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';

/// Typed callback bundle for [VideoMarkerController].
class VideoMarkerCallbacks {
  const VideoMarkerCallbacks({
    required this.getPlayer,
    required this.getRef,
    required this.getMounted,
    required this.getIsMarkerEditorActive,
    required this.setIsMarkerEditorActive,
    required this.getEditingMarker,
    required this.setEditingMarker,
    required this.getIsControlsVisible,
    required this.setIsControlsVisible,
    required this.getMarkerEditorAnchor,
    required this.setMarkerEditorAnchor,
    required this.getSliderWidth,
    required this.getContextSize,
    required this.getHideTimer,
    required this.getIsPlayingNotifier,
    required this.getFocusNode,
    required this.getCurrentVideoPath,
    required this.onInteraction,
    required this.setStateCallback,
  });

  final Player Function() getPlayer;
  final WidgetRef Function() getRef;
  final bool Function() getMounted;
  final bool Function() getIsMarkerEditorActive;
  final void Function(bool) setIsMarkerEditorActive;
  final VideoMarker? Function() getEditingMarker;
  final void Function(VideoMarker?) setEditingMarker;
  final bool Function() getIsControlsVisible;
  final void Function(bool) setIsControlsVisible;
  final Offset? Function() getMarkerEditorAnchor;
  final void Function(Offset?) setMarkerEditorAnchor;
  final double Function() getSliderWidth;
  final Size? Function() getContextSize;
  final Timer? Function() getHideTimer;
  final ValueNotifier<bool> Function() getIsPlayingNotifier;
  final FocusNode Function() getFocusNode;
  final String Function() getCurrentVideoPath;
  final void Function() onInteraction;
  final void Function(void Function()) setStateCallback;
}

/// Manages the timeline marker editor lifecycle: open, save, and close.
///
/// Mirrors lines 1345–1418 of `video_preview_widget.dart`.
class VideoMarkerController {
  const VideoMarkerController(this.c);

  final VideoMarkerCallbacks c;

  void openMarkerEditor({VideoMarker? marker}) {
    c.getHideTimer()?.cancel();
    final player = c.getPlayer();
    player.pause();

    final position = marker?.timestamp ?? player.state.position;
    final duration = player.state.duration;

    c.setStateCallback(() {
      c.setIsMarkerEditorActive(true);
      c.setIsControlsVisible(true); // Lock HUD open
      c.setEditingMarker(marker);

      // Calculate anchor position on timeline
      if (duration > Duration.zero) {
        final fraction = position.inMilliseconds / duration.inMilliseconds;
        // The slider starts at 32px padding; we calculate the absolute screen X.
        final contextWidth = c.getContextSize()?.width ?? 0;
        final effectiveWidth = c.getSliderWidth() > 0
            ? c.getSliderWidth()
            : (contextWidth - 64);
        c.setMarkerEditorAnchor(Offset(fraction * effectiveWidth, 0));
      } else {
        final contextWidth = c.getContextSize()?.width ?? 0;
        c.setMarkerEditorAnchor(Offset((contextWidth - 64) / 2, 0));
      }
    });

    // ignore: inference_failure_on_function_invocation
    c.getRef().read(isMarkerEditorActiveProvider.notifier).state = true;
  }

  Future<void> saveMarker(String content, String icon) async {
    final ref = c.getRef();
    final editingMarker = c.getEditingMarker();
    final player = c.getPlayer();
    final currentPath = c.getCurrentVideoPath();

    if (editingMarker != null) {
      await ref
          .read(markerActionsProvider)
          .updateMarker(
            currentPath,
            editingMarker.copyWith(content: content, icon: icon),
          );
    } else {
      await ref
          .read(markerActionsProvider)
          .addMarker(currentPath, player.state.position, content, icon: icon);
    }

    closeMarkerEditor(resume: true);
  }

  void closeMarkerEditor({bool resume = false}) {
    final player = c.getPlayer();
    if (resume) {
      player.play();
      c.getIsPlayingNotifier().value = true;
    }

    c.setStateCallback(() {
      c.setIsMarkerEditorActive(false);
      c.setEditingMarker(null);
      c.setMarkerEditorAnchor(null);
      // Force HUD to stay visible briefly so updated state is visible
      c.onInteraction();
    });

    // ignore: inference_failure_on_function_invocation
    c.getRef().read(isMarkerEditorActiveProvider.notifier).state = false;

    // EPX-009: Restore focus to the player to ensure shortcuts work immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.getMounted()) c.getFocusNode().requestFocus();
    });
  }
}
