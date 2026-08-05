import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_header.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class DownloadsPanel extends ConsumerWidget {
  const DownloadsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(downloadsPanelViewProvider);

    var viewIndex = 0;
    switch (view) {
      case DownloadsPanelView.tasks:
        viewIndex = 0;
      case DownloadsPanelView.history:
        viewIndex = 1;
      case DownloadsPanelView.historyDetail:
        viewIndex = 2;
    }

    return IndexedStack(
      index: viewIndex,
      children: const [
        _ActiveDownloadsPanel(),
        DownloadHistoryView(),
        DownloadHistoryDetailView(),
      ],
    );
  }
}

class _ActiveDownloadsPanel extends ConsumerWidget {
  const _ActiveDownloadsPanel();

  void _openStandaloneDownloader(BuildContext context, WidgetRef ref) {
    PersistentViewerManager.openMedia(
      WindowParams(
        viewerType: ViewerType.downloader,
        file: FileItem(
          name: 'Downloader',
          path: '',
          type: FileItemType.other,
          modified: DateTime.now(),
          sizeBytes: 0,
        ),
        initParams: {
          'width': math.max(
            950,
            ref.read(settingsProvider).value?.downloaderWidth.toInt() ?? 950,
          ),
          'height': math.max(
            700,
            ref.read(settingsProvider).value?.downloaderHeight.toInt() ?? 700,
          ),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTasks = ref.watch(activeDownloadTaskProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DownloadsHeader(),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: activeTasks.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildTaskList(activeTasks),
        ),
        if (activeTasks.isNotEmpty) _buildCancelAllButton(ref),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_done_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Downloads',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Downloads started from the downloader window will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text(
                'Open Downloader',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _openStandaloneDownloader(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<DownloadTask> tasks) {
    return ListView.builder(
      itemCount: tasks.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DownloadTaskTile(
            key: ValueKey(task.id),
            task: task,
          ),
        );
      },
    );
  }

  Widget _buildCancelAllButton(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () {
            ref.read(downloadTaskProvider.notifier).cancelAll();
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.error.withValues(alpha: 0.1),
            foregroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: AppColors.error.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Text(
            'Cancel All',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
