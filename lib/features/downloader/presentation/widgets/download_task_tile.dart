import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/core/utils/string_utils.dart';

class DownloadTaskTile extends ConsumerStatefulWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  @override
  ConsumerState<DownloadTaskTile> createState() => _DownloadTaskTileState();
}

class _DownloadTaskTileState extends ConsumerState<DownloadTaskTile> {
  bool _showCancelConfirm = false;

  List<TextSpan> _buildStatsSpans(DownloadTask task) {
    final spans = <TextSpan>[];
    final separator = TextSpan(
      text: '  •  ',
      style: GoogleFonts.manrope(
        color: AppColors.textMuted.withOpacity(0.4),
        fontSize: 11,
      ),
    );

    if (task.totalItems > 1) {
      spans.add(TextSpan(text: '${task.completedItems}/${task.totalItems}'));
    }

    // For multi-item downloads (playlists/profiles), show folder downloaded size
    if (task.totalItems > 1 && task.downloadedBytes > 0) {
      if (spans.isNotEmpty) spans.add(separator);
      final expectedStr = task.expectedBytes > 0
          ? StringUtils.formatBytes(task.expectedBytes)
          : '?';
      spans.add(TextSpan(
        text: '${StringUtils.formatBytes(task.downloadedBytes)} / $expectedStr',
      ));
    } else if (task.totalSize.isNotEmpty) {
      // For single downloads, show the per-item size from yt-dlp/aria2c
      if (spans.isNotEmpty) spans.add(separator);
      spans.add(TextSpan(text: task.totalSize));
    }

    if (task.speed.isNotEmpty) {
      if (spans.isNotEmpty) spans.add(separator);
      spans.add(TextSpan(
        text: task.speed,
        style: GoogleFonts.manrope(
          color: AppColors.violet,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ));
    }

    // Always show ETA — compute total remaining for playlists, use per-item for singles
    final etaText = _computeEta(task);
    if (spans.isNotEmpty) spans.add(separator);
    if (etaText.isNotEmpty) {
      spans.add(TextSpan(text: 'ETA $etaText'));
    } else {
      spans.add(TextSpan(text: 'ETA Calculating...'));
    }
    return spans;
  }

  /// Computes the best ETA string to display.
  /// For multi-item downloads: estimates total remaining based on elapsed time and progress.
  /// For single downloads: uses the per-item ETA from yt-dlp/aria2c.
  String _computeEta(DownloadTask task) {
    if (task.totalItems > 1 && task.completedItems > 0) {
      // Estimate total ETA from elapsed time and items completed
      final elapsed = DateTime.now().difference(task.createdAt);
      final elapsedSecs = elapsed.inSeconds;
      if (elapsedSecs > 0) {
        // Use progress-based estimate: remaining = elapsed * (1 - progress) / progress
        if (task.progress > 0.0 && task.progress < 1.0) {
          final remainingSecs = (elapsedSecs * (1.0 - task.progress) / task.progress).round();
          return _formatDuration(remainingSecs);
        }
      }
    }
    // Fall back to per-item ETA from the engine
    return task.eta;
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main tile content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + Status badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(task.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'To: ${task.destination}',
                              style: GoogleFonts.manrope(
                                color: AppColors.textMuted.withOpacity(0.7),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Subtitle for non-running tasks
                          if (task.status != DownloadStatus.running &&
                              task.status != DownloadStatus.cancelling)
                            Text(
                              task.status == DownloadStatus.completed
                                  ? 'Download finished successfully'
                                  : task.status == DownloadStatus.pending
                                  ? 'Waiting to start...'
                                  : task.status == DownloadStatus.error
                                  ? 'Failed to download'
                                  : 'Cancelled by user',
                              style: GoogleFonts.manrope(
                                color: task.status == DownloadStatus.error
                                    ? AppColors.error
                                    : AppColors.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Cancel button
                    if (task.status == DownloadStatus.running ||
                        task.status == DownloadStatus.pending)
                      InkWell(
                        onTap: () {
                          setState(() => _showCancelConfirm = true);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      )
                    else if (task.status == DownloadStatus.cancelling)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange.withOpacity(0.6),
                            ),
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          ref
                              .read(downloadTaskProvider.notifier)
                              .removeTask(task.id);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Progress + ETA row
              if (task.status == DownloadStatus.running ||
                  task.status == DownloadStatus.pending ||
                  task.status == DownloadStatus.cancelling) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          child: task.status == DownloadStatus.cancelling
                              ? LinearProgressIndicator(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.06,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange.withOpacity(0.6),
                                  ),
                                )
                              : TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    end: task.status == DownloadStatus.pending
                                        ? 0.0
                                        : task.progress,
                                  ),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.linear,
                                  builder: (context, animatedProgress, _) {
                                    return LinearProgressIndicator(
                                      value:
                                          task.progress == 0.0 &&
                                              task.totalSize.isEmpty &&
                                              task.status ==
                                                  DownloadStatus.running
                                          ? null
                                          : animatedProgress,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.06,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        task.status == DownloadStatus.pending
                                            ? Colors.white.withOpacity(0.1)
                                            : AppColors.violet.withOpacity(0.8),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.status == DownloadStatus.cancelling
                                  ? 'Cancelling...'
                                  : task.progress == 0.0 &&
                                        task.status == DownloadStatus.running
                                  ? 'Processing...'
                                  : '${(task.progress * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.manrope(
                                color: task.status == DownloadStatus.cancelling
                                    ? Colors.orange.withOpacity(0.7)
                                    : AppColors.textMuted.withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Left side stats removed to prefer the right side consolidated string
                          ],
                        ),
                      ),
                      if (task.status == DownloadStatus.running &&
                          (task.speed.isNotEmpty ||
                              task.totalSize.isNotEmpty ||
                              task.eta.isNotEmpty ||
                              task.totalItems > 1 ||
                              task.downloadedBytes > 0))
                        Flexible(
                          flex: 2,
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            text: TextSpan(
                              style: GoogleFonts.manrope(
                                color: AppColors.textMuted.withOpacity(0.8),
                                fontSize: 11,
                              ),
                              children: _buildStatsSpans(task),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Error message
              if (task.status == DownloadStatus.error && task.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    task.error!,
                    style: GoogleFonts.manrope(
                      color: AppColors.error.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
          if (_showCancelConfirm)
            Positioned.fill(
              child: _buildCancelConfirmation(),
            ),
        ],
      ),
    );
  }

  Widget _buildCancelConfirmation() {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cancel this download?',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _confirmButton(
                  'No',
                  Colors.white.withOpacity(0.1),
                  Colors.white,
                  () => setState(() => _showCancelConfirm = false),
                ),
                const SizedBox(width: 12),
                _confirmButton(
                  'Yes, Cancel',
                  AppColors.error.withOpacity(0.2),
                  AppColors.error,
                  () {
                    ref
                        .read(downloadTaskProvider.notifier)
                        .cancelDownload(widget.task.id);
                    setState(() => _showCancelConfirm = false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmButton(
    String label,
    Color bgColor,
    Color textColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: textColor.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DownloadStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case DownloadStatus.running:
        bgColor = AppColors.violet.withOpacity(0.15);
        textColor = AppColors.violet;
        label = 'Running';
        break;
      case DownloadStatus.pending:
        bgColor = Colors.amber.withOpacity(0.1);
        textColor = Colors.amber;
        label = 'Pending';
        break;
      case DownloadStatus.completed:
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        label = 'Completed';
        break;
      case DownloadStatus.error:
        bgColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        label = 'Error';
        break;
      case DownloadStatus.cancelled:
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        label = 'Cancelled';
        break;
      case DownloadStatus.cancelling:
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
        label = 'Cancelling';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
