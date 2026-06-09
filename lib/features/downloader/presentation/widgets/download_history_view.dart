import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:path/path.dart' as p;

class DownloadHistoryView extends ConsumerStatefulWidget {
  const DownloadHistoryView({super.key});

  @override
  ConsumerState<DownloadHistoryView> createState() =>
      _DownloadHistoryViewState();
}

class _DownloadHistoryViewState extends ConsumerState<DownloadHistoryView> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showClearConfirm = false;
  bool _showDeleteSelectedConfirm = false;
  bool _showFilterBox = false;
  DownloadHistoryFilter _tempFilter = const DownloadHistoryFilter();
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
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(downloadHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(downloadHistorySelectionProvider);
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
                ref.read(downloadHistorySelectionProvider.notifier).clear();
              } else {
                ref.read(downloadsPanelViewProvider.notifier).state =
                    DownloadsPanelView.tasks;
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
    );
  }

  Widget _buildToolbar() {
    final historyNotifier = ref.read(downloadHistoryProvider.notifier);
    ref.watch(downloadHistoryProvider); // Trigger rebuilds when history changes
    final totalCount = historyNotifier.totalEntries;
    final totalSize = totalCount == 0
        ? '0 B'
        : StringUtils.formatBytes(historyNotifier.historyFileSize);
    final currentFilter = ref.watch(downloadHistoryFilterProvider);
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
            Icons.history_rounded,
            size: 12,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          Text(
            '$totalCount Tasks',
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
                ref.read(downloadHistoryFilterProvider.notifier).state =
                    const DownloadHistoryFilter();
                setState(() {
                  _tempFilter = const DownloadHistoryFilter();
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
            onTap: () {
              setState(() {
                _tempFilter = ref.read(downloadHistoryFilterProvider);
                _showFilterBox = !_showFilterBox;
              });
            },
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
    final availableDates = ref.watch(availableDownloadDatesProvider);
    return Positioned(
      top: 120, // Avoid overlap with toolbar
      right: 16,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _showFilterBox = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
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
                  _SimpleCalendar(
                    selectedDates: _tempFilter.selectedDates ?? {},
                    availableDates: availableDates,
                    onDatesChanged: (dates) => setState(
                      () => _tempFilter = _tempFilter.copyWith(
                        selectedDates: dates,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusDropdown(
                    _tempFilter.status ?? 'All',
                    (val) => setState(
                      () => _tempFilter = _tempFilter.copyWith(status: val),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _showFilterBox = false),
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
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
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
                                        .read(
                                          downloadHistoryFilterProvider
                                              .notifier,
                                        )
                                        .state =
                                    _tempFilter;
                                if (mounted)
                                  setState(() => _isFiltering = false);
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
      ),
    );
  }

  Widget _buildStatusDropdown(String value, Function(String?) onChanged) {
    final ops = ['All', 'Completed', 'Error', 'Cancelled'];
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (context) => ops.map((opt) {
        final isSelected = opt == value;
        return PopupMenuItem<String>(
          value: opt,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              opt,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 11),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white24,
            ),
          ],
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
    final history = ref.watch(filteredDownloadHistoryProvider);
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
    final filter = ref.watch(downloadHistoryFilterProvider);
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
                ? 'No downloads matching the filter'
                : 'No download history yet',
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
                ref.read(downloadHistoryFilterProvider.notifier).state =
                    const DownloadHistoryFilter();
                setState(() => _tempFilter = const DownloadHistoryFilter());
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
      onDismiss: () => setState(() => _showClearConfirm = false),
      child: _ClearHistoryDialog(
        onCancel: () => setState(() => _showClearConfirm = false),
        onConfirm: (filter) {
          if (filter == null) {
            ref.read(downloadHistoryProvider.notifier).clearAll();
          } else {
            ref.read(downloadHistoryProvider.notifier).deleteFiltered(filter);
          }
          setState(() => _showClearConfirm = false);
        },
      ),
    );
  }

  Widget _buildDeleteSelectedConfirmOverlay() {
    final selection = ref.read(downloadHistorySelectionProvider);
    return _buildBaseOverlay(
      onDismiss: () => setState(() => _showDeleteSelectedConfirm = false),
      child: _DeleteConfirmDialog(
        title: 'Delete Selected?',
        message: 'Remove ${selection.length} selected downloads from history?',
        confirmLabel: 'Delete',
        onConfirm: () {
          ref.read(downloadHistoryProvider.notifier).deleteEntries(selection);
          ref.read(downloadHistorySelectionProvider.notifier).clear();
          setState(() => _showDeleteSelectedConfirm = false);
        },
        onCancel: () => setState(() => _showDeleteSelectedConfirm = false),
      ),
    );
  }

  Widget _buildBaseOverlay({
    required Widget child,
    required VoidCallback onDismiss,
  }) {
    return Positioned.fill(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            onDismiss();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.black.withOpacity(0.4),
            child: Center(child: child),
          ),
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
    DownloadHistoryEntry entry,
    Set<String> selection,
  ) {
    final isSelected =
        selection.contains(entry.id) ||
        ref.watch(selectedDownloadHistoryIdProvider) == entry.id;
    final isSuccess = entry.statusName.toLowerCase() == 'completed';
    final isError = entry.statusName.toLowerCase() == 'error';
    final isCancelled = entry.statusName.toLowerCase() == 'cancelled';

    int itemCount = 0;
    for (final log in entry.logs) {
      if (log.startsWith('/') || log.startsWith(r'C:\')) {
        final ext = p.extension(log).toLowerCase();
        if (ext != '.json') {
          itemCount++;
        }
      }
    }

    Color statusColor = Colors.white54;
    if (isSuccess)
      statusColor = Colors.greenAccent;
    else if (isError)
      statusColor = Colors.redAccent;
    else if (isCancelled)
      statusColor = Colors.orangeAccent;

    IconData typeIcon = Icons.file_download_rounded;
    Color typeColor = Colors.white54;

    switch (entry.downloadType) {
      case 'video':
        typeIcon = Icons.videocam_rounded;
        typeColor = Colors.blueAccent;
        break;
      case 'image':
        typeIcon = Icons.image_rounded;
        typeColor = Colors.pinkAccent;
        break;
      case 'playlist':
        typeIcon = Icons.queue_music_rounded;
        typeColor = Colors.orangeAccent;
        break;
      case 'profile':
        typeIcon = Icons.person_outline_rounded;
        typeColor = Colors.purpleAccent;
        break;
    }

    if (isError) typeColor = Colors.redAccent;
    if (isCancelled) typeColor = Colors.orangeAccent;

    // Subtitle logic
    String subtitle = 'in ${p.basename(entry.destination)}';

    // We try to find the size from the current file on disk if it is a single file.
    // If it's a directory, this provides the folder name.

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

        final selection = ref.read(downloadHistorySelectionProvider);
        final hasSelection = selection.isNotEmpty;

        if (isShiftPressed) {
          final history = ref.read(filteredDownloadHistoryProvider);
          ref
              .read(downloadHistorySelectionProvider.notifier)
              .selectRange(history, entry.id);
        } else if (isControlPressed || hasSelection) {
          ref.read(downloadHistorySelectionProvider.notifier).toggle(entry.id);
          ref
              .read(downloadHistorySelectionProvider.notifier)
              .setAnchor(entry.id);
          if (ref.read(downloadHistorySelectionProvider).isEmpty) {
            ref.read(selectedDownloadHistoryIdProvider.notifier).state = null;
          }
        } else {
          ref.read(downloadHistorySelectionProvider.notifier).clear();
          ref
              .read(downloadHistorySelectionProvider.notifier)
              .setAnchor(entry.id);
          ref.read(selectedDownloadHistoryIdProvider.notifier).state = entry.id;
          ref.read(downloadsPanelViewProvider.notifier).state =
              DownloadsPanelView.historyDetail;
        }
      },
      onSecondaryTap: () {
        _focusNode.requestFocus();
        ref.read(downloadHistorySelectionProvider.notifier).toggle(entry.id);
        ref.read(downloadHistorySelectionProvider.notifier).setAnchor(entry.id);
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
                color: typeColor.withOpacity(isSelected ? 0.3 : 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                typeIcon,
                size: 16,
                color: isSelected ? Colors.white : typeColor.withOpacity(0.8),
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
                          entry.title,
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
                      // Item Count Pill
                      if (itemCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '$itemCount ITEM${itemCount > 1 ? 'S' : ''}',
                            style: GoogleFonts.manrope(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
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
                      Expanded(
                        child: Text(
                          subtitle,
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted.withOpacity(0.5),
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
}

class _ClearHistoryDialog extends ConsumerStatefulWidget {
  final VoidCallback onCancel;
  final Function(DownloadHistoryFilter?) onConfirm;

  const _ClearHistoryDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  ConsumerState<_ClearHistoryDialog> createState() =>
      _ClearHistoryDialogState();
}

class _ClearHistoryDialogState extends ConsumerState<_ClearHistoryDialog> {
  bool _customOps = false;
  DownloadHistoryFilter _filter = const DownloadHistoryFilter();

  @override
  Widget build(BuildContext context) {
    final availableDates = ref.watch(availableDownloadDatesProvider);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clear History',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _customOps
                ? 'Select what you want to remove'
                : 'Are you sure you want to clear all download history?',
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: () => setState(() => _customOps = !_customOps),
            child: Row(
              children: [
                Checkbox(
                  value: _customOps,
                  onChanged: (val) => setState(() => _customOps = val ?? false),
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
            _SimpleCalendar(
              selectedDates: _filter.selectedDates ?? {},
              availableDates: availableDates,
              onDatesChanged: (dates) => setState(
                () => _filter = _filter.copyWith(selectedDates: dates),
              ),
            ),
            const SizedBox(height: 16),
            PopupMenuButton<String>(
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              color: const Color(0xFF2A2A35),
              elevation: 24,
              tooltip: '',
              padding: EdgeInsets.zero,
              onSelected: (val) =>
                  setState(() => _filter = _filter.copyWith(status: val)),
              itemBuilder: (context) {
                final ops = ['All', 'Completed', 'Error', 'Cancelled'];
                return ops.map((opt) {
                  final isSelected = opt == (_filter.status ?? 'All');
                  return PopupMenuItem<String>(
                    value: opt,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withAlpha(15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        opt,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  );
                }).toList();
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _filter.status ?? 'All',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.white24,
                    ),
                  ],
                ),
              ),
            ),
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
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
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
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _customOps ? 'Delete' : 'Clear All',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
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
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.manrope(
              color: Colors.white70,
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
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
              icon: const Icon(
                Icons.chevron_left,
                size: 16,
                color: Colors.white54,
              ),
              onPressed: () => setState(
                () => _viewDate = DateTime(_viewDate.year, _viewDate.month - 1),
              ),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            Text(
              '${_viewDate.year}-${_viewDate.month.toString().padLeft(2, '0')}',
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.white54,
              ),
              onPressed: () => setState(
                () => _viewDate = DateTime(_viewDate.year, _viewDate.month + 1),
              ),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
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
            if (index < firstWeekday ||
                index >= firstWeekday + lastDayOfMonth.day) {
              return const SizedBox.shrink();
            }
            final date = DateTime(
              _viewDate.year,
              _viewDate.month,
              index - firstWeekday + 1,
            );
            final isAvailable = widget.availableDates.any(
              (d) => _isSameDay(d, date),
            );
            final isSelected = widget.selectedDates.any(
              (d) => _isSameDay(d, date),
            );

            return InkWell(
              onTap: isAvailable
                  ? () {
                      final newDates = Set.of(widget.selectedDates);
                      if (isSelected) {
                        newDates.removeWhere((d) => _isSameDay(d, date));
                      } else {
                        newDates.add(date);
                      }
                      widget.onDatesChanged(newDates);
                    }
                  : null,
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
                    color: isSelected
                        ? Colors.white
                        : (isAvailable ? Colors.white70 : Colors.white24),
                    fontWeight: isSelected
                        ? FontWeight.bold
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
}
