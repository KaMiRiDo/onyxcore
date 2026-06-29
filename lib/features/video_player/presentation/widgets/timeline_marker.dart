import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
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
  final void Function(bool) onHoverChanged;
  final void Function(bool) onMenuVisibilityChanged;
  final ValueNotifier<double?> hoverXNotifier;
  final bool isMarkerEditorActive;

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
    required this.isMarkerEditorActive,
    super.key,
  });

  @override
  ConsumerState<TimelineMarker> createState() => _TimelineMarkerState();
}

class _TimelineMarkerState extends ConsumerState<TimelineMarker> {
  bool _isHovered = false;
  bool _isMenuOpen = false;
  bool _isDeletePromptVisible = false; // Kept for potential future use
  Uint8List? _cachedImageBytes;
  bool _isBase64 = false;
  FocusNode? _deleteButtonFocusNode;
  final GlobalKey _markerIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _processIcon();
  }

  @override
  void dispose() {
    _deleteButtonFocusNode?.dispose();
    super.dispose();
  }

  void _processIcon() {
    final displayEmoji = widget.marker.icon;
    _isBase64 = displayEmoji.startsWith('B64:');
    if (_isBase64) {
      try {
        _cachedImageBytes = base64Decode(displayEmoji.substring(4));
      } catch (_) {
        _cachedImageBytes = null;
      }
    } else {
      _cachedImageBytes = null;
    }
  }

  @override
  void didUpdateWidget(TimelineMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.marker.icon != oldWidget.marker.icon) {
      _processIcon();
    }
    if (widget.isMarkerEditorActive && !oldWidget.isMarkerEditorActive) {
      if (_isMenuOpen || _isDeletePromptVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isMenuOpen = false;
              _isDeletePromptVisible = false;
            });
            widget.onMenuVisibilityChanged(false);
          }
        });
      }
    }
  }

  void _showDeleteAllDialog(BuildContext context) {
    // Keep HUD visible while dialog is open
    widget.onMenuVisibilityChanged(true);

    // Get marker icon's exact global position
    final iconBox =
        _markerIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (iconBox == null) return;
    final iconPos = iconBox.localToGlobal(Offset.zero);
    final iconSize = iconBox.size;
    final screenSize = MediaQuery.of(context).size;

    // Dialog dimensions
    const dialogWidth = 220.0;
    const dialogHeight = 80.0;

    // Get the parent timeline area bounds for horizontal clamping
    final parentBox = context.findRenderObject()?.parent as RenderBox?;
    final parentPos = parentBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    // Find the video player's global boundaries to ensure precise clamping from the video edge
    RenderBox? playerBox;
    context.visitAncestorElements((element) {
      if (element.renderObject is RenderBox) {
        final box = element.renderObject as RenderBox;
        // The video player root has a width matching widget.sliderWidth
        if (box.size.width == widget.sliderWidth) {
          playerBox = box;
          return false;
        }
      }
      return true;
    });

    final playerGlobalX =
        playerBox?.localToGlobal(Offset.zero).dx ?? parentPos.dx;
    final playerWidth = widget.sliderWidth;

    // Center dialog horizontally on the marker icon, with edge clamping to video bounds (16px margin)
    final iconCenterX = iconPos.dx + iconSize.width / 2;
    final dialogLeft = (iconCenterX - dialogWidth / 2).clamp(
      playerGlobalX + 16,
      playerGlobalX + playerWidth - dialogWidth - 16,
    );
    // Place dialog bottom just above the marker icon top, with a small gap
    // Also clamp so dialog top doesn't go above the screen (at least 30px margin)
    final dialogBottom = (screenSize.height - iconPos.dy + 8).clamp(
      0.0,
      screenSize.height - dialogHeight - 30,
    );

    showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Delete All',
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SizedBox.expand(
          child: Stack(
            children: [
              // Invisible barrier to catch outside taps
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(false),
                ),
              ),
              // Dialog positioned above marker
              Positioned(
                left: dialogLeft,
                bottom: dialogBottom,
                width: dialogWidth,
                child: FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: dialogWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Delete all markers?',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(false),
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withOpacity(0.08),
                                          foregroundColor: Colors.white70,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(true),
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.redAccent
                                              .withOpacity(0.2),
                                          foregroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
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
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    ).then((confirmed) async {
      // Dismiss HUD hold
      if (mounted) widget.onMenuVisibilityChanged(false);
      if (confirmed == true && mounted) {
        await ref
            .read(markerActionsProvider)
            .deleteAllMarkers(widget.videoPath);
      }
    });
  }

  void _showRadialMenu(BuildContext context) {
    // Keep HUD visible
    widget.onMenuVisibilityChanged(true);

    final iconBox =
        _markerIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (iconBox == null) return;
    final iconPos = iconBox.localToGlobal(Offset.zero);
    final iconSize = iconBox.size;

    showGeneralDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Radial Menu',
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenSize = MediaQuery.of(dialogContext).size;

        // --- Smart No-Overlap Positioning Logic ---
        final buttonSize = 40.0;
        const offset = 44.0;
        final idealCenterX = iconPos.dx + iconSize.width / 2;
        final idealCenterY = iconPos.dy + iconSize.height / 2;

        // 1. Initial ideal positions centered on marker
        double editX = idealCenterX - buttonSize / 2;
        double deleteX = idealCenterX - offset - buttonSize / 2;
        double deleteAllX = idealCenterX + offset - buttonSize / 2;

        // 2. Clamp individually to screen edges (with 8px margin)
        final leftBound = 8.0;
        final rightBound = screenSize.width - buttonSize - 8.0;

        deleteX = deleteX.clamp(leftBound, rightBound);
        editX = editX.clamp(leftBound, rightBound);
        deleteAllX = deleteAllX.clamp(leftBound, rightBound);

        // 3. Prevent overlaps: Ensure minimum 4px gap between buttons
        const minGap = 4.0;
        // Check Delete vs Edit
        if (editX < deleteX + buttonSize + minGap) {
          editX = deleteX + buttonSize + minGap;
        }
        // Check Edit vs Delete All
        if (deleteAllX < editX + buttonSize + minGap) {
          deleteAllX = editX + buttonSize + minGap;
        }

        // 4. Final safety check: if the rightmost button was pushed off-screen,
        // push everything back to the left
        if (deleteAllX > rightBound) {
          deleteAllX = rightBound;
          if (editX > deleteAllX - buttonSize - minGap) {
            editX = deleteAllX - buttonSize - minGap;
          }
          if (deleteX > editX - buttonSize - minGap) {
            deleteX = editX - buttonSize - minGap;
          }
        }
        // --- End Positioning Logic ---

        return SizedBox.expand(
          child: Stack(
            children: [
              // Outside tap dismisses
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(null),
                ),
              ),
              // Edit (Top)
              _buildOverlayMenuButton(
                dialogContext: dialogContext,
                x: editX,
                y: (idealCenterY - offset - buttonSize / 2).clamp(
                  8.0,
                  screenSize.height - buttonSize - 8,
                ),
                icon: Icons.edit_rounded,
                color: Colors.white,
                result: 'edit',
                delay: 0,
                animation: animation,
              ),
              // Delete (Left)
              _buildOverlayMenuButton(
                dialogContext: dialogContext,
                x: deleteX,
                y: (idealCenterY - buttonSize / 2).clamp(
                  8.0,
                  screenSize.height - buttonSize - 8,
                ),
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent,
                result: 'delete',
                delay: 50,
                animation: animation,
              ),
              // Delete All (Right)
              _buildOverlayMenuButton(
                dialogContext: dialogContext,
                x: deleteAllX,
                y: (idealCenterY - buttonSize / 2).clamp(
                  8.0,
                  screenSize.height - buttonSize - 8,
                ),
                icon: Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                result: 'deleteAll',
                delay: 100,
                animation: animation,
              ),
            ],
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    ).then((result) {
      if (!mounted) return;
      setState(() => _isMenuOpen = false);
      widget.onMenuVisibilityChanged(false);

      switch (result) {
        case 'edit':
          widget.onEdit();
        case 'delete':
          ref
              .read(markerActionsProvider)
              .deleteMarker(widget.videoPath, widget.marker.id);
        case 'deleteAll':
          // Slight delay so dialog closes first
          Future.microtask(() {
            if (mounted) _showDeleteAllDialog(context);
          });
      }
    });
  }

  Widget _buildOverlayMenuButton({
    required BuildContext dialogContext,
    required double x,
    required double y,
    required IconData icon,
    required Color color,
    required String result,
    required Animation<double> animation,
    int delay = 0,
  }) {
    return Positioned(
      left: x,
      top: y,
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Interval(
                (delay / 300).clamp(0.0, 1.0),
                1.0,
                curve: Curves.easeOutBack,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(result),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.9),
                    border: Border.all(color: color.withOpacity(0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalDuration <= Duration.zero || widget.sliderWidth <= 0) {
      return const SizedBox.shrink();
    }

    final fraction =
        (widget.marker.timestamp.inMilliseconds /
                widget.totalDuration.inMilliseconds)
            .clamp(0.0, 1.0);
    final left = fraction * widget.sliderWidth;
    final displayEmoji = widget.marker.icon;

    if (displayEmoji.startsWith('B64:') && _cachedImageBytes == null) {
      _processIcon();
    }

    return Positioned(
      left: left - 150, // Center of 300px width
      bottom: -97, // Center of 300px height (aligned with old center 53)
      width: 300,
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Text Tooltip on Hover
          if (_isHovered && !_isMenuOpen && widget.marker.content.isNotEmpty)
            Positioned(
              bottom: 185, // Above the marker icon
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          widget.marker.content,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

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
                _showRadialMenu(context);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: _isHovered ? 1.1 : 1.0,
                child: CustomPaint(
                  key: _markerIconKey,
                  painter: MarkerShadowPainter(),
                  child: ClipPath(
                    clipper: MarkerShapeClipper(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 36,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            _isHovered ? 0.15 : 0.08,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        alignment: const Alignment(0, -0.3),
                        child: _isBase64 && _cachedImageBytes != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    _cachedImageBytes!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    gaplessPlayback:
                                        true, // Prevents flickering on minor rebuilds
                                  ),
                                ),
                              )
                            : Text(
                                displayEmoji,
                                style: const TextStyle(fontSize: 22),
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
