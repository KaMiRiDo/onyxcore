import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:path/path.dart' as p;

class CompressDialogResult {
  final String archiveName;
  final String format;
  final String? password;

  CompressDialogResult({
    required this.archiveName,
    required this.format,
    this.password,
  });
}

class CompressDialog extends StatefulWidget {
  final List<String> sourcePaths;

  const CompressDialog({super.key, required this.sourcePaths});

  static Future<CompressDialogResult?> show(
    BuildContext context,
    List<String> sourcePaths,
  ) {
    return showDialog<CompressDialogResult>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => CompressDialog(sourcePaths: sourcePaths),
    );
  }

  @override
  State<CompressDialog> createState() => _CompressDialogState();
}

class _CompressDialogState extends State<CompressDialog> {
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  String _selectedFormat = 'zip';
  bool _obscurePassword = true;

  final List<String> _formats = ['zip', '7z', 'tar', 'gz'];

  @override
  void initState() {
    super.initState();
    String defaultName = 'archive';
    if (widget.sourcePaths.isNotEmpty) {
      if (widget.sourcePaths.length == 1) {
        defaultName = p.basenameWithoutExtension(widget.sourcePaths.first);
      } else {
        defaultName = p.basename(p.dirname(widget.sourcePaths.first));
        if (defaultName.isEmpty || defaultName == '.') {
          defaultName = 'archive';
        }
      }
    }

    _nameController = TextEditingController(text: defaultName);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_nameController.text.isEmpty) return;

    final password = _passwordController.text.isNotEmpty
        ? _passwordController.text
        : null;
    Navigator.pop(
      context,
      CompressDialogResult(
        archiveName: _nameController.text,
        format: _selectedFormat,
        password: password,
      ),
    );
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
              color: const Color(0xFF1E1E1E).withOpacity(0.85),
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
                      Text(
                        "ARCHIVE NAME",
                        style: GoogleFonts.manrope(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_nameController, "Enter archive name"),
                      const SizedBox(height: 24),
                      Text(
                        "FORMAT",
                        style: GoogleFonts.manrope(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFormatSelector(),
                      const SizedBox(height: 24),
                      Text(
                        "PASSWORD (OPTIONAL)",
                        style: GoogleFonts.manrope(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPasswordField(),
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
            child: const Icon(
              Icons.folder_zip_rounded,
              color: AppColors.violet,
              size: 24,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            'Compress Items',
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

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violet.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
        onSubmitted: (_) => _handleSubmit(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white12),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violet.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
        onSubmitted: (_) => _handleSubmit(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: InputBorder.none,
          hintText: "Enter password to encrypt",
          hintStyle: const TextStyle(color: Colors.white12),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.white54,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Row(
      children: _formats.map((format) {
        final isActive = _selectedFormat == format;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selectedFormat = format),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.violet.withOpacity(0.2)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AppColors.violet
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Text(
                format.toUpperCase(),
                style: GoogleFonts.manrope(
                  color: isActive ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'COMPRESS',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
