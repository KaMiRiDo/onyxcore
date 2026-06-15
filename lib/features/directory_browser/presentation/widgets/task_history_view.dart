import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/utils/string_utils.dart';

/// History list view within the background panel.
class TaskHistoryView extends ConsumerStatefulWidget {
  const TaskHistoryView({super.key});

  @override
  ConsumerState<TaskHistoryView> createState() => _TaskHistoryViewState();
}

class _TaskHistoryViewState extends ConsumerState<TaskHistoryView> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showClearConfirm = false;
  bool _showDeleteSelectedConfirm = false;
  bool _showFilterBox = false;
  TaskHistoryFilter _tempFilter = const TaskHistoryFilter(selectedDates: {});
  bool _isFiltering = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
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
    final selection = ref.watch(historySelectionProvider);
    final hasSelection = selection.isNotEmpty;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.delete &&
            hasSelection) {
          setState(() => _showDeleteSelectedConfirm = true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                _buildHeader(hasSelection, selection),

                // Toolbar
                _buildToolbar(),

                Expanded(
                  child: _isFiltering ? _buildLoader() : _buildList(selection),
                ),
              ],
            ),

            if (_showFilterBox) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showFilterBox = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
              _buildFilterOverlay(),
            ],

            if (_showClearConfirm) _buildClearAllConfirmOverlay(),

            if (_showDeleteSelectedConfirm)
              _buildDeleteSelectedConfirmOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasSelection, Set<String> selection) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (hasSelection) {
                ref.read(historySelectionProvider.notifier).clear();
              } else {
                ref.read(backgroundPanelViewProvider.notifier).state =
                    BackgroundPanelView.tasks;
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                hasSelection ? Icons.close_rounded : Icons.arrow_back_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              hasSelection ? '${selection.length} Selected' : 'History',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Close button
          Tooltip(
            message: 'Close Panel',
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
              onTap: () {
                ref.read(backgroundPanelOpenProvider.notifier).state = false;
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
    );
  }

  Widget _buildToolbar() {
    final historyNotifier = ref.read(taskHistoryProvider.notifier);
    final totalCount = historyNotifier.totalEntries;
    final totalSize = StringUtils.formatBytes(historyNotifier.historyFileSize);
    final currentFilter = ref.watch(taskHistoryFilterProvider);
    final isFiltered = !currentFilter.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.04), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 12,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          Text(
            '$totalCount Entries',
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '•',
              style: TextStyle(
                color: Colors.white.withOpacity(0.1),
                fontSize: 10,
              ),
            ),
          ),
          Text(
            totalSize,
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (isFiltered)
            IconButton(
              onPressed: () {
                ref.read(taskHistoryFilterProvider.notifier).state =
                    const TaskHistoryFilter();
                setState(() {
                  _tempFilter = const TaskHistoryFilter();
                  _showFilterBox = false;
                });
              },
              icon: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.error.withOpacity(0.6),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Clear Filter',
            ),
          const SizedBox(width: 8),
          _buildToolButton(
            icon: Icons.filter_list_rounded,
            active: _showFilterBox || isFiltered,
            onTap: () => setState(() => _showFilterBox = !_showFilterBox),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.violet.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppColors.violet.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: active ? AppColors.violet : Colors.white.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildFilterOverlay() {
    final availableDates = ref.watch(availableDatesProvider);
    return Positioned(
      top: 120, // Moved down to avoid overlap
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 280, // Slightly bigger
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.03,
              ), // More transparent for glass effect
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HistoryCalendar(
                  selectedDates: _tempFilter.selectedDates ?? {},
                  availableDates: availableDates,
                  onDatesChanged: (dates) => setState(
                    () => _tempFilter = _tempFilter.copyWith(
                      selectedDates: dates,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildOperationDropdown(
                  _tempFilter.operationType ?? 'All',
                  (val) => setState(
                    () =>
                        _tempFilter = _tempFilter.copyWith(operationType: val),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => setState(() => _showFilterBox = false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.manrope(
                            color: Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 36, // Reduced height
                        decoration: BoxDecoration(
                          gradient:
                              AppTheme.primaryGradient, // Match Overview style
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violet.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              setState(() {
                                _isFiltering = true;
                                _showFilterBox = false;
                              });
                              await Future.delayed(
                                const Duration(milliseconds: 300),
                              );
                              ref
                                      .read(taskHistoryFilterProvider.notifier)
                                      .state =
                                  _tempFilter;
                              if (mounted) setState(() => _isFiltering = false);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.filter_list_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'FILTER',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }

  Widget _buildOperationDropdown(String value, Function(String?) onChanged) {
    final ops = ['All', 'Rename', 'Delete', 'Copy', 'Move', 'Create'];
    return Container(
      height: 36, // Reduced height
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E1E26),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Colors.white24,
          ),
          isExpanded: true,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 11,
          ), // Slightly smaller font
          onChanged: onChanged,
          items: ops
              .map((op) => DropdownMenuItem(value: op, child: Text(op)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.violet.withOpacity(0.5),
              ),
              backgroundColor: Colors.white.withOpacity(0.05),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Filtering history...',
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(Set<String> selection) {
    final history = ref.watch(filteredTaskHistoryProvider);
    final hasSelection = selection.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    final prevEntry = index > 0 ? history[index - 1] : null;
                    final isNewDay =
                        prevEntry == null ||
                        entry.createdAt.day != prevEntry.createdAt.day ||
                        entry.createdAt.month != prevEntry.createdAt.month ||
                        entry.createdAt.year != prevEntry.createdAt.year;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isNewDay)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                            child: Text(
                              _formatDate(entry.createdAt),
                              style: GoogleFonts.manrope(
                                color: Colors.white.withOpacity(0.2),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        _buildHistoryItem(context, entry, selection),
                      ],
                    );
                  },
                ),
        ),
        // Bottom Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Row(
            children: [
              if (hasSelection)
                Expanded(
                  child: _buildActionButton(
                    context,
                    label: 'Delete Selected',
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    onPressed: () =>
                        setState(() => _showDeleteSelectedConfirm = true),
                  ),
                )
              else
                Expanded(
                  child: _buildActionButton(
                    context,
                    label: 'Clear All History',
                    icon: Icons.delete_sweep_rounded,
                    color: AppColors.error,
                    onPressed: () => setState(() => _showClearConfirm = true),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final filter = ref.watch(taskHistoryFilterProvider);
    final isFilterActive = !filter.isEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFilterActive
                ? Icons.filter_list_off_rounded
                : Icons.history_rounded,
            size: 48,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 16),
          Text(
            isFilterActive
                ? 'No history matching the filter'
                : 'No history yet',
            style: GoogleFonts.manrope(
              color: AppColors.textMuted.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isFilterActive) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                ref.read(taskHistoryFilterProvider.notifier).state =
                    const TaskHistoryFilter();
                setState(() => _tempFilter = const TaskHistoryFilter());
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(
                'CLEAR FILTER',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.violet,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClearAllConfirmOverlay() {
    return _buildBaseOverlay(
      child: _ClearHistoryDialog(
        onCancel: () => setState(() => _showClearConfirm = false),
        onConfirm: (filter) {
          if (filter == null) {
            ref.read(taskHistoryProvider.notifier).clearAll();
          } else {
            ref.read(taskHistoryProvider.notifier).deleteFiltered(filter);
          }
          setState(() => _showClearConfirm = false);
        },
      ),
    );
  }

  Widget _buildDeleteSelectedConfirmOverlay() {
    final selection = ref.read(historySelectionProvider);
    return _buildBaseOverlay(
      child: _DeleteConfirmDialog(
        title: 'Delete Selected?',
        message: 'Remove ${selection.length} selected items from history?',
        confirmLabel: 'Delete',
        onConfirm: () {
          ref.read(taskHistoryProvider.notifier).deleteEntries(selection);
          ref.read(historySelectionProvider.notifier).clear();
          setState(() => _showDeleteSelectedConfirm = false);
        },
        onCancel: () => setState(() => _showDeleteSelectedConfirm = false),
      ),
    );
  }

  Widget _buildBaseOverlay({required Widget child}) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withOpacity(0.4),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    TaskHistoryEntry entry,
    Set<String> selection,
  ) {
    final isSelected =
        selection.contains(entry.id) ||
        ref.watch(selectedHistoryIdProvider) == entry.id;
    final statusColor = _getStatusColor(entry.statusName);

    String subtitle = '';
    if (entry.totalCount > 0) {
      subtitle = '${entry.processedCount}/${entry.totalCount} items';
    }

    final isRename = entry.title.toLowerCase().contains('renam');
    final isDelete =
        entry.title.toLowerCase().contains('delet') ||
        entry.title.toLowerCase().contains('trash');

    if (!isRename &&
        entry.totalSizeBytes != null &&
        entry.totalSizeBytes! > 0) {
      final size = _formatBytes(entry.totalSizeBytes!);
      subtitle = subtitle.isEmpty ? size : '$subtitle • $size';
    }

    // Location summary
    String? locationInfo;
    if (entry.targetPath != null &&
        entry.sourcePaths != null &&
        entry.sourcePaths!.isNotEmpty) {
      final sourceDir = p.basename(p.dirname(entry.sourcePaths![0]));
      final targetDir = p.basename(entry.targetPath!);
      locationInfo = '$sourceDir → $targetDir';
    } else if (entry.targetPath != null) {
      locationInfo = 'to ${p.basename(entry.targetPath!)}';
    } else if ((isRename || isDelete) &&
        entry.sourcePaths != null &&
        entry.sourcePaths!.isNotEmpty) {
      locationInfo = 'in ${p.basename(p.dirname(entry.sourcePaths![0]))}';
    }

    final operationIcon = _getOperationIcon(entry.title);
    final opColor = _getOperationColor(entry.title);

    return InkWell(
      onTap: () {
        _focusNode.requestFocus();
        final isShiftPressed =
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.shiftLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.shiftRight,
            );
        final isControlPressed =
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlRight,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.metaLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.metaRight,
            );

        final selection = ref.read(historySelectionProvider);
        final hasSelection = selection.isNotEmpty;

        if (isShiftPressed) {
          final history = ref.read(filteredTaskHistoryProvider);
          ref
              .read(historySelectionProvider.notifier)
              .selectRange(history, entry.id);
        } else if (isControlPressed || hasSelection) {
          // If we are already in selection mode, single click toggles selection
          ref.read(historySelectionProvider.notifier).toggle(entry.id);
          ref.read(historySelectionProvider.notifier).setAnchor(entry.id);
          // If toggling results in empty selection, we can optionally clear the detail view highlight
          if (ref.read(historySelectionProvider).isEmpty) {
            ref.read(selectedHistoryIdProvider.notifier).state = null;
          }
        } else {
          // Normal click (no selection active): Clear bulk selection and open detail
          // We set the anchor AFTER clear so that subsequent shift-clicks work
          ref.read(historySelectionProvider.notifier).clear();
          ref.read(historySelectionProvider.notifier).setAnchor(entry.id);
          ref.read(selectedHistoryIdProvider.notifier).state = entry.id;
          ref.read(backgroundPanelViewProvider.notifier).state =
              BackgroundPanelView.historyDetail;
        }
      },
      onSecondaryTap: () {
        _focusNode.requestFocus();
        ref.read(historySelectionProvider.notifier).toggle(entry.id);
        ref.read(historySelectionProvider.notifier).setAnchor(entry.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.violet.withOpacity(0.15)
              : statusColor.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.violet.withOpacity(0.4)
                : statusColor.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: opColor.withOpacity(isSelected ? 0.3 : 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                operationIcon,
                size: 16,
                color: isSelected ? Colors.white : opColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _toPastTense(entry.title),
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: statusColor.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          entry.statusName.toUpperCase(),
                          style: GoogleFonts.manrope(
                            color: statusColor.withOpacity(0.8),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (subtitle.isNotEmpty) ...[
                        Text(
                          subtitle,
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.1),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                      if (locationInfo != null)
                        Expanded(
                          child: Text(
                            locationInfo,
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted.withOpacity(0.3),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTime(entry.createdAt),
                  style: GoogleFonts.firaCode(
                    color: Colors.white.withOpacity(0.15),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.05),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'TODAY';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'YESTERDAY';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _toPastTense(String title) {
    if (title.startsWith('Copying'))
      return title.replaceFirst('Copying', 'Copied');
    if (title.startsWith('Moving'))
      return title.replaceFirst('Moving', 'Moved');
    if (title.startsWith('Deleting'))
      return title.replaceFirst('Deleting', 'Deleted');
    if (title.startsWith('Renaming'))
      return title.replaceFirst('Renaming', 'Renamed');
    return title;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _getOperationIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('copy')) return Icons.copy_all_rounded;
    if (t.contains('mov')) return Icons.drive_file_move_rounded;
    if (t.contains('delet') || t.contains('trash'))
      return Icons.delete_forever_rounded;
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
}

class _ClearHistoryDialog extends ConsumerStatefulWidget {
  final VoidCallback onCancel;
  final Function(TaskHistoryFilter?) onConfirm;

  const _ClearHistoryDialog({required this.onCancel, required this.onConfirm});

  @override
  ConsumerState<_ClearHistoryDialog> createState() =>
      _ClearHistoryDialogState();
}

class _ClearHistoryDialogState extends ConsumerState<_ClearHistoryDialog> {
  bool _customOps = false;
  TaskHistoryFilter _filter = const TaskHistoryFilter(selectedDates: {});

  @override
  Widget build(BuildContext context) {
    final availableDates = ref.watch(availableDatesProvider);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Clear History',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _customOps
                      ? 'Select what you want to remove'
                      : 'Are you sure you want to permanently clear all task history?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                // Custom Operations Toggle
                InkWell(
                  onTap: () => setState(() => _customOps = !_customOps),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _customOps,
                        onChanged: (val) =>
                            setState(() => _customOps = val ?? false),
                        activeColor: AppColors.violet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Text(
                        'Custom operations',
                        style: GoogleFonts.manrope(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_customOps) ...[
                  const SizedBox(height: 16),
                  HistoryCalendar(
                    selectedDates: _filter.selectedDates ?? {},
                    availableDates: availableDates,
                    onDatesChanged: (dates) => setState(
                      () => _filter = _filter.copyWith(selectedDates: dates),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onCancel,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            widget.onConfirm(_customOps ? _filter : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(_customOps ? 'Delete' : 'Clear All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    final ops = ['All', 'Rename', 'Delete', 'Copy', 'Move', 'Create'];
    return Container(
      height: 36, // Reduced height
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter.operationType ?? 'All',
          dropdownColor: const Color(0xFF1E1E26),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Colors.white24,
          ),
          isExpanded: true,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 11,
          ), // Slightly smaller font
          onChanged: (val) =>
              setState(() => _filter = _filter.copyWith(operationType: val)),
          items: ops
              .map((op) => DropdownMenuItem(value: op, child: Text(op)))
              .toList(),
        ),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DeleteConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
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
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
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
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryCalendar extends StatefulWidget {
  final Set<DateTime> selectedDates;
  final Set<DateTime> availableDates;
  final ValueChanged<Set<DateTime>> onDatesChanged;

  const HistoryCalendar({
    super.key,
    required this.selectedDates,
    required this.availableDates,
    required this.onDatesChanged,
  });

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  late DateTime _viewDate;
  DateTime? _anchorDate;

  @override
  void initState() {
    super.initState();
    // Default view to newest available date or now
    if (widget.availableDates.isNotEmpty) {
      _viewDate = widget.availableDates.reduce((a, b) => a.isAfter(b) ? a : b);
    } else {
      _viewDate = DateTime.now();
    }
  }

  bool get _hasPrev {
    if (widget.availableDates.isEmpty) return false;
    final minDate = widget.availableDates.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    return _viewDate.year > minDate.year ||
        (_viewDate.year == minDate.year && _viewDate.month > minDate.month);
  }

  bool get _hasNext {
    if (widget.availableDates.isEmpty) return false;
    final maxDate = widget.availableDates.reduce(
      (a, b) => a.isAfter(b) ? a : b,
    );
    return _viewDate.year < maxDate.year ||
        (_viewDate.year == maxDate.year && _viewDate.month < maxDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final monthDays = _getDaysInMonth(_viewDate);
    final prevMonthDays = _getPrevMonthDays(_viewDate);
    final firstDayOfWeek =
        DateTime(_viewDate.year, _viewDate.month, 1).weekday % 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: _hasPrev ? Colors.white30 : Colors.white10,
              ),
              onPressed: _hasPrev
                  ? () => setState(
                      () => _viewDate = DateTime(
                        _viewDate.year,
                        _viewDate.month - 1,
                      ),
                    )
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Text(
              _formatMonthYear(_viewDate),
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: _hasNext ? Colors.white30 : Colors.white10,
              ),
              onPressed: _hasNext
                  ? () => setState(
                      () => _viewDate = DateTime(
                        _viewDate.year,
                        _viewDate.month + 1,
                      ),
                    )
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            DateTime date;
            bool currentMonth = true;
            if (index < firstDayOfWeek) {
              date = DateTime(
                _viewDate.year,
                _viewDate.month - 1,
                prevMonthDays - firstDayOfWeek + index + 1,
              );
              currentMonth = false;
            } else if (index < firstDayOfWeek + monthDays) {
              date = DateTime(
                _viewDate.year,
                _viewDate.month,
                index - firstDayOfWeek + 1,
              );
            } else {
              date = DateTime(
                _viewDate.year,
                _viewDate.month + 1,
                index - firstDayOfWeek - monthDays + 1,
              );
              currentMonth = false;
            }

            final normalizedDate = DateTime(date.year, date.month, date.day);
            final isAvailable = widget.availableDates.any(
              (d) => _isSameDay(d, normalizedDate),
            );
            final isSelected = widget.selectedDates.any(
              (d) => _isSameDay(d, normalizedDate),
            );
            final isToday = _isSameDay(DateTime.now(), normalizedDate);

            return InkWell(
              onTap: isAvailable ? () => _handleDateTap(normalizedDate) : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: !isSelected && isToday
                      ? AppColors.violet.withOpacity(0.1)
                      : (isSelected ? null : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isSelected
                      ? Border.all(
                          color: AppColors.violet.withOpacity(0.2),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Text(
                  date.day.toString(),
                  style: GoogleFonts.manrope(
                    color: isSelected
                        ? Colors.white
                        : (isAvailable
                              ? (currentMonth ? Colors.white70 : Colors.white24)
                              : Colors.white.withOpacity(0.05)),
                    fontSize: 9,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _handleDateTap(DateTime date) {
    final isShift =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );
    final isCtrl =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.metaLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.metaRight,
        );

    Set<DateTime> newDates = Set.from(widget.selectedDates);

    if (isShift && _anchorDate != null) {
      // Range select
      final start = _anchorDate!.isBefore(date) ? _anchorDate! : date;
      final end = _anchorDate!.isBefore(date) ? date : _anchorDate!;
      for (
        var d = start;
        d.isBefore(end.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))
      ) {
        newDates.add(DateTime(d.year, d.month, d.day));
      }
    } else if (isCtrl) {
      // Multi select
      final normalized = DateTime(date.year, date.month, date.day);
      if (newDates.any((d) => _isSameDay(d, normalized))) {
        newDates.removeWhere((d) => _isSameDay(d, normalized));
      } else {
        newDates.add(normalized);
      }
      _anchorDate = normalized;
    } else {
      // Single select
      newDates = {DateTime(date.year, date.month, date.day)};
      _anchorDate = DateTime(date.year, date.month, date.day);
    }

    widget.onDatesChanged(newDates);
  }

  int _getDaysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;
  int _getPrevMonthDays(DateTime date) =>
      DateTime(date.year, date.month, 0).day;
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _formatMonthYear(DateTime date) {
    final months = [
      "JANUARY",
      "FEBRUARY",
      "MARCH",
      "APRIL",
      "MAY",
      "JUNE",
      "JULY",
      "AUGUST",
      "SEPTEMBER",
      "OCTOBER",
      "NOVEMBER",
      "DECEMBER",
    ];
    return "${months[date.month - 1]} ${date.year}";
  }
}
