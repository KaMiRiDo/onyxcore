import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

class TaskProgressOverlay extends ConsumerWidget {
  const TaskProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      right: 24,
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        verticalDirection: VerticalDirection.up,
        children: tasks.map((task) => _buildTaskTile(task)).toList(),
      ),
    );
  }

  Widget _buildTaskTile(FileTask task) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceBase.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   _buildStatusIcon(task.status),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           task.title,
                           style: GoogleFonts.outfit(
                             color: Colors.white,
                             fontSize: 14,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         const SizedBox(height: 2),
                         Text(
                           task.subtitle,
                           style: GoogleFonts.manrope(
                             color: AppColors.textMuted,
                             fontSize: 11,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 12),
              if (task.status == FileTaskStatus.running) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: AppColors.cyan,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(task.progress * 100).toInt()}%',
                      style: GoogleFonts.manrope(
                        color: AppColors.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ] else if (task.status == FileTaskStatus.error)
                Text(
                  task.errorMessage ?? "An error occurred",
                  style: GoogleFonts.manrope(
                    color: AppColors.error,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(FileTaskStatus status) {
    switch (status) {
      case FileTaskStatus.running:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.cyan,
          ),
        );
      case FileTaskStatus.completed:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18);
      case FileTaskStatus.error:
        return const Icon(Icons.error_rounded, color: AppColors.error, size: 18);
    }
  }
}
