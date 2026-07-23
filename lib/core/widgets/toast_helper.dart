import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/app.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

class ToastHelper {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    bool isError = false,
  }) {
    final overlayState =
        Overlay.maybeOf(context) ?? appNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _currentEntry?.remove();
    _currentEntry = null;
    _timer?.cancel();

    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 60, // Positioned below the top bar
          right: 24, // Positioned near the background tasks icon
          child: Material(
            color: Colors.transparent,
            child: _ToastWidget(message: message, icon: icon, isError: isError),
          ),
        );
      },
    );

    overlayState.insert(_currentEntry!);

    _timer = Timer(const Duration(seconds: 4), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _ToastWidget extends StatefulWidget {

  const _ToastWidget({required this.message, required this.isError, this.icon});
  final String message;
  final IconData? icon;
  final bool isError;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // The notch pointing to the top bar icon
            Container(
              margin: const EdgeInsets.only(
                right: 136,
              ), // Align with the background tasks icon
              width: 12,
              height: 6,
              child: CustomPaint(
                painter: _TrianglePainter(
                  color: widget.isError
                      ? AppColors.error.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isError
                          ? AppColors.error.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: widget.isError
                              ? null
                              : AppTheme.primaryGradient.withOpacity(0.2),
                          color: widget.isError
                              ? AppColors.error.withValues(alpha: 0.2)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isError
                                ? AppColors.error.withValues(alpha: 0.4)
                                : AppColors.violet.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          widget.icon ??
                              (widget.isError
                                  ? Icons.error_outline_rounded
                                  : Icons.info_outline_rounded),
                          color: widget.isError
                              ? AppColors.error
                              : AppColors.violet,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.message,
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E1E).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Draw the border only on the two top lines
    final linePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);

    canvas.drawPath(linePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
