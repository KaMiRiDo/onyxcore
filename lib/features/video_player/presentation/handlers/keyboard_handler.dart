import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/marker_editor_overlay.dart';

/// Callback bundle for all player actions triggered by keyboard shortcuts.
///
/// All callbacks are typed so the handler file has no direct dependency on
/// `_VideoPreviewWidgetState`.
class VideoKeyboardCallbacks {
  const VideoKeyboardCallbacks({
    required this.playOrPause,
    required this.startFastSeek,
    required this.stopFastSeek,
    required this.startVolumeAdjust,
    required this.stopVolumeAdjust,
    required this.toggleMute,
    required this.takeScreenshot,
    required this.openMarkerEditor,
    required this.closeMarkerEditor,
    required this.toggleFullscreen,
    required this.navigateMedia,
    required this.handleDelete,
    required this.closePreview,
    required this.navigatePlaylistHistoryBack,
    required this.navigatePlaylistHistoryForward,
    required this.showHud,
    required this.hideMenu,
    required this.getIsControlsVisible,
    required this.setIsControlsVisible,
    required this.requestFocus,
    required this.getActiveSeekKey,
    required this.setActiveSeekKey,
    required this.getActiveVolumeKey,
    required this.setActiveVolumeKey,
  });

  final void Function() playOrPause;
  final void Function({required bool isForward}) startFastSeek;
  final void Function() stopFastSeek;
  final void Function({required bool isIncrease}) startVolumeAdjust;
  final void Function() stopVolumeAdjust;
  final void Function() toggleMute;
  final void Function() takeScreenshot;
  final void Function() openMarkerEditor;
  final void Function({required bool resume}) closeMarkerEditor;
  final void Function() toggleFullscreen;
  final void Function(bool forward) navigateMedia;
  final void Function({required bool permanent}) handleDelete;
  final void Function() closePreview;
  final void Function(WidgetRef ref) navigatePlaylistHistoryBack;
  final void Function(WidgetRef ref) navigatePlaylistHistoryForward;
  final void Function() showHud;
  final void Function() hideMenu;
  final bool Function() getIsControlsVisible;
  final void Function(bool visible) setIsControlsVisible;
  final void Function() requestFocus;
  final LogicalKeyboardKey? Function() getActiveSeekKey;
  final void Function(LogicalKeyboardKey? key) setActiveSeekKey;
  final LogicalKeyboardKey? Function() getActiveVolumeKey;
  final void Function(LogicalKeyboardKey? key) setActiveVolumeKey;
}

/// Handles all keyboard events for the video player.
///
/// This is a plain class with no Flutter widget lifecycle. The owning
/// `_VideoPreviewWidgetState` instantiates it once and delegates its
/// `onKeyEvent` callback here.
///
/// Mirrors the `_handleKeyEvent` method originally at lines 1625–1798
/// of `video_preview_widget.dart`.
class VideoKeyboardHandler {
  const VideoKeyboardHandler({
    required this.callbacks,
    required this.isMarkerEditorActive,
    required this.markerEditorKey,
    required this.isStandalone,
    required this.windowId,
    required this.isClosing,
    required this.ref,
  });

  final VideoKeyboardCallbacks callbacks;
  final bool Function() isMarkerEditorActive;
  final GlobalKey<MarkerEditorOverlayState> markerEditorKey;
  final bool isStandalone;
  final String? windowId;
  final bool Function() isClosing;
  final WidgetRef ref;

  /// Entry point — mirrors `KeyEventResult _handleKeyEvent(KeyEvent event)`.
  KeyEventResult handle(KeyEvent event) {
    if (isClosing()) return KeyEventResult.ignored;

    // EPX-009: Handle keys during marker editor
    if (isMarkerEditorActive()) {
      // Allow standard OS shortcuts (Ctrl+C, Ctrl+V, Ctrl+A, etc.) to pass through
      final isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isControlPressed) return KeyEventResult.ignored;

      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          callbacks.closeMarkerEditor(resume: true);
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          final editor = markerEditorKey.currentState;
          if (editor != null && editor.isTagFieldFocused) {
            editor.save();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        // Block Space and Backspace from triggering player actions, but pass
        // them through to the TextField via `ignored`.
        if (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }

        return KeyEventResult.ignored;
      }
      return KeyEventResult.ignored;
    }

    // BUG-FIX: Block Backspace and Alt+Arrows navigation in preview mode
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          (isAltPressed &&
              (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.arrowRight))) {
        if (windowId == null && !isStandalone) {
          final isSidebarOpen = ref.read(videoPlaylistSidebarVisibleProvider);
          if (isSidebarOpen && isAltPressed) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              callbacks.navigatePlaylistHistoryBack(ref);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              callbacks.navigatePlaylistHistoryForward(ref);
            }
          }
          return KeyEventResult.handled;
        }
      }
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (event is KeyDownEvent) callbacks.playOrPause();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (callbacks.getActiveSeekKey() == null && event is KeyDownEvent) {
          callbacks.setActiveSeekKey(event.logicalKey);
          callbacks.startFastSeek(isForward: false);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (callbacks.getActiveSeekKey() == null && event is KeyDownEvent) {
          callbacks.setActiveSeekKey(event.logicalKey);
          callbacks.startFastSeek(isForward: true);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (callbacks.getActiveVolumeKey() == null && event is KeyDownEvent) {
          callbacks.setActiveVolumeKey(event.logicalKey);
          callbacks.startVolumeAdjust(isIncrease: true);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (callbacks.getActiveVolumeKey() == null && event is KeyDownEvent) {
          callbacks.setActiveVolumeKey(event.logicalKey);
          callbacks.startVolumeAdjust(isIncrease: false);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        if (event is KeyDownEvent) callbacks.toggleMute();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        if (event is KeyDownEvent) callbacks.takeScreenshot();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        if (event is KeyDownEvent) {
          // In all modes, 'F' should at least hide/show the HUD controls
          if (callbacks.getIsControlsVisible()) {
            callbacks.setIsControlsVisible(false);
            callbacks.hideMenu();
          } else {
            callbacks.setIsControlsVisible(true);
          }

          if (isStandalone) {
            callbacks.toggleFullscreen();
          } else {
            // In preview mode, ensure we keep focus after the HUD state change
            callbacks.requestFocus();
          }
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyP &&
          HardwareKeyboard.instance.isControlPressed &&
          HardwareKeyboard.instance.isShiftPressed) {
        if (event is KeyDownEvent) {
          final isOpen = ref.read(videoPlaylistSidebarVisibleProvider);
          ref.read(videoPlaylistSidebarVisibleProvider.notifier).state =
              !isOpen;
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
        if (event is KeyDownEvent) callbacks.openMarkerEditor();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (event is KeyDownEvent) {
          final shift = HardwareKeyboard.instance.isShiftPressed;
          callbacks.handleDelete(permanent: shift);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyW &&
          HardwareKeyboard.instance.isControlPressed) {
        if (event is KeyDownEvent && !isStandalone) {
          callbacks.closePreview();
        }
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (callbacks.getActiveSeekKey() == event.logicalKey) {
          callbacks.stopFastSeek();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (callbacks.getActiveVolumeKey() == event.logicalKey) {
          callbacks.stopVolumeAdjust();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
