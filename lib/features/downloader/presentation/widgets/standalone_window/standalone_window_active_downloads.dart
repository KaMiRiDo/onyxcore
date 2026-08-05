import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';

class StandaloneWindowActiveDownloads extends StatelessWidget {
  const StandaloneWindowActiveDownloads({
    required this.tasks, required this.onCancelAll, super.key,
  });

  final List<DownloadTask> tasks;
  final VoidCallback onCancelAll;

  @override
  Widget build(BuildContext context) {
    final isSmallWindow = MediaQuery.of(context).size.width < 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Active Downloads',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: isSmallWindow ? 13 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No active downloads',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: DownloadTaskTile(
                        key: ValueKey(task.id),
                        task: task,
                      ),
                    );
                  },
                ),
        ),
        if (tasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: isSmallWindow ? 24 : null,
              child: TextButton(
                onPressed: onCancelAll,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel All',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallWindow ? 11 : 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
