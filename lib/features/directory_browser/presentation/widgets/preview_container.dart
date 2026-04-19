import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:window_manager/window_manager.dart';

/// Orchestrator for the inline preview mode.
/// Switches between image and video previewers based on file type.
class PreviewContainer extends ConsumerWidget {
  const PreviewContainer({required this.item, super.key});

  final FileItem item;

  Future<void> _toggleFullscreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullScreen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isAltPressed = HardwareKeyboard.instance.isAltPressed;
            final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

            if (event.logicalKey == LogicalKeyboardKey.backspace || 
                (isAltPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft) ||
                (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyW)) {
              // Standard global navigation: Close any preview
              ref.read(previewFileProvider.notifier).state = null;
              
              // Restore standard window mode and HUD visibility
              windowManager.setFullScreen(false);
              ref.read(previewHudVisibleProvider.notifier).state = true;
              
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
              // Standard global immersion: Toggle True Full Screen (System Level)
              final isVisible = ref.read(previewHudVisibleProvider);
              final newVisible = !isVisible;
              ref.read(previewHudVisibleProvider.notifier).state = newVisible;
              
              // Toggle OS-level fullscreen to hide system bars
              _toggleFullscreen();
              
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onDoubleTap: () async {
            final windowParams = WindowParams(
              viewerType: item.type == FileItemType.video ? ViewerType.video : ViewerType.image,
              file: item,
            );
            await PersistentViewerManager.openMedia(windowParams);
            ref.read(previewFileProvider.notifier).state = null;
          },
          child: Stack(
            children: [
              // The Preview Content
              Positioned.fill(
                child: _buildPreviewer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewer() {
    if (item.type == FileItemType.image) {
      return ImagePreviewWidget(item: item);
    } else if (item.type == FileItemType.video) {
      return VideoPreviewWidget(item: item);
    }
    return const Center(
      child: Text(
        'Preview not supported for this file type',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
