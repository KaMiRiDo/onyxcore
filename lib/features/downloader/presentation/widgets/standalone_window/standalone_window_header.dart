import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';

class StandaloneWindowHeader extends StatelessWidget {
  const StandaloneWindowHeader({
    super.key,
    required this.urlController,
    required this.urlFocusNode,
    required this.gradientController,
    required this.onFetch,
    required this.selectedEngine,
    required this.onEngineChanged,
  });

  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final AnimationController gradientController;
  final VoidCallback onFetch;
  final String selectedEngine;
  final ValueChanged<String> onEngineChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input Box
          Expanded(
            child: AnimatedBuilder(
              animation: gradientController,
              builder: (context, child) {
                final isFocused = urlFocusNode.hasFocus;
                return CustomPaint(
                  painter: isFocused
                      ? _GradientBorderPainter(gradientController.value)
                      : null,
                  child: Container(
                    height: 84, // Reduced to accommodate ~2 lines comfortably
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: !isFocused
                          ? Border.all(color: Colors.white10)
                          : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): onFetch,
                      },
                      child: TextField(
                        controller: urlController,
                        focusNode: urlFocusNode,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.firaCode(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'https://youtube.com/watch?v=...\nhttps://instagram.com/...',
                          hintStyle: GoogleFonts.firaCode(
                            color: Colors.white24,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // Action Column
          SizedBox(
            height: 84, // Reduced to match input box exactly
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fetch Button
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.magenta,
                          AppColors.violet,
                          AppColors.indigo,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      onPressed: onFetch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Fetch',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bottom Row (Dropdown + Settings)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      EngineSelectorDropdown(
                        selectedEngine: selectedEngine,
                        onChanged: onEngineChanged,
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Downloader Settings',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => SettingsDialog.show(
                              context,
                              section: 'Download Manager',
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: Colors.white70,
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
        ],
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter(
    this.animation, {
    this.radius = 12.0,
    this.strokeWidth = 1.5,
    this.colors = const [
      AppColors.magenta,
      AppColors.violet,
      AppColors.indigo,
      AppColors.magenta,
    ],
  });
  final double animation;
  final List<Color> colors;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: colors,
        transform: GradientRotation(animation * 2 * 3.141592653589793),
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter old) =>
      old.animation != animation ||
      old.colors != colors ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
