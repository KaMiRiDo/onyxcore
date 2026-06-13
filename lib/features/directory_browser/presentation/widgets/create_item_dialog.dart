import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

class CreateItemDialog extends StatefulWidget {
  final String currentPath;
  final List<String> existingNames;
  final bool initialIsFolder;

  const CreateItemDialog({
    required this.currentPath,
    required this.existingNames,
    this.initialIsFolder = true,
    super.key,
  });

  static Future<String?> show({
    required BuildContext context,
    required String currentPath,
    required List<String> existingNames,
    bool initialIsFolder = true,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => CreateItemDialog(
        currentPath: currentPath,
        existingNames: existingNames,
        initialIsFolder: initialIsFolder,
      ),
    );
  }

  @override
  State<CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<CreateItemDialog> {
  late bool _isFolder;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isFolder = widget.initialIsFolder;
    _controller.addListener(_validate);
    
    // Maintain focus
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        _focusNode.requestFocus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _controller.text.trim();
    String? error;

    if (text.isEmpty) {
      error = null;
    } else {
      final invalidChars = RegExp(r'[\\/:*?"<>|]');
      if (invalidChars.hasMatch(text)) {
        error = 'Name contains invalid characters';
      } else if (widget.existingNames.contains(text)) {
        error = 'A ${(_isFolder ? "folder" : "file")} with this name already exists';
      }
    }

    setState(() {
      _errorMessage = error;
    });
  }

  void _toggleType() {
    setState(() {
      _isFolder = !_isFolder;
      _validate();
    });
  }

  void _submit() {
    if (_errorMessage == null && _controller.text.trim().isNotEmpty) {
      Navigator.pop(context, '${_isFolder ? "folder" : "file"}:${_controller.text.trim()}');
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown || 
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _toggleType();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _submit();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Focus(
          onKeyEvent: (node, event) {
            _handleKeyEvent(event);
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 420,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopIcon(),
                const SizedBox(height: 16),
                _buildTitle(),
                const SizedBox(height: 20),
                _buildInputSection(),
                const SizedBox(height: 12),
                _buildTypeSelection(),
                const SizedBox(height: 24),
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Center(
        child: Icon(
          _isFolder ? Icons.create_new_folder_outlined : Icons.note_add_outlined,
          color: Colors.white.withOpacity(0.9),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      _isFolder ? "New Folder" : "New Document",
      style: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              _errorMessage!,
              style: GoogleFonts.manrope(
                color: AppColors.error.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _errorMessage != null 
                  ? AppColors.error.withOpacity(0.3) 
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            cursorColor: AppColors.violet,
            textAlign: TextAlign.left,
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(0.9), 
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: _isFolder ? 'Enter folder name' : 'Enter document name',
              hintStyle: GoogleFonts.manrope(
                color: Colors.white.withOpacity(0.2),
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectionRow(
            title: 'Folder',
            isSelected: _isFolder,
            icon: Icons.folder_outlined,
            onTap: () => setState(() {
              _isFolder = true;
              _validate();
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSelectionRow(
            title: 'Document',
            isSelected: !_isFolder,
            icon: Icons.description_outlined,
            onTap: () => setState(() {
              _isFolder = false;
              _validate();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionRow({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.03),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isSelected 
                  ? ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Icon(icon, size: 18, color: Colors.white),
                    )
                  : Icon(icon, size: 18, color: Colors.white.withOpacity(0.2)),
              ),
              const SizedBox(width: 12),
              isSelected 
                ? ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      title,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              const Spacer(),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                    width: 2,
                  ),
                  gradient: isSelected 
                      ? const LinearGradient(
                          colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: isSelected 
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    )
                  : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final bool canCreate = _errorMessage == null && _controller.text.trim().isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: canCreate 
                  ? const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: canCreate ? null : Colors.white.withOpacity(0.05),
            ),
            child: ElevatedButton(
              onPressed: canCreate ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.transparent,
              ),
              child: Text(
                "Create",
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800, 
                  fontSize: 15,
                  color: canCreate ? Colors.white : Colors.white10,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
