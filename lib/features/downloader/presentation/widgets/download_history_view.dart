import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/core/utils/string_utils.dart';

class DownloadHistoryView extends ConsumerWidget {
  const DownloadHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(filteredDownloadHistoryProvider);
    final selection = ref.watch(downloadHistorySelectionProvider);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white70),
                onPressed: () {
                  ref.read(downloadHistorySelectionProvider.notifier).clear();
                  ref.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.tasks;
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Download History',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (history.isNotEmpty)
                _FilterButton(),
            ],
          ),
        ),
        
        // Multi-select actions bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: selection.isNotEmpty ? 52 : 0,
          margin: EdgeInsets.symmetric(
            horizontal: 24, 
            vertical: selection.isNotEmpty ? 8 : 0
          ),
          decoration: BoxDecoration(
            color: AppColors.violet.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.violet.withOpacity(0.3)),
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    '${selection.length} selected',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.violet,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.deselect_rounded, size: 20),
                    color: Colors.white70,
                    tooltip: 'Clear Selection',
                    onPressed: () => ref.read(downloadHistorySelectionProvider.notifier).clear(),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: AppColors.violet.withOpacity(0.2)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.redAccent,
                    tooltip: 'Delete Selected',
                    onPressed: () => _confirmDeleteSelection(context, ref, selection),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),

        // List
        Expanded(
          child: history.isEmpty
              ? _buildEmptyState()
              : NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      ref.read(downloadHistoryProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final isSelected = selection.contains(entry.id);
                      return _HistoryTile(
                        entry: entry,
                        isSelected: isSelected,
                        onTap: () {
                          if (selection.isNotEmpty) {
                            ref.read(downloadHistorySelectionProvider.notifier).toggle(entry.id);
                          } else {
                            ref.read(selectedDownloadHistoryIdProvider.notifier).state = entry.id;
                            ref.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.historyDetail;
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'No download history',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelection(BuildContext context, WidgetRef ref, Set<String> selection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Selected History',
          style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${selection.length} items from history?\nThis will not delete the downloaded files.',
          style: GoogleFonts.manrope(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              foregroundColor: Colors.redAccent,
              elevation: 0,
            ),
            onPressed: () {
              ref.read(downloadHistoryProvider.notifier).deleteEntries(selection);
              ref.read(downloadHistorySelectionProvider.notifier).clear();
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final DownloadHistoryEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuccess = entry.statusName.toLowerCase() == 'completed';
    final isError = entry.statusName.toLowerCase() == 'error';

    Color statusColor = Colors.white54;
    IconData statusIcon = Icons.info_outline;

    if (isSuccess) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (isError) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline_rounded;
    } else if (entry.statusName.toLowerCase() == 'cancelled') {
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.cancel_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () {
            ref.read(downloadHistorySelectionProvider.notifier).setAnchor(entry.id);
            ref.read(downloadHistorySelectionProvider.notifier).toggle(entry.id);
          },
          onSecondaryTapDown: (_) {
            if (!isSelected) {
              ref.read(downloadHistorySelectionProvider.notifier).toggle(entry.id);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.violet.withOpacity(0.15)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? AppColors.violet.withOpacity(0.5)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StringUtils.truncateMiddle(entry.title, maxLength: 40),
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            entry.statusName.toUpperCase(),
                            style: GoogleFonts.manrope(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(entry.createdAt),
                            style: GoogleFonts.manrope(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && now.day == date.day) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays <= 1 && now.subtract(const Duration(days: 1)).day == date.day) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _FilterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(downloadHistoryFilterProvider);
    final isActive = !filter.isEmpty;

    return IconButton(
      icon: Stack(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 20,
            color: isActive ? AppColors.violet : Colors.white70,
          ),
          if (isActive)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.violet,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        _FilterOverlay.show(context, position, box.size, ref);
      },
    );
  }
}

class _FilterOverlay extends StatefulWidget {
  final Offset position;
  final Size size;
  final WidgetRef ref;

  const _FilterOverlay({
    required this.position,
    required this.size,
    required this.ref,
  });

  static void show(BuildContext context, Offset position, Size size, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: position.dy + size.height + 8,
              right: MediaQuery.of(context).size.width - position.dx - size.width,
              child: Material(
                color: Colors.transparent,
                child: _FilterOverlay(position: position, size: size, ref: ref),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  State<_FilterOverlay> createState() => _FilterOverlayState();
}

class _FilterOverlayState extends State<_FilterOverlay> {
  late DownloadHistoryFilter filter;
  late Set<DateTime> availableDates;

  @override
  void initState() {
    super.initState();
    filter = widget.ref.read(downloadHistoryFilterProvider);
    availableDates = widget.ref.read(availableDownloadDatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 16, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'FILTER HISTORY',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (!filter.isEmpty)
                  InkWell(
                    onTap: () {
                      setState(() {
                        filter = const DownloadHistoryFilter();
                        widget.ref.read(downloadHistoryFilterProvider.notifier).state = filter;
                      });
                    },
                    child: Text(
                      'CLEAR',
                      style: GoogleFonts.manrope(
                        color: AppColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          
          // Status Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filter.status ?? 'All',
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceBase,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.5)),
                      items: ['All', 'Completed', 'Error', 'Cancelled'].map((op) {
                        return DropdownMenuItem(
                          value: op,
                          child: Text(op),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          filter = filter.copyWith(status: val);
                          widget.ref.read(downloadHistoryFilterProvider.notifier).state = filter;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Container(height: 1, color: Colors.white.withOpacity(0.05)),

          // Custom simplified calendar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Date',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (filter.selectedDates != null && filter.selectedDates!.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setState(() {
                            filter = filter.copyWith(selectedDates: {});
                            widget.ref.read(downloadHistoryFilterProvider.notifier).state = filter;
                          });
                        },
                        child: Text(
                          'CLEAR DATES',
                          style: GoogleFonts.manrope(
                            color: AppColors.violet,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _SimpleCalendar(
                  selectedDates: filter.selectedDates ?? {},
                  availableDates: availableDates,
                  onDatesChanged: (dates) {
                    setState(() {
                      filter = filter.copyWith(selectedDates: dates);
                      widget.ref.read(downloadHistoryFilterProvider.notifier).state = filter;
                    });
                  },
                ),
              ],
            ),
          ),
          
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () {
                _confirmClearAll(context, widget.ref);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Clear All History'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        title: const Text('Clear All History', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to clear all download history?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(downloadHistoryProvider.notifier).clearAll();
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close overlay
            },
            child: const Text('Clear All'),
          )
        ],
      ),
    );
  }
}

class _SimpleCalendar extends StatefulWidget {
  final Set<DateTime> selectedDates;
  final Set<DateTime> availableDates;
  final ValueChanged<Set<DateTime>> onDatesChanged;

  const _SimpleCalendar({
    required this.selectedDates,
    required this.availableDates,
    required this.onDatesChanged,
  });

  @override
  State<_SimpleCalendar> createState() => _SimpleCalendarState();
}

class _SimpleCalendarState extends State<_SimpleCalendar> {
  late DateTime _viewDate;

  @override
  void initState() {
    super.initState();
    if (widget.availableDates.isNotEmpty) {
      _viewDate = widget.availableDates.reduce((a, b) => a.isAfter(b) ? a : b);
    } else {
      _viewDate = DateTime.now();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_viewDate.year, _viewDate.month, 1);
    final lastDayOfMonth = DateTime(_viewDate.year, _viewDate.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 16, color: Colors.white54),
              onPressed: () => setState(() => _viewDate = DateTime(_viewDate.year, _viewDate.month - 1)),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            Text(
              '${_viewDate.year}-${_viewDate.month.toString().padLeft(2, '0')}',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 16, color: Colors.white54),
              onPressed: () => setState(() => _viewDate = DateTime(_viewDate.year, _viewDate.month + 1)),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: 42,
          itemBuilder: (context, index) {
            if (index < firstWeekday || index >= firstWeekday + lastDayOfMonth.day) {
              return const SizedBox.shrink();
            }
            final date = DateTime(_viewDate.year, _viewDate.month, index - firstWeekday + 1);
            final isAvailable = widget.availableDates.any((d) => _isSameDay(d, date));
            final isSelected = widget.selectedDates.any((d) => _isSameDay(d, date));
            
            return InkWell(
              onTap: isAvailable ? () {
                final newDates = Set.of(widget.selectedDates);
                if (isSelected) {
                  newDates.removeWhere((d) => _isSameDay(d, date));
                } else {
                  newDates.add(date);
                }
                widget.onDatesChanged(newDates);
              } : null,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.violet : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  date.day.toString(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: isSelected ? Colors.white : (isAvailable ? Colors.white70 : Colors.white24),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
