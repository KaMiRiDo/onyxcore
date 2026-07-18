import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:path/path.dart' as p;

/// Detail view for a single task history entry.
class TaskHistoryDetailView extends ConsumerStatefulWidget {
  const TaskHistoryDetailView({super.key});

  @override
  ConsumerState<TaskHistoryDetailView> createState() =>
      _TaskHistoryDetailViewState();
}

class _TaskHistoryDetailViewState extends ConsumerState<TaskHistoryDetailView> {
  bool _logsExpanded = false;
  bool _showDeleteConfirm = false;
  final ScrollController _logScrollController = ScrollController();
  final ScrollController _processedScrollController = ScrollController();
  final ScrollController _affectedScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    _processedScrollController.dispose();
    _affectedScrollController.dispose();
    super.dispose();
  }

  void _navigateTo(
    String path, {
    String? highlightFile,
    bool forceParent = false,
  }) {
    if (!Directory(path).existsSync() && !File(path).existsSync()) return;

    final targetDir = (Directory(path).existsSync() && !forceParent)
        ? path
        : p.dirname(path);
    final itemToHighlight = highlightFile ?? (forceParent ? path : null);

    // Navigate
    ref.read(currentPathProvider.notifier).state = targetDir;

    // Highlight if requested
    if (itemToHighlight != null) {
      // Small delay to ensure the directory provider has started loading the new path
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        ref.read(selectionProvider.notifier).deselectAll();
        ref.read(selectionProvider.notifier).select(itemToHighlight);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryId = ref.watch(selectedHistoryIdProvider);
    if (entryId == null) return const SizedBox.shrink();

    final entry = ref.read(taskHistoryProvider.notifier).getEntry(entryId);
    if (entry == null) return const SizedBox.shrink();

    final duration = entry.duration;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      ref.read(selectedHistoryIdProvider.notifier).state = null;
                      ref.read(backgroundPanelViewProvider.notifier).state =
                          BackgroundPanelView.history;
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Task Details',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showDeleteConfirm = true),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.error.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Delete History Entry',
                  ),
                  // Close button
                  Tooltip(
                    message: 'Close Panel',
                    waitDuration: const Duration(milliseconds: 500),
                    child: InkWell(
                      onTap: () {
                        ref.read(backgroundPanelOpenProvider.notifier).state =
                            false;
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
            ),
            const Divider(color: Colors.white10, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getOperationColor(
                                    entry.title,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getOperationIcon(entry.title),
                                  size: 20,
                                  color: _getOperationColor(entry.title),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _toPastTense(entry.title),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(entry.statusName),
                            ],
                          ),
                          if (entry.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.errorMessage!,
                                      style: GoogleFonts.manrope(
                                        color: AppColors.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Path Visualization
                    if (entry.sourcePaths != null ||
                        entry.targetPath != null) ...[
                      Text(
                        'FLOW',
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPathFlow(entry),
                      const SizedBox(height: 24),
                    ],

                    // Processed Files (Copy/Move)
                    if (entry.sourcePaths != null &&
                        entry.sourcePaths!.isNotEmpty &&
                        entry.targetPath != null) ...[
                      Text(
                        'PROCESSED ITEMS',
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Scrollbar(
                          controller: _processedScrollController,
                          thumbVisibility: true,
                          trackVisibility: false,
                          thickness: 4,
                          radius: const Radius.circular(10),
                          child: ListView.builder(
                            controller: _processedScrollController,
                            padding: EdgeInsets.zero,
                            itemCount: entry.sourcePaths!.length,
                            itemBuilder: (context, index) {
                              final src = entry.sourcePaths![index];
                              final destPath = p.join(
                                entry.targetPath!,
                                p.basename(src),
                              );
                              final exists =
                                  File(destPath).existsSync() ||
                                  Directory(destPath).existsSync();
                              return _buildProcessedFileItem(
                                src,
                                destPath,
                                exists,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Affected Items (Rename/Delete/Create from Logs)
                    ...(() {
                      final processedLogs = entry.logs
                          .where(
                            (log) =>
                                log.startsWith('Renamed: ') ||
                                log.startsWith('Moved to Trash: ') ||
                                log.startsWith('Deleted: ') ||
                                log.startsWith('Created Folder: ') ||
                                log.startsWith('Created File: '),
                          )
                          .toList();

                      if (processedLogs.isEmpty) return <Widget>[];

                      return [
                        Text(
                          'PROCESSED ITEMS',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Scrollbar(
                            controller: _affectedScrollController,
                            thumbVisibility: true,
                            trackVisibility: false,
                            thickness: 4,
                            radius: const Radius.circular(10),
                            child: ListView.builder(
                              controller: _affectedScrollController,
                              padding: EdgeInsets.zero,
                              itemCount: processedLogs.length,
                              itemBuilder: (context, index) {
                                final log = processedLogs[index];
                                if (log.startsWith('Renamed: ')) {
                                  final parts = log.substring(9).split(' -> ');
                                  if (parts.length == 2) {
                                    return _buildRenamedFileItem(
                                      parts[0].trim(),
                                      parts[1].trim(),
                                    );
                                  }
                                } else if (log.startsWith('Deleted: ') ||
                                    log.startsWith('Moved to Trash: ')) {
                                  final isTrash = log.startsWith(
                                    'Moved to Trash: ',
                                  );
                                  final path = log
                                      .substring(isTrash ? 16 : 9)
                                      .trim();
                                  return _buildDeletedFileItem(path, isTrash);
                                } else if (log.startsWith('Created Folder: ') ||
                                    log.startsWith('Created File: ')) {
                                  final isFolder = log.startsWith(
                                    'Created Folder: ',
                                  );
                                  final path = log
                                      .substring(isFolder ? 16 : 14)
                                      .trim();
                                  return _buildCreatedFileItem(path, isFolder);
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ];
                    }()),

                    // Stats Grid (Single Row)
                    Text(
                      'STATISTICS',
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              Icons.timer_outlined,
                              'Duration',
                              duration != null
                                  ? _formatDuration(duration)
                                  : 'N/A',
                            ),
                          ),
                          _buildStatDivider(),
                          Expanded(
                            child: _buildStatItem(
                              Icons.inventory_2_outlined,
                              'Items',
                              '${entry.processedCount}/${entry.totalCount}',
                            ),
                          ),
                          if (!entry.title.toLowerCase().contains('rename') &&
                              !entry.title.toLowerCase().contains('renam')) ...[
                            _buildStatDivider(),
                            Expanded(
                              child: _buildStatItem(
                                Icons.sd_storage_outlined,
                                'Size',
                                StringUtils.formatBytes(
                                  (entry.statusName == 'cancelled')
                                      ? (entry.processedSizeBytes ?? 0)
                                      : (entry.totalSizeBytes ?? 0),
                                ),
                              ),
                            ),
                          ],
                          if (duration != null &&
                              duration.inSeconds > 0 &&
                              (entry.totalSizeBytes ?? 0) > 0) ...[
                            _buildStatDivider(),
                            Expanded(
                              child: _buildStatItem(
                                Icons.speed_outlined,
                                'Speed',
                                '${StringUtils.formatBytes(((entry.totalSizeBytes ?? 0) / duration.inSeconds).round())}/s',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Timeline
                    Text(
                      'TIMELINE',
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTimelineItem('Created', entry.createdAt),
                    if (entry.startedAt != null)
                      _buildTimelineItem('Started', entry.startedAt!),
                    if (entry.completedAt != null)
                      _buildTimelineItem('Finished', entry.completedAt!),

                    const SizedBox(height: 24),

                    // Logs (Dropdown Style)
                    if (entry.logs.isNotEmpty) ...[
                      InkWell(
                        onTap: () =>
                            setState(() => _logsExpanded = !_logsExpanded),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _logsExpanded
                                  ? AppColors.violet.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.terminal_rounded,
                                size: 18,
                                color: _logsExpanded
                                    ? AppColors.violet
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Execution Logs',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${entry.logs.length} entries recorded',
                                      style: GoogleFonts.manrope(
                                        color: AppColors.textMuted.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _logsExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_logsExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 250,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: ListView.builder(
                            controller: _logScrollController,
                            itemCount: entry.logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  entry.logs[index],
                                  style: GoogleFonts.firaCode(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        // Local Confirmation Overlay
        if (_showDeleteConfirm)
          _buildLocalConfirmOverlay(
            title: 'Delete History?',
            message: 'Are you sure you want to delete this history entry?',
            confirmLabel: 'Delete',
            onConfirm: () {
              ref.read(taskHistoryProvider.notifier).deleteEntry(entryId);
              ref.read(selectedHistoryIdProvider.notifier).state = null;
              ref.read(backgroundPanelViewProvider.notifier).state =
                  BackgroundPanelView.history;
            },
            onCancel: () => setState(() => _showDeleteConfirm = false),
          ),
      ],
    );
  }

  Widget _buildLocalConfirmOverlay({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        child: InkWell(
          onTap: onCancel,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Center(
            child: InkWell(
              onTap: () {}, // Prevent tap from bubbling up
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: onCancel,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.manrope(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                              minimumSize: const Size(0, 40),
                            ),
                            child: Text(
                              confirmLabel,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String statusName) {
    final color = _getStatusColor(statusName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        statusName.toUpperCase(),
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.violet.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 1),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            color: AppColors.textMuted.withValues(alpha: 0.4),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.05),
    );
  }

  Widget _buildPathFlow(TaskHistoryEntry entry) {
    // For Source: show only the parent directory path
    final sourcePath =
        entry.sourcePaths != null && entry.sourcePaths!.isNotEmpty
        ? entry.sourcePaths![0]
        : null;

    final sourceParent = sourcePath != null ? p.dirname(sourcePath) : null;
    final sourceExists =
        sourceParent != null && Directory(sourceParent).existsSync();

    // For Destination: entry.targetPath is already the parent directory
    final targetPath = entry.targetPath;
    final targetExists =
        targetPath != null && Directory(targetPath).existsSync();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sourceParent != null)
            _buildPathItem(
              Icons.folder_open_rounded,
              'Source Folder',
              sourceParent,
              sourceExists,
              () => _navigateTo(sourceParent),
            ),
          if (sourceParent != null && targetPath != null)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
              child: Icon(
                Icons.south_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          if (targetPath != null)
            _buildPathItem(
              Icons.download_for_offline_rounded,
              'Destination',
              targetPath,
              targetExists,
              () => _navigateTo(targetPath),
            ),
        ],
      ),
    );
  }

  Widget _buildPathItem(
    IconData icon,
    String label,
    String path,
    bool exists,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: exists ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: exists
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    StringUtils.truncateMiddle(path, maxLength: 50),
                    style: GoogleFonts.manrope(
                      color: exists
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: exists ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ),
            if (exists)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessedFileItem(String srcPath, String destPath, bool exists) {
    return InkWell(
      onTap: exists ? () => _navigateTo(destPath, forceParent: true) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.04),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getItemIcon(destPath),
              size: 16,
              color: exists
                  ? AppColors.violet.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.basename(destPath),
                style: GoogleFonts.manrope(
                  color: exists
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (exists)
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.15),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenamedFileItem(String oldPath, String newPath) {
    final exists =
        File(newPath).existsSync() || Directory(newPath).existsSync();
    return InkWell(
      onTap: exists ? () => _navigateTo(newPath, forceParent: true) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.04),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getItemIcon(newPath),
              size: 16,
              color: exists
                  ? AppColors.violet.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: p.basename(oldPath),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    TextSpan(
                      text: '  →  ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    TextSpan(
                      text: p.basename(newPath),
                      style: TextStyle(
                        color: exists
                            ? AppColors.violet
                            : Colors.white.withValues(alpha: 0.2),
                        decoration: exists ? TextDecoration.underline : null,
                        decorationColor: AppColors.violet.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (exists)
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.violet.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedFileItem(String path, bool isFolder) {
    final exists = isFolder
        ? Directory(path).existsSync()
        : File(path).existsSync();
    return InkWell(
      onTap: exists ? () => _navigateTo(path, forceParent: true) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.04),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isFolder ? Icons.folder_rounded : _getFileIcon(path),
              size: 16,
              color: exists
                  ? AppColors.violet.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.basename(path),
                style: GoogleFonts.manrope(
                  color: exists
                      ? AppColors.violet
                      : Colors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: exists ? TextDecoration.underline : null,
                  decorationColor: AppColors.violet.withValues(alpha: 0.4),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (exists)
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.violet.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedFileItem(String path, bool isTrash) {
    // If it was moved to trash, it might still exist at the new location, but here we show the OLD path.
    // Usually, we just show it as 'deleted'.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTrash ? Icons.delete_sweep_rounded : Icons.delete_forever_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.basename(path),
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            isTrash ? 'TRASHED' : 'DELETED',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.1),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            _formatDateTime(time),
            style: GoogleFonts.firaCode(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _toPastTense(String title) {
    if (title.startsWith('Copying')) {
      return title.replaceFirst('Copying', 'Copied');
    }
    if (title.startsWith('Moving')) {
      return title.replaceFirst('Moving', 'Moved');
    }
    if (title.startsWith('Deleting')) {
      return title.replaceFirst('Deleting', 'Deleted');
    }
    if (title.startsWith('Renaming')) {
      return title.replaceFirst('Renaming', 'Renamed');
    }
    return title;
  }

  IconData _getOperationIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('copy')) return Icons.copy_all_rounded;
    if (t.contains('mov')) return Icons.drive_file_move_rounded;
    if (t.contains('delet') || t.contains('trash')) {
      return Icons.delete_forever_rounded;
    }
    if (t.contains('renam')) return Icons.edit_rounded;
    if (t.contains('new folder')) return Icons.create_new_folder_rounded;
    if (t.contains('new file')) return Icons.note_add_rounded;
    return Icons.task_alt_rounded;
  }

  Color _getOperationColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('copy') || t.contains('mov')) return Colors.greenAccent;
    if (t.contains('delet') || t.contains('trash')) return Colors.redAccent;
    if (t.contains('rename')) return Colors.blueAccent;
    return AppColors.violet;
  }

  Color _getStatusColor(String statusName) {
    switch (statusName) {
      case 'completed':
        return AppColors.success;
      case 'error':
        return AppColors.error;
      case 'cancelled':
        return Colors.orange;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getFileIcon(String path) {
    final ext = p.extension(path).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (['.mp4', '.mkv', '.mov', '.avi'].contains(ext)) {
      return Icons.videocam_outlined;
    }
    if (['.mp3', '.wav', '.flac', '.m4a'].contains(ext)) {
      return Icons.audio_file_outlined;
    }
    if (['.pdf', '.doc', '.docx', '.txt'].contains(ext)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  IconData _getItemIcon(String path, {bool? isDirectory}) {
    if (isDirectory ?? false) return Icons.folder_rounded;
    if (isDirectory == false) return _getFileIcon(path);

    // Fallback: check filesystem if available
    try {
      if (Directory(path).existsSync()) return Icons.folder_rounded;
    } catch (_) {}
    return _getFileIcon(path);
  }
}
