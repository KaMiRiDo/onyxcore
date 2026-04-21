import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

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
  bool _isControlsVisible = true;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.windowId != null) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _loadFile();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadFile() async {
    setState(() => _isLoading = true);
    try {
      final content = await File(widget.item.path).readAsString();
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _content = '# Error Loading File\n\n$e';
          _isLoading = false;
        });
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
            // Markdown Content
            Positioned.fill(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
                      child: Markdown(
                        controller: _scrollController,
                        data: _content,
                        selectable: true,
                        styleSheet: _buildStyleSheet(context),
                      ),
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
                  metadata: 'Markdown Documentation',
                  isStandalone: widget.windowId != null,
                  onPopOut: _openInNewWindow,
                  onClose: () => ref.read(previewFileProvider.notifier).state = null,
                ),
              ),
            ),
          ],
        ),
      ),
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
