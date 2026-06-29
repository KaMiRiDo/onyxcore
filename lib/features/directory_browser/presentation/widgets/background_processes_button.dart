import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Pie-chart style progress button for background processes.
///
/// States:
/// - **Idle**: Outlined circle (always visible)
/// - **Active**: Pie-chart arc filling proportional to total progress
/// - **Completed**: Green checkmark (resets after 3s)
/// - **Error**: Red error icon (persists until user opens panel)
class BackgroundProcessesButton extends ConsumerStatefulWidget {
  const BackgroundProcessesButton({super.key});

  @override
  ConsumerState<BackgroundProcessesButton> createState() =>
      _BackgroundProcessesButtonState();
}

class _BackgroundProcessesButtonState
    extends ConsumerState<BackgroundProcessesButton>
    with SingleTickerProviderStateMixin {
  bool _showingCompletionTick = false;
  bool _hadErrorSinceLastOpen = false;
  bool _callbackRegistered = false;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final isOpen = ref.watch(backgroundPanelOpenProvider);
    final notifier = ref.read(taskProvider.notifier);

    final hasRunning =
        notifier.runningTasks.isNotEmpty || notifier.pendingTasks.isNotEmpty;
    final hasErrors = notifier.hasErrors;
    final totalProgress = notifier.totalProgress;

    // Sync concurrency limit from settings
    final settingsAsync = ref.watch(settingsProvider);
    settingsAsync.whenData((settings) {
      if (notifier.maxConcurrent != settings.maxConcurrentTasks) {
        notifier.maxConcurrent = settings.maxConcurrentTasks;
      }
    });

    // Track errors
    if (hasErrors) {
      _hadErrorSinceLastOpen = true;
    }

    // Clear error flag when panel is opened
    if (isOpen && _hadErrorSinceLastOpen) {
      _hadErrorSinceLastOpen = false;
    }

    // Detect transition to all-completed
    ref.listen(taskProvider, (prev, next) {
      final prevHadRunning = (prev ?? []).any(
        (t) =>
            t.status == FileTaskStatus.running ||
            t.status == FileTaskStatus.pending,
      );
      final nowHasRunning = next.any(
        (t) =>
            t.status == FileTaskStatus.running ||
            t.status == FileTaskStatus.pending,
      );
      final nowHasCompleted = next.any(
        (t) => t.status == FileTaskStatus.completed,
      );

      if (prevHadRunning &&
          !nowHasRunning &&
          nowHasCompleted &&
          !ref.read(taskProvider.notifier).hasErrors) {
        setState(() => _showingCompletionTick = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showingCompletionTick = false);
          }
        });
      }
    });

    return Tooltip(
      message: 'Background Processes',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () {
          ref.read(backgroundPanelOpenProvider.notifier).state = !isOpen;
          if (!isOpen) {
            ref.read(downloadsPanelOpenProvider.notifier).state = false;
            // Reset to tasks view when opening
            ref.read(backgroundPanelViewProvider.notifier).state =
                BackgroundPanelView.tasks;
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: _buildButtonContent(
              hasRunning: hasRunning,
              hasErrors: _hadErrorSinceLastOpen,
              totalProgress: totalProgress,
              isOpen: isOpen,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent({
    required bool hasRunning,
    required bool hasErrors,
    required double totalProgress,
    required bool isOpen,
  }) {
    const size = 22.0;

    // Error state: red icon, persists
    if (hasErrors && !isOpen) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.error.withOpacity(0.15),
          border: Border.all(
            color: AppColors.error.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 14,
          ),
        ),
      );
    }

    // Completion tick state: green check, auto-resets
    if (_showingCompletionTick) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withOpacity(0.15),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 14,
                ),
              ),
            ),
          );
        },
      );
    }

    // Active state: pie chart progress
    if (hasRunning) {
      return CustomPaint(
        size: const Size(size, size),
        painter: _PieProgressPainter(
          progress: totalProgress.clamp(
            0.01,
            1.0,
          ), // Show at least a sliver if running
          strokeColor: AppColors.violet,
          backgroundColor: Colors.white.withOpacity(0.05),
        ),
      );
    }

    // Idle state: outlined circle
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isOpen
              ? AppColors.violet.withOpacity(0.6)
              : Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
      ),
    );
  }
}

/// Custom painter that draws a filled pie-chart arc.
class _PieProgressPainter extends CustomPainter {
  final double progress;
  final Color strokeColor;
  final Color backgroundColor;

  _PieProgressPainter({
    required this.progress,
    required this.strokeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = strokeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, outlinePaint);

    // Progress arc (pie slice)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = strokeColor.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from 12 o'clock
        sweepAngle,
        true, // Use center (pie slice)
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PieProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
