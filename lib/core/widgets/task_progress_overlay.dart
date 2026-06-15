import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

class TaskProgressButton extends ConsumerWidget {
  const TaskProgressButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);

    // Always reserve exact IconButton space to prevent UI shifts
    if (tasks.isEmpty) {
      return const IconButton(
        onPressed: null,
        icon: SizedBox(width: 20, height: 20),
      );
    }

    final runningTasks = tasks
        .where((t) => t.status == FileTaskStatus.running)
        .toList();
    final errorTasks = tasks
        .where((t) => t.status == FileTaskStatus.error)
        .toList();

    Color bgColor = Colors.transparent;
    Widget content;

    if (runningTasks.isNotEmpty) {
      double totalProgress = 0.0;
      for (final t in runningTasks) {
        totalProgress += t.progress;
      }
      final avgProgress = totalProgress / runningTasks.length;

      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: avgProgress > 0 ? avgProgress : null,
          strokeWidth: 10, // Half of 20 for pie chart effect
          color: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.2),
        ),
      );
    } else if (errorTasks.isNotEmpty) {
      bgColor = AppColors.error;
      content = const Icon(
        Icons.error_outline_rounded,
        color: Colors.white,
        size: 14,
      );
    } else {
      bgColor = const Color(0xFF1B5E20); // Even darker green
      content = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
    }

    return IconButton(
      onPressed: () {}, // Future: Open task list
      tooltip: 'Background Tasks',
      icon: Container(
        width: 20,
        height: 20,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: bgColor != Colors.transparent
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: content,
        ),
      ),
    );
  }
}
