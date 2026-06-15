import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:path/path.dart' as p;

enum RenameMode { prefix, constant }

class RenamePopover {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required Offset position,
    required List<String> paths,
    required List<String> existingNames,
    required Function(dynamic) onRename,
    VoidCallback? onClose,
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _RenamePopoverWidget(
        position: position,
        paths: paths,
        existingNames: existingNames,
        onRename: (result) {
          hide();
          onRename(result);
        },
        onClose: () {
          hide();
          if (onClose != null) onClose();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _RenamePopoverWidget extends StatefulWidget {
  final Offset position;
  final List<String> paths;
  final List<String> existingNames;
  final Function(dynamic) onRename;
  final VoidCallback onClose;

  const _RenamePopoverWidget({
    required this.position,
    required this.paths,
    required this.existingNames,
    required this.onRename,
    required this.onClose,
  });

  @override
  State<_RenamePopoverWidget> createState() => _RenamePopoverWidgetState();
}

class _RenamePopoverWidgetState extends State<_RenamePopoverWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  RenameMode _bulkMode = RenameMode.prefix;
  bool _hasConflict = false;

  @override
  void initState() {
    super.initState();
    final name = widget.paths.length == 1 ? p.basename(widget.paths.first) : "";
    _controller = TextEditingController(text: name);
    _focusNode = FocusNode();

    _controller.addListener(_validate);

    if (widget.paths.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        final nameWithoutExt = p.basenameWithoutExtension(widget.paths.first);
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: nameWithoutExt.length,
        );
      });
    } else {
      _focusNode.requestFocus();
    }
  }

  void _validate() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      if (_hasConflict) setState(() => _hasConflict = false);
      return;
    }

    if (widget.paths.length == 1) {
      final originalName = p.basename(widget.paths.first);
      final exists =
          widget.existingNames.contains(value) && value != originalName;
      if (_hasConflict != exists) {
        setState(() => _hasConflict = exists);
      }
    } else {
      // For bulk rename, simple conflict check is harder because it adds numbers
      // We'll skip real-time validation for bulk for now or keep it simple
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_validate);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_hasConflict) return;

    final value = _controller.text.trim();
    if (value.isEmpty) {
      widget.onClose();
      return;
    }

    if (widget.paths.length == 1) {
      if (value != p.basename(widget.paths.first)) {
        widget.onRename(value);
      } else {
        widget.onClose();
      }
    } else {
      widget.onRename({
        'mode': _bulkMode,
        'value': value,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isMulti = widget.paths.length > 1;
    final width = 340.0;
    final height = isMulti ? 260.0 : (_hasConflict ? 165.0 : 135.0);

    double left = widget.position.dx - (width / 2);
    double top = widget.position.dy + 12;

    bool isBelow = true;
    if (left < 16) left = 16;
    if (left + width > screenSize.width - 16)
      left = screenSize.width - width - 16;
    if (top + height > screenSize.height - 16) {
      top = widget.position.dy - height - 30;
      isBelow = false;
    }

    final backgroundColor = const Color(0xFF2D2D2D).withOpacity(0.95);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            onSecondaryTapUp: (_) => widget.onClose(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: widget.position.dx - 10,
          top: isBelow ? top - 8 : top + height - 2,
          child: CustomPaint(
            size: const Size(20, 10),
            painter: _TrianglePainter(color: backgroundColor, isUp: isBelow),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: width,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMulti
                            ? 'Bulk Rename'
                            : (p.extension(widget.paths.first).isEmpty
                                  ? 'Rename Folder'
                                  : 'Rename File'),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isMulti) ...[
                        _buildRadioMode(RenameMode.prefix, 'Add Prefix'),
                        _buildRadioMode(
                          RenameMode.constant,
                          'Constant Name + Counter',
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _hasConflict
                                ? AppColors.error.withOpacity(0.5)
                                : const Color(0xFF007AFF).withOpacity(0.5),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: isMulti
                                ? (_bulkMode == RenameMode.prefix
                                      ? 'Enter Prefix'
                                      : 'Enter Base Name')
                                : null,
                            hintStyle: GoogleFonts.manrope(
                              color: Colors.white24,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_hasConflict) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '  Already exists',
                            style: GoogleFonts.manrope(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildSubmitButton(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioMode(RenameMode mode, String label) {
    final bool isSelected = _bulkMode == mode;
    return InkWell(
      onTap: () => setState(() => _bulkMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF007AFF) : Colors.white24,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: _hasConflict ? null : AppTheme.primaryGradient,
        color: _hasConflict ? Colors.white10 : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _hasConflict
            ? []
            : [
                BoxShadow(
                  color: AppColors.violet.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _hasConflict ? null : _submit,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Rename',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _hasConflict ? Colors.white24 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool isUp;

  _TrianglePainter({required this.color, required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
