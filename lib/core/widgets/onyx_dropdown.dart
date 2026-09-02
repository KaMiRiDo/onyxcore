import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnyxDropdown<T> extends StatelessWidget {
  const OnyxDropdown({
    required this.value, required this.options, required this.onChanged, super.key,
    this.minWidth = 100,
    this.isExpanded = false,
    this.disabledOptions = const {},
  });

  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;
  final double minWidth;
  final bool isExpanded;
  final Set<T> disabledOptions;

  @override
  Widget build(BuildContext context) {
    final selectedOption = options.firstWhere(
      (o) => o.key == value,
      orElse: () => options.first,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final popupMinWidth = isExpanded && constraints.maxWidth != double.infinity
            ? constraints.maxWidth
            : minWidth;

        return PopupMenuButton<T>(
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          color: const Color(0xFF161616),
          elevation: 24,
          onSelected: onChanged,
          tooltip: '',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: popupMinWidth),
          itemBuilder: (context) => options.map((opt) {
            final isSelected = opt.key == value;
            final isDisabled = disabledOptions.contains(opt.key);
            
            return PopupMenuItem<T>(
              value: opt.key,
              height: 38,
              enabled: !isDisabled,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt.value,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isDisabled
                        ? Colors.white.withValues(alpha: 0.24)
                        : (isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            );
      }).toList(),
      child: Container(
        width: isExpanded ? double.infinity : null,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                selectedOption.value,
                style: GoogleFonts.manrope(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isExpanded) const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
        ),
      );
      },
    );
  }
}
