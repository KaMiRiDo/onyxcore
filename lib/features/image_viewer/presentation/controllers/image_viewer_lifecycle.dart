import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:path/path.dart' as p;

class ImageViewerLifecycle {

  ImageViewerLifecycle({
    required this.windowId,
    required this.isStandalone,
    required this.focusNode,
    required this.zoomAnimationController,
    required this.onWindowFocus,
    required this.onReadyForInteraction,
    required this.onFirstFrame,
  });
  final String? windowId;
  final bool isStandalone;
  final FocusNode focusNode;
  final AnimationController zoomAnimationController;
  final void Function() onWindowFocus;
  final void Function() onReadyForInteraction;
  final void Function() onFirstFrame;

  final Completer<void> _firstFrameCompleter = Completer<void>();
  Future<void> get firstFrame => _firstFrameCompleter.future;

  Future<void> initialize({
    required BuildContext context,
    required WidgetRef ref,
    required FileItem item,
    required bool isMounted,
  }) async {
    if (isStandalone && windowId != null) {
      PersistentViewerManager.getFocusTrigger(int.parse(windowId!))
          .addListener(onWindowFocus);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted) return;

      ref.read(imageIsEmptyProvider.notifier).state = false;
      final parentPath = p.dirname(item.path);
      final currentRoot = ref.read(imageRootPathProvider);
      if (currentRoot.isEmpty || !parentPath.startsWith(currentRoot)) {
        ref.read(imageRootPathProvider.notifier).state = parentPath;
      }
      ref.read(imageCurrentPathProvider.notifier).state = parentPath;

      onFirstFrame();

      if (!_firstFrameCompleter.isCompleted) {
        _firstFrameCompleter.complete();
      }
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      if (isMounted) {
        onReadyForInteraction();
      }
    });

    if (isStandalone && windowId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          PersistentViewerManager.presentWindow(int.parse(windowId!));
          if (isMounted) {
            focusNode.requestFocus();
          }
        });
      });
    }
  }

  void dispose() {
    if (isStandalone && windowId != null) {
      PersistentViewerManager.getFocusTrigger(int.parse(windowId!))
          .removeListener(onWindowFocus);
    }
  }
}
