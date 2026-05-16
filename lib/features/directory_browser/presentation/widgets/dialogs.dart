import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Show a vibrant confirmation dialog — exact same UI as original.
Future<bool> showVibrantConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.manrope(fontSize: 14, color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            "Cancel",
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            backgroundColor: confirmColor.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            confirmLabel,
            style: GoogleFonts.manrope(
              color: confirmColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Show an input dialog for text entry — exact same UI as original.
Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String? initialValue,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _InputDialog(
      title: title,
      hint: hint,
      initialValue: initialValue,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String? initialValue;

  const _InputDialog({
    required this.title,
    required this.hint,
    this.initialValue,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: GoogleFonts.manrope(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: GoogleFonts.manrope(color: Colors.white30),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.violet.withOpacity(0.5)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.violet),
          ),
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(
            "Create",
            style: GoogleFonts.manrope(
              color: AppColors.violet,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// A reusable confirmation dialog with destructive/normal styling.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final bool isDestructive;

  const ConfirmDialog({
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.isDestructive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = isDestructive ? AppColors.error : AppColors.violet;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.manrope(fontSize: 14, color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            backgroundColor: confirmColor.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            confirmText,
            style: GoogleFonts.manrope(
              color: confirmColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// A specialized, high-fidelity confirmation dialog for permanent deletions.
class PermanentDeleteDialog extends StatelessWidget {
  final int filesCount;
  final int foldersCount;
  final String totalSize;

  const PermanentDeleteDialog({
    super.key,
    required this.filesCount,
    required this.foldersCount,
    required this.totalSize,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = filesCount + foldersCount;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 50,
              spreadRadius: 10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Centered Trash Icon with Soft Glow
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.error.withOpacity(0.15), width: 1.5),
              ),
              child: Center(
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error.withOpacity(0.9),
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "Are you sure?",
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    label: "Folders",
                    value: foldersCount.toString(),
                    color: Colors.white.withOpacity(0.7),
                  ),
                  _buildStatItem(
                    label: "Files",
                    value: filesCount.toString(),
                    color: Colors.white.withOpacity(0.7),
                  ),
                  _buildStatItem(
                    label: "Total Space",
                    value: totalSize,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Refined Warning Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.04),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.error.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.error.withOpacity(0.6),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "This action cannot be undone",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.error.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "No, Cancel",
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Yes, Delete",
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white24,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
