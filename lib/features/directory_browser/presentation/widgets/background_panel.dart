import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_tile.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_detail_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';

/// Slide-in panel from the right showing background processes.
///
/// Sits below the toolbar and extends to the bottom of the window.
/// Does not affect sidebar, breadcrumbs, or any other functionality.
class BackgroundPanel extends ConsumerWidget {
  const BackgroundPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(backgroundPanelOpenProvider);
    final currentView = ref.watch(backgroundPanelViewProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 30% of the total screen width (not just the available constraints)
        final screenWidth = MediaQuery.of(context).size.width;
        final panelWidth = screenWidth * 0.25;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: isOpen ? panelWidth : 0,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            border: isOpen
                ? Border(
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                  )
                : null,
            boxShadow: isOpen
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(-6, 0),
                    ),
                  ]
                : null,
          ),
          child: isOpen
              ? OverflowBox(
                  minWidth: panelWidth,
                  maxWidth: panelWidth,
                  alignment: Alignment.topLeft,
                  child: _buildCurrentView(currentView, ref, context),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildCurrentView(
      BackgroundPanelView view, WidgetRef ref, BuildContext context) {
    switch (view) {
      case BackgroundPanelView.tasks:
        return _TasksView();
      case BackgroundPanelView.history:
        return const TaskHistoryView();
      case BackgroundPanelView.historyDetail:
        return const TaskHistoryDetailView();
    }
  }
}

/// The main tasks list view within the panel.
class _TasksView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);
    final hasActiveTasks = ref.read(taskProvider.notifier).hasActiveTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    'Background Processes',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              // History button
              Tooltip(
                message: 'History',
                waitDuration: const Duration(milliseconds: 500),
                child: InkWell(
                  onTap: () {
                    ref.read(backgroundPanelViewProvider.notifier).state =
                        BackgroundPanelView.history;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              // Minimize button
              Tooltip(
                message: 'Minimize',
                waitDuration: const Duration(milliseconds: 500),
                child: InkWell(
                  onTap: () {
                    ref.read(backgroundPanelOpenProvider.notifier).state = false;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cancel All (only if there are active tasks)
        if (hasActiveTasks)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            child: InkWell(
              onTap: () => _confirmCancelAll(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      size: 14,
                      color: AppColors.error.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cancel All',
                      style: GoogleFonts.manrope(
                        color: AppColors.error.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Divider(color: Colors.white10, height: 1),
        // Task list
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 40,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No active tasks',
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return TaskTile(task: tasks[index]);
                  },
                ),
        ),
      ],
    );
  }

  void _confirmCancelAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmDialog(
        title: 'Cancel All Tasks',
        message:
            'This will cancel all running and pending tasks. Partially processed items will remain in their current state.',
        confirmText: 'Cancel All',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      ref.read(taskProvider.notifier).cancelAllTasks();
    }
  }
}
