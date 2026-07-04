import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:path/path.dart' as p;

enum ConflictResolution { replace, skip, rename }

class ConflictResult {
  final ConflictResolution resolution;
  final bool applyToAll;
  ConflictResult(this.resolution, this.applyToAll);
}

class ConflictDialog extends ConsumerStatefulWidget {
  final String fileName;
  final String destinationPath;
  final bool isFolder;
  final bool showApplyToAll;

  const ConflictDialog({
    required this.fileName,
    required this.destinationPath,
    this.isFolder = false,
    this.showApplyToAll = true,
    super.key,
  });

  @override
  ConsumerState<ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends ConsumerState<ConflictDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _selectedIndex = 0;
  bool _applyToAll = false;

  final List<ConflictResolution> _resolutions = [
    ConflictResolution.skip,
    ConflictResolution.replace,
    ConflictResolution.rename,
  ];

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: CurveSelection())).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  void _handleNavigate(int direction) {
    setState(() {
      _selectedIndex = (_selectedIndex + direction).clamp(
        0,
        _resolutions.length - 1,
      );
    });
  }

  void _handleConfirm() {
    Navigator.pop(
      context,
      ConflictResult(_resolutions[_selectedIndex], _applyToAll),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _triggerShake();
      },
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _handleNavigate(1);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _handleNavigate(-1);
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              _handleConfirm();
            }
          }
        },
        child: GestureDetector(
          onTap: _triggerShake,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final double offset = sin(_shakeAnimation.value * pi * 4) * 8;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: GestureDetector(
                onTap: () {}, // Stop tap propagation inside dialog box
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 440,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.isFolder ? "Folder" : "File"} already exists',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.manrope(
                                      color: Colors.white60,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            '"${_truncateMiddle(widget.fileName, 24)}"',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' already exists - ',
                                      ),
                                      TextSpan(
                                        text: _formatDestinationPath(
                                          widget.destinationPath,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Divider(color: Colors.white10, height: 1),

                          // Action Buttons
                          _buildOption(
                            context,
                            icon: Icons.skip_next_rounded,
                            title: 'Skip',
                            subtitle: 'Leave the current file as is',
                            value: ConflictResolution.skip,
                            color: AppColors.textMuted,
                            index: 0,
                          ),
                          _buildOption(
                            context,
                            icon: Icons.copy_all_rounded,
                            title: 'Replace',
                            subtitle: 'Overwrite the existing file',
                            value: ConflictResolution.replace,
                            color: AppColors.error,
                            index: 1,
                          ),
                          _buildOption(
                            context,
                            icon: Icons.drive_file_rename_outline_rounded,
                            title: 'Rename (Keep Both)',
                            subtitle: 'Paste with a new name',
                            value: ConflictResolution.rename,
                            color: AppColors.cyan,
                            index: 2,
                          ),

                          if (widget.showApplyToAll) ...[
                            const Divider(color: Colors.white10, height: 1),
                            InkWell(
                              onTap: () =>
                                  setState(() => _applyToAll = !_applyToAll),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _applyToAll,
                                        onChanged: (val) => setState(
                                          () => _applyToAll = val ?? false,
                                        ),
                                        activeColor: AppColors.violet,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Apply this for all files/folders',
                                        style: GoogleFonts.manrope(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ConflictResolution value,
    required Color color,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, ConflictResult(value, _applyToAll)),
        onHover: (hovering) {
          if (hovering) setState(() => _selectedIndex = index);
        },
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: const Border(
                    left: BorderSide(color: AppColors.violet, width: 3),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected ? Colors.white70 : Colors.white24,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDestinationPath(String path) {
    final parts = p.split(path);
    if (parts.length >= 2) {
      final folder = _truncateMiddle(parts[parts.length - 2], 24);
      final file = _truncateMiddle(parts[parts.length - 1], 24);
      return "...../$folder/$file";
    }
    return _truncateMiddle(path, 40);
  }

  String _truncateMiddle(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    int half = (maxLength / 2).floor();
    return "${text.substring(0, half - 2)}...${text.substring(text.length - (half - 1))}";
  }
}

class CurveSelection extends Curve {
  @override
  double transformInternal(double t) {
    return t; // Linear for now, we use sin(t) in the builder
  }
}
