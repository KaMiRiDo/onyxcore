import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_preview_widget.dart';

import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:window_manager/window_manager.dart';

/// Orchestrator for the inline preview mode.
/// Switches between image and video previewers based on file type.
class PreviewContainer extends ConsumerStatefulWidget {
  const PreviewContainer({required this.item, super.key});

  final FileItem item;

  @override
  ConsumerState<PreviewContainer> createState() => _PreviewContainerState();
}

class _PreviewContainerState extends ConsumerState<PreviewContainer> {
  final FocusNode _focusNode = FocusNode();
  DateTime _lastToggle = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            // Block all shortcuts if the marker editor is active
            if (ref.read(isMarkerEditorActiveProvider)) return KeyEventResult.ignored;

            final isAltPressed = HardwareKeyboard.instance.isAltPressed;
            final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

            final isVideo = widget.item.type == FileItemType.video;
            final isAudio = widget.item.type == FileItemType.audio;
            final canCloseWithKeys = !isVideo && !isAudio;
            
            if ((event.logicalKey == LogicalKeyboardKey.backspace && canCloseWithKeys) || 
                (isAltPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft && canCloseWithKeys) ||
                (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyW)) {
              
              // Close preview immediately
              ref.read(previewFileProvider.notifier).state = null;
              ref.read(previewHudVisibleProvider.notifier).state = true;
              
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
              final now = DateTime.now();
              if (now.difference(_lastToggle).inMilliseconds < 300) {
                return KeyEventResult.handled;
              }
              _lastToggle = now;

              // Ensure we have focus
              _focusNode.requestFocus();

              // Toggle HUD panel visibility
              final current = ref.read(previewHudVisibleProvider);
              ref.read(previewHudVisibleProvider.notifier).state = !current;
              
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onDoubleTap: widget.item.type == FileItemType.audio ? null : () async {
            List<String> preloadPaths = [];
            if (widget.item.type == FileItemType.image) {
              final items = ref.read(directoryItemsProvider).value ?? [];
              final mediaItems = items.where((i) => i.type == FileItemType.image).toList();
              if (mediaItems.isNotEmpty) {
                final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path);
                if (currentIndex != -1) {
                  for (int i = 1; i <= 2; i++) {
                    preloadPaths.add(mediaItems[(currentIndex + i) % mediaItems.length].path);
                    preloadPaths.add(mediaItems[(currentIndex - i + mediaItems.length) % mediaItems.length].path);
                  }
                }
              }
            }

            final windowParams = WindowParams(
              viewerType: widget.item.type == FileItemType.video 
                  ? ViewerType.video 
                  : (widget.item.type == FileItemType.audio ? ViewerType.audio : (widget.item.type == FileItemType.document ? ViewerType.markdown : ViewerType.image)),
              file: widget.item,
              initParams: {
                'preloadPaths': preloadPaths,
                if (widget.item.type == FileItemType.image) ...{
                  'currentIndex': (ref.read(directoryItemsProvider).value ?? []).where((i) => i.type == FileItemType.image).toList().indexWhere((i) => i.path == widget.item.path) + 1,
                  'totalCount': (ref.read(directoryItemsProvider).value ?? []).where((i) => i.type == FileItemType.image).length,
                }
              },
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
    if (widget.item.type == FileItemType.image) {
      return ImagePreviewWidget(item: widget.item);
    } else if (widget.item.type == FileItemType.video) {
      return VideoPreviewWidget(item: widget.item);
    } else if (widget.item.type == FileItemType.audio) {
      return AudioPlayerView(item: widget.item);
    } else if (widget.item.type == FileItemType.document) {
      if (widget.item.path.toLowerCase().endsWith('.pdf')) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'PDF Preview not yet implemented',
                style: TextStyle(color: Colors.white38),
              ),
              SizedBox(height: 8),
              Text(
                'Double-tap to open in external viewer',
                style: TextStyle(color: Colors.white10, fontSize: 12),
              ),
            ],
          ),
        );
      }
      return MarkdownPreviewWidget(key: ValueKey(widget.item.path), item: widget.item);
    }
    return const Center(
      child: Text(
        'Preview not supported for this file type',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
