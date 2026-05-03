import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart'; // Using existing switch if needed, but radio is better for this.
import 'package:path/path.dart' as p;

import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_popover.dart';

class RenameDialog extends StatefulWidget {
  final List<String> paths;

  const RenameDialog({required this.paths, super.key});

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;
  RenameMode _mode = RenameMode.prefix;
  String? _errorMessage;
  bool _isSubmitting = false;

  bool get _isBulk => widget.paths.length > 1;

  @override
  void initState() {
    super.initState();
    final initialValue = _isBulk ? "" : p.basenameWithoutExtension(widget.paths.first);
    _controller = TextEditingController(text: initialValue);
    _controller.addListener(() => setState(() {
      _errorMessage = null;
    }));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_controller.text.isEmpty || _isSubmitting) return;

    final value = _controller.text;
    
    // Check for existing files for simple rename
    if (!_isBulk) {
      final oldPath = widget.paths.first;
      final parent = p.dirname(oldPath);
      final newPath = p.join(parent, value + p.extension(oldPath));
      
      // If name hasn't changed, just close
      if (newPath == oldPath) {
        Navigator.pop(context);
        return;
      }

      if (io.File(newPath).existsSync() || io.Directory(newPath).existsSync()) {
        setState(() {
          _errorMessage = "A file or folder with this name already exists.";
        });
        return;
      }
    }

    // Clear error and pop
    setState(() => _errorMessage = null);
    if (!_isBulk) {
      Navigator.pop(context, value);
    } else {
      Navigator.pop(context, {'mode': _mode, 'value': value});
    }
  }

  List<Map<String, String>> _getPreviews() {
    final value = _controller.text;
    return widget.paths.asMap().entries.map((entry) {
      final index = entry.key;
      final path = entry.value;
      final original = p.basename(path);
      String newName;
      
      if (!_isBulk) {
        newName = value + p.extension(path);
      } else if (_mode == RenameMode.prefix) {
        newName = "$value$original";
      } else {
        newName = "${value}_${index + 1}${p.extension(path)}";
      }
      
      return {'original': original, 'new': newName};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.85), // Matches other dialogs
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.violet.withOpacity(0.3)),
            ),
            child: const Icon(Icons.edit_note_rounded, color: AppColors.violet, size: 24),
          ),
          const SizedBox(width: 18),
          Text(
            _isBulk ? 'Bulk Rename' : 'Rename Item',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
          style: GoogleFonts.manrope(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildRadioButton(label: "Add Prefix", active: _mode == RenameMode.prefix, onTap: () => setState(() => _mode = RenameMode.prefix)),
            const SizedBox(width: 16),
            _buildRadioButton(label: "Constant Name", active: _mode == RenameMode.constant, onTap: () => setState(() => _mode = RenameMode.constant)),
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
          color: active ? AppColors.violet.withOpacity(0.2) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.violet : Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 16, color: active ? AppColors.violet : Colors.white24),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.manrope(color: active ? Colors.white : Colors.white38, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel() {
    String label = _isBulk ? (_mode == RenameMode.prefix ? "PREFIX STRING" : "CONSTANT BASE NAME") : "NEW ITEM NAME";
    return Text(label, style: GoogleFonts.manrope(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5));
  }

  Widget _buildTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _errorMessage != null 
                  ? AppColors.error.withOpacity(0.5) 
                  : AppColors.violet.withOpacity(0.2)
            ),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
            onSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: InputBorder.none,
              hintText: _isBulk ? "Enter value..." : "Enter file name",
              hintStyle: const TextStyle(color: Colors.white12),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.manrope(
                color: AppColors.error.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewSection() {
    final previews = _getPreviews();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PREVIEW",
          style: GoogleFonts.manrope(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 140), // Height for ~3 items
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            shrinkWrap: true,
            itemCount: previews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = previews[index];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      item['original']!,
                      style: GoogleFonts.manrope(color: Colors.white38, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white12),
                  ),
                  Expanded(
                    child: Text(
                      item['new']!,
                      style: GoogleFonts.manrope(color: AppColors.violet, fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: GoogleFonts.manrope(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            gradient: _controller.text.isEmpty ? null : AppTheme.primaryGradient,
            color: _controller.text.isEmpty ? Colors.white10 : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _controller.text.isEmpty ? [] : [BoxShadow(color: AppColors.violet.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: _controller.text.isEmpty ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('RENAME', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
        ),
      ],
    );
  }
}
