import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';

/// Detail view for a single task history entry.
class TaskHistoryDetailView extends ConsumerStatefulWidget {
  const TaskHistoryDetailView({super.key});

  @override
  ConsumerState<TaskHistoryDetailView> createState() => _TaskHistoryDetailViewState();
}

class _TaskHistoryDetailViewState extends ConsumerState<TaskHistoryDetailView> {
  bool _logsExpanded = false;
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryId = ref.watch(selectedHistoryIdProvider);
    if (entryId == null) return const SizedBox.shrink();

    final entry = ref.read(taskHistoryProvider.notifier).getEntry(entryId);
    if (entry == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(backgroundPanelViewProvider.notifier).state =
                      BackgroundPanelView.history;
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
                  'Task Detail',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  entry.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                // Status
                _buildDetailRow('Status', _formatStatus(entry.statusName)),
                const SizedBox(height: 8),
                // Source / Destination
                _buildDetailRow('Description', entry.subtitle),
                const SizedBox(height: 8),
                // Items processed
                if (entry.totalCount > 0) ...[
                  _buildDetailRow(
                      'Items', '${entry.processedCount} of ${entry.totalCount}'),
                  const SizedBox(height: 8),
                ],
                // Duration
                if (entry.duration != null) ...[
                  _buildDetailRow('Duration', _formatDuration(entry.duration!)),
                  const SizedBox(height: 8),
                ],
                // Started at
                if (entry.startedAt != null) ...[
                  _buildDetailRow('Started', _formatDateTime(entry.startedAt!)),
                  const SizedBox(height: 8),
                ],
                // Completed at
                if (entry.completedAt != null) ...[
                  _buildDetailRow('Completed', _formatDateTime(entry.completedAt!)),
                  const SizedBox(height: 8),
                ],
                // Error
                if (entry.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  _buildDetailRow('Error', entry.errorMessage!,
                      valueColor: AppColors.error),
                  const SizedBox(height: 8),
                ],
                // Logs section
                if (entry.logs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => _logsExpanded = !_logsExpanded),
                    child: Row(
                      children: [
                        Icon(
                          _logsExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Logs (${entry.logs.length} lines)',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_logsExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: ListView.builder(
                        controller: _logScrollController,
                        itemCount: entry.logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              entry.logs[index],
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
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              color: valueColor ?? Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatStatus(String statusName) {
    switch (statusName) {
      case 'completed':
        return 'Completed';
      case 'error':
        return 'Error';
      case 'cancelled':
        return 'Cancelled';
      case 'running':
        return 'Interrupted';
      default:
        return statusName;
    }
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
}
