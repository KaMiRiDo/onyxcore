import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_tile.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_detail_view.dart';

/// Slide-in panel from the right showing background processes.
///
/// Sits below the toolbar and extends to the bottom of the window.
/// Does not affect sidebar, breadcrumbs, or any other functionality.
class BackgroundPanel extends ConsumerWidget {
  const BackgroundPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(backgroundPanelViewProvider);
    return _buildCurrentView(currentView, ref, context);
  }

  Widget _buildCurrentView(
    BackgroundPanelView view,
    WidgetRef ref,
    BuildContext context,
  ) {
    switch (view) {
      case BackgroundPanelView.tasks:
        return const _TasksView();
      case BackgroundPanelView.history:
        return const TaskHistoryView();
      case BackgroundPanelView.historyDetail:
        return const TaskHistoryDetailView();
    }
  }
}

/// The main tasks list view within the panel.
class _TasksView extends ConsumerStatefulWidget {
  const _TasksView();

  @override
  ConsumerState<_TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends ConsumerState<_TasksView>
    with SingleTickerProviderStateMixin {
  bool _showCancelAllConfirm = false;
  AnimationController? _refreshControllerInternal;
  AnimationController get _refreshController {
    _refreshControllerInternal ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    return _refreshControllerInternal!;
  }

  bool _isRefreshing = false;

  @override
  void dispose() {
    _refreshControllerInternal?.dispose();
    super.dispose();
  }

  void _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshController.repeat();

    ref.read(taskProvider.notifier).refreshTasks();

    // Hold the effect for a bit to make it visible
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      _refreshController.stop();
      _refreshController.reset();
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final notifier = ref.read(taskProvider.notifier);
    final hasActiveTasks = notifier.hasActiveTasks;

    // Automatically move cancelled tasks to history and remove them from active list
    ref.listen<List<FileTask>>(taskProvider, (prev, next) {
      for (final task in next) {
        if (task.status == FileTaskStatus.cancelled) {
          ref.read(taskHistoryProvider.notifier).addEntry(task);
          ref.read(taskProvider.notifier).removeTask(task.id);
        }
      }
    });

    return Stack(
      children: [
        Column(
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
                  // Refresh button
                  Tooltip(
                    message: 'Refresh Tasks',
                    waitDuration: const Duration(milliseconds: 500),
                    child: InkWell(
                      onTap: _handleRefresh,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: RotationTransition(
                          turns: _refreshController,
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: _isRefreshing
                                ? AppColors.violet
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // History button (Text)
                  TextButton(
                    onPressed: () {
                      ref.read(backgroundPanelViewProvider.notifier).state =
                          BackgroundPanelView.history;
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'History',
                      style: GoogleFonts.manrope(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            // Task list
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isRefreshing ? 0.6 : 1.0,
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
            ),
            // Footer with Cancel All button
            if (hasActiveTasks)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  border: const Border(
                    top: BorderSide(color: Colors.white10, width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _showCancelAllConfirm = true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error.withOpacity(0.1),
                      foregroundColor: AppColors.error,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(
                      'Cancel All Tasks',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Local Confirmation Overlay
        if (_showCancelAllConfirm)
          Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.7),
              child: InkWell(
                onTap: () => setState(() => _showCancelAllConfirm = false),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                child: Center(
                  child: InkWell(
                    onTap: () {}, // Prevent tap from bubbling up
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    child: Container(
                      width: 260,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
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
                              color: AppColors.error.withOpacity(0.1),
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
                            'Cancel All Tasks?',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This will stop all running and pending operations immediately.',
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
                                  onPressed: () {
                                    setState(
                                      () => _showCancelAllConfirm = false,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'No, Keep',
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
                                  onPressed: () {
                                    ref
                                        .read(taskProvider.notifier)
                                        .cancelAllTasks();
                                    setState(
                                      () => _showCancelAllConfirm = false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Yes, Cancel',
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
          ),
      ],
    );
  }
}
