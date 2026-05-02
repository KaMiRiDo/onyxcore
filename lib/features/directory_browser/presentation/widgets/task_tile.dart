import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

class TaskTile extends ConsumerStatefulWidget {
  final FileTask task;
  const TaskTile({required this.task, super.key});

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  bool _logsExpanded = false;
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
    if (_logsExpanded && widget.task.logs.length != oldWidget.task.logs.length) {
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
    final eta = widget.task.estimatedRemaining;
    if (eta == null || widget.task.status != FileTaskStatus.running) {
      if (mounted) setState(() => _etaText = '');
      return;
    }
    final minutes = eta.inMinutes;
    final seconds = eta.inSeconds % 60;
    if (mounted) {
      setState(() {
        if (minutes > 0) {
          _etaText = '~${minutes}m ${seconds}s remaining';
        } else {
          _etaText = '~${seconds}s remaining';
        }
      });
    }
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
      child: Column(
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
                      // Current item
                      if (task.currentItem != null && task.status == FileTaskStatus.running)
                        Text(
                          StringUtils.truncateMiddle(task.currentItem!, maxLength: 30),
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      // Subtitle for non-running tasks
                      if (task.currentItem == null || task.status != FileTaskStatus.running)
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
                      ref.read(taskProvider.notifier).cancelTask(task.id);
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
                  ),
              ],
            ),
          ),
          // Progress + ETA row
          if (task.status == FileTaskStatus.running) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: task.progress > 0 ? task.progress : null,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.violet.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_etaText.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      _etaText,
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Items count
            if (task.totalCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(
                  '${task.processedCount} of ${task.totalCount} items',
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
          // Error message
          if (task.status == FileTaskStatus.error && task.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                task.errorMessage!,
                style: GoogleFonts.manrope(
                  color: AppColors.error.withOpacity(0.8),
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
                      color: AppColors.textMuted.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Logs',
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted.withOpacity(0.6),
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
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                          color: Colors.white.withOpacity(0.5),
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
    );
  }

  Widget _buildStatusBadge(FileTaskStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case FileTaskStatus.running:
        bgColor = AppColors.violet.withOpacity(0.15);
        textColor = AppColors.violet;
        label = 'Running';
      case FileTaskStatus.pending:
        bgColor = Colors.amber.withOpacity(0.1);
        textColor = Colors.amber;
        label = 'Pending';
      case FileTaskStatus.completed:
        bgColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.success;
        label = 'Completed';
      case FileTaskStatus.error:
        bgColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        label = 'Error';
      case FileTaskStatus.cancelled:
        bgColor = Colors.orange.withOpacity(0.1);
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
