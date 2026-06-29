import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

class SortOverlay {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required Offset buttonPosition,
    required Size buttonSize,
    required SortOption currentOption,
    required Function(SortOption) onSelected,
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _SortOverlayWidget(
        buttonPosition: buttonPosition,
        buttonSize: buttonSize,
        currentOption: currentOption,
        onSelected: (option) {
          hide();
          onSelected(option);
        },
        onClose: hide,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _SortOverlayWidget extends StatelessWidget {
  final Offset buttonPosition;
  final Size buttonSize;
  final SortOption currentOption;
  final Function(SortOption) onSelected;
  final VoidCallback onClose;

  const _SortOverlayWidget({
    required this.buttonPosition,
    required this.buttonSize,
    required this.currentOption,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const width = 240.0;
    final height = SortOption.values.length * 44.0 + 32.0;

    // Align left edge of popup with the button so it opens towards the right
    double left = buttonPosition.dx + 8;
    // Show directly below the button
    double top = buttonPosition.dy + buttonSize.height + 8;

    if (left < 16) left = 16;
    if (left + width > screenSize.width - 16)
      left = screenSize.width - width - 16;

    if (top + height > screenSize.height - 16) {
      top = buttonPosition.dy - height - 8;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: SortOption.values.map((option) {
                        final isSelected = option == currentOption;
                        return _buildOption(option, isSelected);
                      }).toList(),
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

  Widget _buildOption(SortOption option, bool isSelected) {
    return InkWell(
      onTap: () => onSelected(option),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(
              _getIcon(option),
              size: 18,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                style: GoogleFonts.manrope(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            _buildRadioButton(isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioButton(bool isSelected) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.white24,
          width: 1.5,
        ),
        gradient: isSelected ? AppTheme.primaryGradient : null,
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  IconData _getIcon(SortOption option) {
    switch (option) {
      case SortOption.aToZ:
        return Icons.sort_by_alpha_rounded;
      case SortOption.zToA:
        return Icons.sort_by_alpha_rounded;
      case SortOption.firstModified:
        return Icons.history_rounded;
      case SortOption.lastModified:
        return Icons.update_rounded;
      case SortOption.sizeSmallToLarge:
        return Icons.unfold_more_rounded;
      case SortOption.sizeLargeToSmall:
        return Icons.unfold_less_rounded;
      case SortOption.filesFirst:
        return Icons.insert_drive_file_outlined;
    }
  }
}
