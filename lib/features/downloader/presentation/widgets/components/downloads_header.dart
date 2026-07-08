import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';

class DownloadsHeader extends ConsumerWidget {
  const DownloadsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                'Download Manager',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          Tooltip(
            message: 'Open in Window',
            waitDuration: const Duration(milliseconds: 500),
            child: IconButton(
              icon: Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white70),
              onPressed: () {
                final currentPath = ref.read(currentPathProvider);
                PersistentViewerManager.openMedia(
                  WindowParams(
                    viewerType: ViewerType.downloader,
                    file: FileItem(
                      name: 'Downloader',
                      path: currentPath,
                      type: FileItemType.other,
                      modified: DateTime.now(),
                      sizeBytes: 0,
                    ),
                    initParams: {'currentPath': currentPath},
                  ),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadsPanelViewProvider.notifier).state =
                  DownloadsPanelView.history;
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'History',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Close button
          Tooltip(
            message: 'Close Panel',
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
              onTap: () {
                ref.read(downloadsPanelOpenProvider.notifier).state = false;
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
