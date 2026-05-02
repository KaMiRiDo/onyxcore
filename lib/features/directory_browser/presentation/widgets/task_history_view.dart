import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';

/// History list view within the background panel.
class TaskHistoryView extends ConsumerStatefulWidget {
  const TaskHistoryView({super.key});

  @override
  ConsumerState<TaskHistoryView> createState() => _TaskHistoryViewState();
}

class _TaskHistoryViewState extends ConsumerState<TaskHistoryView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      ref.read(taskHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(taskHistoryProvider);
    final notifier = ref.read(taskHistoryProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(backgroundPanelViewProvider.notifier).state =
                      BackgroundPanelView.tasks;
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
                  'History',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (entries.isNotEmpty)
                InkWell(
                  onTap: () => _confirmClearAll(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.manrope(
                        color: AppColors.error.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        // List
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 40,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No history yet',
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length + (notifier.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Loading indicator at the end
                    if (index == entries.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.violet,
                            ),
                          ),
                        ),
                      );
                    }

                    final entry = entries[index];

                    // Date section header
                    Widget? dateHeader;
                    if (index == 0 ||
                        !_isSameDay(
                            entries[index - 1].createdAt, entry.createdAt)) {
                      dateHeader = Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          _formatDateHeader(entry.createdAt),
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateHeader != null) dateHeader,
                        _buildHistoryItem(entry),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(TaskHistoryEntry entry) {
    final statusIcon = _getStatusIcon(entry.statusName);
    final statusColor = _getStatusColor(entry.statusName);

    return InkWell(
      onTap: () {
        ref.read(selectedHistoryIdProvider.notifier).state = entry.id;
        ref.read(backgroundPanelViewProvider.notifier).state =
            BackgroundPanelView.historyDetail;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(entry.createdAt),
                    style: GoogleFonts.manrope(
                      color: AppColors.textMuted.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.15),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Clear All History',
        message: 'This will permanently delete all task history. This action cannot be undone.',
        confirmText: 'Clear All',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      ref.read(taskHistoryProvider.notifier).clearAll();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'TODAY';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'YESTERDAY';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon(String statusName) {
    switch (statusName) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.radio_button_unchecked;
    }
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
}
