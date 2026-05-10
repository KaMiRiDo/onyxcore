import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/video_marker.dart';
import '../providers/video_markers_provider.dart';

class TimelineMarker extends ConsumerStatefulWidget {
  final VideoMarker marker;
  final Duration totalDuration;
  final double sliderWidth;
  final String videoPath;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Function(bool) onHoverChanged;
  final Function(bool) onMenuVisibilityChanged;
  final ValueNotifier<double?> hoverXNotifier;

  const TimelineMarker({
    required this.marker,
    required this.totalDuration,
    required this.sliderWidth,
    required this.videoPath,
    required this.onTap,
    required this.onEdit,
    required this.onHoverChanged,
    required this.onMenuVisibilityChanged,
    required this.hoverXNotifier,
    super.key,
  });

  @override
  ConsumerState<TimelineMarker> createState() => _TimelineMarkerState();
}

class _TimelineMarkerState extends ConsumerState<TimelineMarker> {
  bool _isHovered = false;
  bool _isMenuOpen = false;

  bool get _isSingleEmoji {
    final content = widget.marker.content.trim();
    if (content.isEmpty) return false;
    
    final chars = content.characters;
    if (chars.length != 1) return false;
    
    final char = chars.first;
    return !RegExp(r'^[a-zA-Z0-9\s]$').hasMatch(char);
  }


  @override
  Widget build(BuildContext context) {
    if (widget.totalDuration <= Duration.zero || widget.sliderWidth <= 0) {
      return const SizedBox.shrink();
    }

    final fraction = (widget.marker.timestamp.inMilliseconds / widget.totalDuration.inMilliseconds).clamp(0.0, 1.0);
    final left = fraction * widget.sliderWidth;
    
    final isSingleEmoji = _isSingleEmoji;
    final displayEmoji = isSingleEmoji ? widget.marker.content.trim() : '📍';

    return Positioned(
      left: left - 80, // Center of 160px width
      bottom: 32 - 59, // Center of 160px height (aligned with marker center)
      width: 160,
      height: 160,
      child: TapRegion(
        onTapOutside: (_) {
          if (_isMenuOpen) {
            setState(() => _isMenuOpen = false);
            widget.onMenuVisibilityChanged(false);
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Radial Menu Buttons
            if (_isMenuOpen) ...[
              // Edit (Top)
              _PositionedMenuButton(
                top: 20, // Relative to 160px center
                icon: Icons.edit_rounded,
                color: Colors.white70,
                onTap: () {
                  widget.onEdit();
                  setState(() => _isMenuOpen = false);
                  widget.onMenuVisibilityChanged(false);
                },
              ),
              // Delete (Left)
              _PositionedMenuButton(
                left: 20,
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent,
                onTap: () {
                  ref.read(markerActionsProvider).deleteMarker(widget.videoPath, widget.marker.id);
                  setState(() => _isMenuOpen = false);
                  widget.onMenuVisibilityChanged(false);
                },
              ),
              // Delete All (Right)
              _PositionedMenuButton(
                right: 20,
                icon: Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                onTap: () {
                  ref.read(markerActionsProvider).deleteAllMarkers(widget.videoPath);
                  setState(() => _isMenuOpen = false);
                  widget.onMenuVisibilityChanged(false);
                },
              ),
            ],

            MouseRegion(
              onEnter: (_) {
                setState(() => _isHovered = true);
                widget.onHoverChanged(true);
                widget.hoverXNotifier.value = null;
              },
              onExit: (_) {
                setState(() => _isHovered = false);
                widget.onHoverChanged(false);
              },
              onHover: (_) {
                widget.hoverXNotifier.value = null;
              },
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (_isMenuOpen) {
                    setState(() => _isMenuOpen = false);
                    widget.onMenuVisibilityChanged(false);
                  } else {
                    widget.onTap();
                  }
                },
                onSecondaryTap: () {
                  setState(() => _isMenuOpen = !_isMenuOpen);
                  widget.onMenuVisibilityChanged(_isMenuOpen);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: _isHovered ? 1.1 : 1.0,
                  child: CustomPaint(
                    painter: MarkerShadowPainter(),
                    child: ClipPath(
                      clipper: MarkerShapeClipper(),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: 36,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(_isHovered ? 0.15 : 0.08),
                            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                          ),
                          alignment: const Alignment(0, -0.3),
                          child: Text(
                            displayEmoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
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

class _PositionedMenuButton extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PositionedMenuButton({
    this.top,
    this.left,
    this.right,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Center(
                        child: Icon(icon, color: color, size: 16),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MarkerShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const r = 10.0; // Corner radius
    const nh = 7.0; // Notch height
    const nw = 12.0; // Notch width
    final w = size.width;
    final h = size.height - nh;

    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    
    // Bottom edge with notch
    path.lineTo(w / 2 + nw / 2, h);
    path.lineTo(w / 2, size.height);
    path.lineTo(w / 2 - nw / 2, h);
    
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldDelegate) => false;
}

class MarkerShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = MarkerShapeClipper().getClip(size);
    canvas.drawShadow(path, Colors.black, 4, true);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
