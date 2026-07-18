import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

import 'package:path/path.dart' as p;

class TaskTile extends ConsumerStatefulWidget {
  const TaskTile({required this.task, super.key});
  final FileTask task;

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  bool _logsExpanded = false;
  bool _showCancelConfirm = false;
  final ScrollController _logScrollController = ScrollController();
  Timer? _etaTimer;
  String _etaText = '';

  @override
  void initState() {
    super.initState();
    _updateEta();
    if (widget.task.status == FileTaskStatus.running) {
      _etaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateEta();
      });
    }
  }

  @override
  void didUpdateWidget(TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.status != FileTaskStatus.running) {
      _etaTimer?.cancel();
    } else if (_etaTimer == null || !_etaTimer!.isActive) {
      _etaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateEta();
      });
    }
    _updateEta();

    // Auto-scroll logs when new entries arrive
    if (_logsExpanded &&
        widget.task.logs.length != oldWidget.task.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _updateEta() {
    if (widget.task.isSyncing) {
      if (mounted) setState(() => _etaText = 'Finishing...');
      return;
    }

    final eta = widget.task.estimatedRemaining;
    if (eta == null || widget.task.status != FileTaskStatus.running) {
      if (mounted) setState(() => _etaText = '');
      return;
    }
    final minutes = eta.inMinutes;
    final seconds = eta.inSeconds % 60;
    if (mounted) {
      setState(() {
        final m = minutes.toString().padLeft(2, '0');
        final s = seconds.toString().padLeft(2, '0');
        _etaText = '$m:$s';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                          // Paths details
                          if (task.sourcePaths != null &&
                              task.sourcePaths!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                task.sourcePaths!.length == 1
                                    ? 'From: ${p.dirname(task.sourcePaths![0])}'
                                    : 'From: ${task.sourcePaths!.length} items from ${p.dirname(task.sourcePaths![0])}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (task.targetPath != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'To: ${StringUtils.truncateMiddle(task.targetPath!, maxLength: 40)}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),

                          // Current item + ETA
                          if (task.currentItem != null &&
                              task.status == FileTaskStatus.running)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Processing: ${StringUtils.truncateMiddle(task.currentItem!, maxLength: 35)}',
                                    style: GoogleFonts.manrope(
                                      color: AppColors.violet.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_etaText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      _etaText,
                                      style: GoogleFonts.manrope(
                                        color: task.isSyncing
                                            ? AppColors.violet
                                            : AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: task.isSyncing
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          // Subtitle for non-running tasks
                          if (task.currentItem == null ||
                              task.status != FileTaskStatus.running)
                            Text(
                              task.subtitle,
                              style: GoogleFonts.manrope(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Cancel button (only for running/pending)
                    if (task.status == FileTaskStatus.running ||
                        task.status == FileTaskStatus.pending)
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
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Progress + ETA row
              if (task.status == FileTaskStatus.running ||
                  task.status == FileTaskStatus.pending) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              end: task.status == FileTaskStatus.pending
                                  ? 0.0
                                  : task.progress,
                            ),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, animatedProgress, _) {
                              return LinearProgressIndicator(
                                value: animatedProgress,
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  task.status == FileTaskStatus.pending
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : (task.isSyncing
                                            ? AppColors.violet
                                            : AppColors.violet.withValues(
                                                alpha: 0.8,
                                              )),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Items count and Byte transfer row
                if (task.totalCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${task.processedCount} of ${task.totalCount} items',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        if (task.progress > 0 ||
                            task.totalSizeBytes > 0 ||
                            task.processedSizeBytes > 0)
                          Row(
                            children: [
                              Text(
                                '${StringUtils.formatBytes(task.processedSizeBytes)} / ${task.totalSizeBytes > 0 ? StringUtils.formatBytes(task.totalSizeBytes) : '?'}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              if (task.speed != null && task.speed! > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${StringUtils.formatBytes(task.speed!.toInt())}/s',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.violet.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (task.totalSizeBytes > 0 && task.progress > 0)
                                const SizedBox(width: 8),
                              if (task.progress > 0)
                                Text(
                                  '${(task.progress * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textMuted.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
              // Error message
              if (task.status == FileTaskStatus.error &&
                  task.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    task.errorMessage!,
                    style: GoogleFonts.manrope(
                      color: AppColors.error.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Logs toggle
              if (task.logs.isNotEmpty) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => setState(() => _logsExpanded = !_logsExpanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _logsExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Logs',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Logs container
                if (_logsExpanded)
                  Container(
                    height: 120,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: task.logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            task.logs[index],
                            style: GoogleFonts.firaCode(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              if (!_logsExpanded) const SizedBox(height: 12),
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
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cancel this task?',
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
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white,
                  () => setState(() => _showCancelConfirm = false),
                ),
                const SizedBox(width: 12),
                _confirmButton(
                  'Yes, Cancel',
                  AppColors.error.withValues(alpha: 0.2),
                  AppColors.error,
                  () {
                    ref.read(taskProvider.notifier).cancelTask(widget.task.id);
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
          border: Border.all(color: textColor.withValues(alpha: 0.2)),
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

  Widget _buildStatusBadge(FileTaskStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case FileTaskStatus.running:
        bgColor = AppColors.violet.withValues(alpha: 0.15);
        textColor = AppColors.violet;
        label = 'Running';
      case FileTaskStatus.pending:
        bgColor = Colors.amber.withValues(alpha: 0.1);
        textColor = Colors.amber;
        label = 'Pending';
      case FileTaskStatus.completed:
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        label = 'Completed';
      case FileTaskStatus.error:
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        label = 'Error';
      case FileTaskStatus.cancelled:
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        label = 'Cancelled';
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
