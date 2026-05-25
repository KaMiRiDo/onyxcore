import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

class PasswordDialog extends StatefulWidget {
  final String title;
  final String message;

  const PasswordDialog({
    super.key,
    this.title = 'Enter Password',
    this.message = 'This archive is encrypted and requires a password to extract.',
  });

  static Future<String?> show(BuildContext context, {String title = 'Enter Password', String message = 'This archive is encrypted and requires a password to extract.'}) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => PasswordDialog(title: title, message: message),
    );
  }

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  late TextEditingController _controller;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_controller.text.isEmpty) return;
    Navigator.pop(context, _controller.text);
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
            width: 420,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.85),
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
                      Text(
                        widget.message,
                        style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Text("PASSWORD", style: GoogleFonts.manrope(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      _buildTextField(),
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
            child: const Icon(Icons.lock_rounded, color: AppColors.violet, size: 24),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violet.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscureText,
        style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
        onSubmitted: (_) => _handleSubmit(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: InputBorder.none,
          hintText: "Enter password",
          hintStyle: const TextStyle(color: Colors.white12),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: Colors.white54,
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          ),
        ),
      ),
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
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('UNLOCK', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
        ),
      ],
    );
  }
}
