import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';

/// Progress view displaying real-time pipeline status and a cancel action.
class CompareProgressView extends StatelessWidget {
  const CompareProgressView({
    required this.progress,
    required this.onCancel,
    super.key,
  });

  final ComparisonProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final double? progressValue;
    if (progress.totalFiles > 0) {
      progressValue = (progress.processedFiles / progress.totalFiles).clamp(
        0.0,
        1.0,
      );
    } else {
      progressValue = null; // Indeterminate
    }

    final percentageText = progressValue != null
        ? '${(progressValue * 100).toInt()}%'
        : '';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.violet),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Comparing Folders...',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusDescription(progress.status),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.violet,
                ),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.processedFiles} / ${progress.totalFiles}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  if (percentageText.isNotEmpty)
                    Text(
                      percentageText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusDescription(ComparisonStatus status) {
    switch (status) {
      case ComparisonStatus.idle:
        return 'Initializing...';
      case ComparisonStatus.discovering:
        return 'Stage 1: Discovering files... (discovering)';
      case ComparisonStatus.clustering:
        return 'Stage 1: Clustering candidates... (clustering)';
      case ComparisonStatus.fingerprinting:
        return 'Stage 2: Generating fingerprints... (fingerprinting)';
      case ComparisonStatus.comparing:
        return 'Stage 2: Comparing candidates... (comparing)';
      case ComparisonStatus.completed:
        return 'Comparison complete.';
      case ComparisonStatus.cancelled:
        return 'Comparison cancelled.';
      case ComparisonStatus.failed:
        return 'Comparison failed.';
    }
  }
}
