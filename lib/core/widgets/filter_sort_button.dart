// ignore_for_file: unawaited_futures
import 'package:flutter/material.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

/// A floating action-style button rendered in the bottom-right corner of a
/// media player or viewer that triggers the sort/filter operation.
///
/// The button is only visible when the HUD is visible (controlled by the
/// parent's [hudVisible] parameter).
class FilterSortButton extends StatelessWidget {
  const FilterSortButton({
    required this.onPressed,
    this.hudVisible = true,
    super.key,
  });

  /// Callback invoked when the user taps the filter button.
  final VoidCallback onPressed;

  /// Whether the parent HUD is currently visible. When false the button fades out.
  final bool hudVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: hudVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !hudVisible,
        child: Tooltip(
          message: 'Move to Filtered folder (Alt+S)',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
