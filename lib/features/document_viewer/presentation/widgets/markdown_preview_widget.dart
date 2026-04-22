import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class MarkdownPreviewWidget extends ConsumerStatefulWidget {
  const MarkdownPreviewWidget({
    required this.item,
    this.windowId,
    this.parentWindowId,
    super.key,
  });

  final FileItem item;
  final String? windowId;
  final String? parentWindowId;

  @override
  ConsumerState<MarkdownPreviewWidget> createState() => _MarkdownPreviewWidgetState();
}

class _MarkdownPreviewWidgetState extends ConsumerState<MarkdownPreviewWidget> with WindowListener {
  String _content = '';
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isControlsVisible = true;
  bool _hasChanges = false;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.windowId != null) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _loadFile();
    
    _editController.addListener(() {
      if (_editController.text != _content && !_hasChanges) {
        setState(() => _hasChanges = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadFile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final file = File(widget.item.path);
      if (!await file.exists()) {
        throw Exception('File does not exist at ${widget.item.path}');
      }
      
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _content = content;
          // Use value setter to ensure listener is notified correctly
          _editController.value = TextEditingValue(
            text: content,
            selection: TextSelection.collapsed(offset: content.length),
          );
          _hasChanges = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MarkdownViewer] Error loading file: $e');
      if (mounted) {
        setState(() {
          _content = '# Error Loading File\n\n$e';
          _editController.text = _content;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveFile() async {
    try {
      await File(widget.item.path).writeAsString(_editController.text);
      if (mounted) {
        setState(() {
          _content = _editController.text;
          _hasChanges = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.windowId != null) {
      windowManager.removeListener(this);
    }
    _focusNode.dispose();
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (widget.windowId != null) {
      await windowManager.hide();
    }
  }

  @override
  void didUpdateWidget(MarkdownPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadFile();
      if (mounted) {
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _openInNewWindow() async {
    final windowParams = WindowParams(
      viewerType: ViewerType.markdown,
      file: widget.item,
    );

    try {
      await PersistentViewerManager.openMedia(windowParams);
      if (mounted) {
        ref.read(previewFileProvider.notifier).state = null;
      }
    } catch (e) {
      debugPrint('Error opening persistent markdown viewer: $e');
    }
  }

  void _navigateMedia(bool forward) {
    if (widget.windowId != null) {
      final payload = jsonEncode({
        'direction': forward ? 'next' : 'prev',
        'currentPath': widget.item.path,
        'type': 'document',
        'targetWindowId': widget.windowId!,
      });
      WindowController.fromWindowId(widget.parentWindowId ?? '0').invokeMethod('request_navigation', payload);
    } else {
      final items = ref.read(directoryItemsProvider).value ?? [];
      if (items.isEmpty) return;

      final docs = items.where((i) => i.type == FileItemType.document).toList();
      if (docs.isEmpty) return;

      final currentIndex = docs.indexWhere((i) => i.path == widget.item.path);
      if (currentIndex == -1) return;

      int nextIndex;
      if (forward) {
        nextIndex = (currentIndex + 1) % docs.length;
      } else {
        nextIndex = (currentIndex - 1 + docs.length) % docs.length;
      }

      ref.read(previewFileProvider.notifier).state = docs[nextIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGlobalHudVisible = widget.windowId == null ? ref.watch(previewHudVisibleProvider) : true;
    final isVisible = _isControlsVisible && isGlobalHudVisible;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Prevention: Don't navigate while editing unless Alt is pressed
          if (_isEditing) return KeyEventResult.ignored;

          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _navigateMedia(true);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (!HardwareKeyboard.instance.isAltPressed) {
              _navigateMedia(false);
              return KeyEventResult.handled;
            }
          }

          if (widget.windowId == null) {
            final isAltPressed = HardwareKeyboard.instance.isAltPressed;
            if (event.logicalKey == LogicalKeyboardKey.backspace || 
                (isAltPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft)) {
              ref.read(previewFileProvider.notifier).state = null;
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Content
            Positioned.fill(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
                      child: _isEditing ? _buildEditor() : _buildMarkdown(),
                    ),
            ),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isVisible ? 1.0 : 0.0,
                child: ViewerTopBar(
                  title: widget.item.name,
                  metadata: _isEditing ? 'Editing Mode' : 'Markdown Documentation',
                  isStandalone: widget.windowId != null,
                  onPopOut: _openInNewWindow,
                  onClose: () => ref.read(previewFileProvider.notifier).state = null,
                  extraActions: [
                    if (_isEditing)
                      _buildTopButton(
                        icon: Icons.save_rounded,
                        onPressed: _hasChanges ? _saveFile : () {},
                        color: _hasChanges ? const Color(0xFF00E5FF) : Colors.white24,
                        tooltip: 'Save Changes',
                      ),
                    const SizedBox(width: 8),
                    _buildTopButton(
                      icon: _isEditing ? Icons.visibility_rounded : Icons.edit_rounded,
                      onPressed: () => setState(() => _isEditing = !_isEditing),
                      tooltip: _isEditing ? 'View Preview' : 'Edit File',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color color = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _editController,
        maxLines: null,
        expands: true,
        style: GoogleFonts.jetBrainsMono(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(24),
          border: InputBorder.none,
          hintText: 'Start typing...',
          hintStyle: TextStyle(color: Colors.white24),
        ),
        cursorColor: const Color(0xFF00E5FF),
      ),
    );
  }

  Widget _buildMarkdown() {
    return Markdown(
      controller: _scrollController,
      data: _content,
      selectable: true,
      styleSheet: _buildStyleSheet(context),
      builders: {
        'code': CodeElementBuilder(),
      },
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      p: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, height: 1.6),
      h1: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
      h2: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      h3: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      code: GoogleFonts.jetBrainsMono(
        backgroundColor: Colors.white.withOpacity(0.05),
        color: const Color(0xFF00E5FF),
        fontSize: 14,
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      blockquote: GoogleFonts.outfit(color: Colors.white54, fontSize: 16, fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.violet, width: 4)),
      ),
      listBullet: GoogleFonts.outfit(color: AppColors.violet, fontSize: 16),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    if (element.attributes['class'] != null) {
      final lg = element.attributes['class'] as String;
      language = lg.replaceFirst('language-', '');
    }

    final String code = element.textContent;
    
    // Inline code (no newline) vs Block code
    final bool isBlock = code.contains('\n');

    if (!isBlock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          code,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF00E5FF),
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          // Code Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code.trim(),
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          
          // Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                   if (language.isNotEmpty)
                    Text(
                      language.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  const Spacer(),
                  _CopyButton(text: code),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.content_copy_rounded,
              size: 14,
              color: _copied ? const Color(0xFF00E5FF) : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              _copied ? 'COPIED' : 'COPY',
              style: GoogleFonts.outfit(
                color: _copied ? const Color(0xFF00E5FF) : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
