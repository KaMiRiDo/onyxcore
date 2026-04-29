import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart'; // Using existing switch if needed, but radio is better for this.
import 'package:path/path.dart' as p;

enum RenameMode { prefix, sequence }

class RenameDialog extends StatefulWidget {
  final List<String> paths;

  const RenameDialog({required this.paths, super.key});

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;
  RenameMode _mode = RenameMode.prefix;
  bool get _isBulk => widget.paths.length > 1;

  @override
  void initState() {
    super.initState();
    final initialValue = _isBulk ? "" : p.basenameWithoutExtension(widget.paths.first);
    _controller = TextEditingController(text: initialValue);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getPreview() {
    if (widget.paths.isEmpty) return "";
    final path = widget.paths.first;
    final name = p.basename(path);
    final ext = p.extension(path);
    final input = _controller.text;

    if (!_isBulk) return input + ext;

    if (_mode == RenameMode.prefix) {
      return "$input$name";
    } else {
      return "${input}_1$ext";
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Center(
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: AppColors.surfaceBase.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isBulk) _buildBulkOptions(),
                    const SizedBox(height: 24),
                    _buildInputLabel(),
                    const SizedBox(height: 12),
                    _buildTextField(),
                    const SizedBox(height: 24),
                    _buildPreviewSection(),
                    const SizedBox(height: 32),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.edit_note_rounded, color: AppColors.cyan, size: 24),
          ),
          const SizedBox(width: 18),
          Text(
            _isBulk ? 'Bulk Rename' : 'Rename Item',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "RENAMING MODE",
          style: GoogleFonts.manrope(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildRadioButton(
              label: "Add Prefix",
              active: _mode == RenameMode.prefix,
              onTap: () => setState(() => _mode = RenameMode.prefix),
            ),
            const SizedBox(width: 16),
            _buildRadioButton(
              label: "Sequence",
              active: _mode == RenameMode.sequence,
              onTap: () => setState(() => _mode = RenameMode.sequence),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRadioButton({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.cyan.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.cyan.withOpacity(0.5) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: active ? AppColors.cyan : Colors.white24,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: active ? Colors.white : Colors.white38,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel() {
    String label = _isBulk 
        ? (_mode == RenameMode.prefix ? "PREFIX STRING" : "SEQUENCE BASE NAME")
        : "NEW ITEM NAME";
    
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: InputBorder.none,
          hintText: _isBulk ? "Enter value..." : "Enter file name",
          hintStyle: TextStyle(color: Colors.white12),
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white24, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PREVIEW",
                  style: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPreview(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.cyan.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCEL',
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _controller.text.isEmpty ? null : () {
            if (!_isBulk) {
              Navigator.pop(context, _controller.text);
            } else {
              Navigator.pop(context, {
                'mode': _mode,
                'value': _controller.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            'RENAME',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ),
      ],
    );
  }
}
