import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:path/path.dart' as p;

class DownloadHistoryDetailView extends ConsumerStatefulWidget {
  const DownloadHistoryDetailView({super.key});

  @override
  ConsumerState<DownloadHistoryDetailView> createState() =>
      _DownloadHistoryDetailViewState();
}

class _DownloadHistoryDetailViewState
    extends ConsumerState<DownloadHistoryDetailView> {
  bool _logsExpanded = false;
  bool _isCopied = false;
  bool _isLogsCopied = false;

  @override
  Widget build(BuildContext context) {
    final entryId = ref.watch(selectedDownloadHistoryIdProvider);
    if (entryId == null) {
      return const SizedBox();
    }

    final entry = ref.watch(downloadHistoryProvider.notifier).getEntry(entryId);
    if (entry == null) {
      return Center(
        child: Text(
          'History not found',
          style: GoogleFonts.manrope(color: Colors.white),
        ),
      );
    }

    final isSuccess = entry.statusName.toLowerCase() == 'completed';
    final isError = entry.statusName.toLowerCase() == 'error';



    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(selectedDownloadHistoryIdProvider.notifier).state =
                      null;
                  ref.read(downloadsPanelViewProvider.notifier).state =
                      DownloadsPanelView.history;
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Download Details',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error.withOpacity(0.7),
                ),
                tooltip: 'Delete History',
                onPressed: () {
                  ref
                      .read(downloadHistoryProvider.notifier)
                      .deleteEntry(entryId);
                  ref.read(selectedDownloadHistoryIdProvider.notifier).state =
                      null;
                  ref.read(downloadsPanelViewProvider.notifier).state =
                      DownloadsPanelView.history;
                },
              ),
              Tooltip(
                message: 'Close Panel',
                waitDuration: const Duration(milliseconds: 500),
                child: InkWell(
                  onTap: () {
                    ref.read(selectedDownloadHistoryIdProvider.notifier).state =
                        null;
                    ref.read(downloadsPanelViewProvider.notifier).state =
                        DownloadsPanelView.tasks;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.5),
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
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.violet.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              size: 20,
                              color: AppColors.violet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.title,
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
                      if (entry.errorMessage != null &&
                          entry.errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.2),
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
                Text(
                  'FLOW',
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPathItem(
                        Icons.link_rounded,
                        'Source URL',
                        entry.url,
                        true,
                        isUrl: true,
                        isCopied: _isCopied,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: entry.url));
                          setState(() {
                            _isCopied = true;
                          });
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _isCopied = false;
                              });
                            }
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Icon(
                          Icons.south_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      _buildPathItem(
                        Icons.download_for_offline_rounded,
                        'Destination',
                        entry.destination,
                        File(entry.destination).existsSync() ||
                            Directory(entry.destination).existsSync(),
                        onTap: () {
                          final dir = Directory(entry.destination).existsSync()
                              ? entry.destination
                              : p.dirname(entry.destination);
                          if (Directory(dir).existsSync()) {
                            ref
                                .read(navigationProvider.notifier)
                                .navigateTo(dir);
                            if (File(entry.destination).existsSync()) {
                              ref
                                  .read(selectionProvider.notifier)
                                  .selectMultiple([entry.destination]);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Processed Items and Stats
                ...(() {
                  int size = 0;
                  int itemCount = 0;
                  List<String> processedFilePaths = [];

                  // Parse logs to find downloaded files
                  for (final log in entry.logs) {
                    String? path;
                    if (log.contains('[download] Destination: ')) {
                      path = log.split('[download] Destination: ')[1].trim();
                    } else if (log.contains(
                      '[Merger] Merging formats into "',
                    )) {
                      path = log
                          .split('[Merger] Merging formats into "')[1]
                          .replaceAll('"', '')
                          .trim();
                    } else if (log.contains('has already been downloaded')) {
                      final idx = log.indexOf('has already been downloaded');
                      if (log.startsWith('[download] ')) {
                        path = log.substring(11, idx).trim();
                      }
                    } else if (log.startsWith('/') || log.startsWith(r'C:\')) {
                      path = log;
                    }

                    if (path != null) {
                      final ext = p.extension(path).toLowerCase();
                      if (ext != '.json' &&
                          !processedFilePaths.contains(path)) {
                        processedFilePaths.add(path);
                      }
                    }
                  }

                  itemCount = processedFilePaths.length;
                  for (final path in processedFilePaths) {
                    final f = File(path);
                    if (f.existsSync()) {
                      try {
                        size += f.lengthSync();
                      } catch (_) {}
                    }
                  }

                  return [
                    if (processedFilePaths.isNotEmpty) ...[
                      Text(
                        'PROCESSED ITEMS',
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted.withOpacity(0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: processedFilePaths.length,
                          itemBuilder: (context, index) {
                            final path = processedFilePaths[index];
                            final f = File(path);
                            final exists = f.existsSync();

                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  final dir = p.dirname(path);
                                  if (Directory(dir).existsSync()) {
                                    ref
                                        .read(navigationProvider.notifier)
                                        .navigateTo(dir);
                                    if (exists) {
                                      ref
                                          .read(selectionProvider.notifier)
                                          .selectMultiple([path]);
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white.withOpacity(0.04),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file_rounded,
                                        size: 16,
                                        color: exists
                                            ? AppColors.violet.withOpacity(0.6)
                                            : Colors.white24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          p.basename(path),
                                          style: GoogleFonts.manrope(
                                            color: exists
                                                ? Colors.white.withOpacity(0.8)
                                                : Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            decoration: exists
                                                ? TextDecoration.underline
                                                : TextDecoration.lineThrough,
                                            decorationColor: exists
                                                ? AppColors.violet.withOpacity(
                                                    0.5,
                                                  )
                                                : Colors.white24,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!exists)
                                        Text(
                                          'Deleted',
                                          style: GoogleFonts.manrope(
                                            color: Colors.redAccent.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Stats Grid
                    Text(
                      'STATISTICS',
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              Icons.timer_outlined,
                              'Duration',
                              entry.duration != null
                                  ? _formatDuration(entry.duration!)
                                  : 'N/A',
                            ),
                          ),
                          _buildStatDivider(),
                          Expanded(
                            child: _buildStatItem(
                              Icons.inventory_2_outlined,
                              'Items',
                              '$itemCount',
                            ),
                          ),
                          _buildStatDivider(),
                          Expanded(
                            child: _buildStatItem(
                              Icons.sd_storage_outlined,
                              'Size',
                              StringUtils.formatBytes(size),
                            ),
                          ),
                          if (entry.duration != null &&
                              entry.duration!.inSeconds > 0 &&
                              size > 0) ...[
                            _buildStatDivider(),
                            Expanded(
                              child: _buildStatItem(
                                Icons.speed_outlined,
                                'Speed',
                                '${StringUtils.formatBytes((size / entry.duration!.inSeconds).round())}/s',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ];
                }()),

                // Timeline
                Text(
                  'TIMELINE',
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTimelineItem('Created', entry.createdAt),
                if (entry.completedAt != null)
                  _buildTimelineItem('Finished', entry.completedAt!),
                const SizedBox(height: 24),

                // Logs
                if (entry.logs.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _logsExpanded = !_logsExpanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _logsExpanded
                              ? AppColors.violet.withOpacity(0.2)
                              : Colors.white.withOpacity(0.04),
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
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${entry.logs.length} entries recorded',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textMuted.withOpacity(0.5),
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
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_logsExpanded) ...[
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 250,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: ListView.builder(
                            itemCount: entry.logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  entry.logs[index],
                                  style: GoogleFonts.firaCode(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: _buildLogsCopyButton(entry.logs),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String statusName) {
    final isSuccess = statusName.toLowerCase() == 'completed';
    final isError = statusName.toLowerCase() == 'error';

    Color color = Colors.white54;
    if (isSuccess) color = Colors.greenAccent;
    if (isError) color = Colors.redAccent;
    if (statusName.toLowerCase() == 'cancelled') color = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
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
        Icon(icon, size: 14, color: AppColors.violet.withOpacity(0.5)),
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
            color: AppColors.textMuted.withOpacity(0.4),
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
      color: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildPathItem(
    IconData icon,
    String label,
    String path,
    bool exists, {
    bool isUrl = false,
    VoidCallback? onTap,
    bool isCopied = false,
    VoidCallback? onCopy,
  }) {
    final content = Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: exists
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                StringUtils.truncateMiddle(path, maxLength: 60),
                style: GoogleFonts.manrope(
                  color: exists
                      ? (onTap != null
                            ? AppColors.violet
                            : Colors.white.withOpacity(0.7))
                      : Colors.white.withOpacity(0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: exists
                      ? (onTap != null ? TextDecoration.underline : null)
                      : TextDecoration.lineThrough,
                  decorationColor: AppColors.violet.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        if (isUrl)
          IconButton(
            icon: Icon(
              isCopied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
              color: isCopied
                  ? Colors.greenAccent
                  : Colors.white.withOpacity(0.5),
            ),
            onPressed: onCopy,
            tooltip: isCopied ? 'Copied!' : 'Copy URL',
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: onTap != null && exists
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                child: content,
              ),
            )
          : content,
    );
  }

  Widget _buildTimelineItem(String label, DateTime date) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.violet.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
          style: GoogleFonts.firaCode(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLogsCopyButton(List<String> logs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: logs.join('\n')));
          setState(() => _isLogsCopied = true);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isLogsCopied = false);
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _isLogsCopied ? Icons.check_rounded : Icons.copy_rounded,
            size: 16,
            color: _isLogsCopied ? Colors.greenAccent : Colors.white70,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes.remainder(60);
      return '${d.inHours}h ${mins > 0 ? '${mins}m' : ''}'.trim();
    } else if (d.inMinutes > 0) {
      final secs = d.inSeconds.remainder(60);
      return '${d.inMinutes}m ${secs > 0 ? '${secs}s' : ''}'.trim();
    } else {
      return '${d.inSeconds}s';
    }
  }
}
