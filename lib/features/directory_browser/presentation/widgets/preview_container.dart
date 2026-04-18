import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

/// Orchestrator for the inline preview mode.
/// Switches between image and video previewers based on file type.
class PreviewContainer extends ConsumerWidget {
  const PreviewContainer({required this.item, super.key});

  final FileItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // The Preview Content
          Positioned.fill(
            child: _buildPreviewer(),
          ),
        ],
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
