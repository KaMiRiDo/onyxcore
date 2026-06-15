import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:onyxcore/features/document_viewer/services/mermaid_offline_renderer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:math' as math;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_syntax_highlighter.dart';
import 'package:onyxcore/core/widgets/search_replace_overlay.dart';
import 'package:onyxcore/features/document_viewer/utils/html_search_highlighter.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/line_numbers_painter.dart';

class SaveIntent extends Intent {
  const SaveIntent();
}

class DualPaneIntent extends Intent {
  const DualPaneIntent();
}

class EditorModeIntent extends Intent {
  const EditorModeIntent();
}

class CloseIntent extends Intent {
  const CloseIntent();
}

class PreviewModeIntent extends Intent {
  const PreviewModeIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class MarkdownPreviewWidget extends ConsumerStatefulWidget {
  const MarkdownPreviewWidget({
    required this.item,
    this.windowId,
    this.parentWindowId,
    this.isStandalone = false,
    super.key,
  });

  final FileItem item;
  final String? windowId;
  final String? parentWindowId;
  final bool isStandalone;

  @override
  ConsumerState<MarkdownPreviewWidget> createState() =>
      _MarkdownPreviewWidgetState();
}

class _MarkdownPreviewWidgetState extends ConsumerState<MarkdownPreviewWidget>
    with WindowListener {
  String _content = '';
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isControlsVisible = true;
  bool _isGlobalHudVisible = true;
  bool _hasChanges = false;
  bool _isDualPane = false;
  final ValueNotifier<double> _editorWidthRatioNotifier = ValueNotifier<double>(
    0.5,
  );
  bool _isSyncingScroll = false;
  bool _isSearchVisible = false;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _previewFocusNode = FocusNode();
  final GlobalKey _htmlKey = GlobalKey();
  final GlobalKey _editorKey = GlobalKey();
  bool _isResizingDualPane = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _lineNumbersScrollController = ScrollController();
  final MarkdownSyntaxHighlighter _editController = MarkdownSyntaxHighlighter();
  final UndoHistoryController _undoController = UndoHistoryController();
  final ValueNotifier<int> _lineNumbersRepaintNotifier = ValueNotifier<int>(0);
  Timer? _debounceTimer;
  final Map<String, Future<Uint8List?>> _mermaidFutures = {};
  String _previewContent = '';
  Offset? _pointerDownPosition;
  DateTime? _lastClickTime;
  String _lastText = '';

  String _searchQuery = '';
  int _currentSearchMatchIndex = -1;
  int _totalSearchMatches = 0;
  bool _searchCaseSensitive = false;
  bool _searchUseRegex = false;

  final ValueNotifier<_SearchPosition> _searchPosition = ValueNotifier(
    const _SearchPosition(top: 100.0, right: 16.0),
  );

  @override
  void initState() {
    super.initState();
    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);
    if (widget.windowId != null) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _editorScrollController.addListener(_onEditorScroll);
    _scrollController.addListener(_onPreviewScroll);
    _loadFile();

    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      _searchCaseSensitive = settings.documentSearchCaseSensitive;
      _searchUseRegex = settings.documentSearchUseRegex;
      _editController.caseSensitive = _searchCaseSensitive;
      _editController.useRegex = _searchUseRegex;
    }

    _editController.addListener(() {
      if (_editController.text == _lastText) return; // Ignore cursor movement
      _lastText = _editController.text;

      if (_editController.text != _content && !_hasChanges) {
        setState(() => _hasChanges = true);
      } else if (_editController.text == _content && _hasChanges) {
        setState(() => _hasChanges = false);
      }
      _updateSearchMatches();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _lineNumbersRepaintNotifier.value++;
        }
      });

      if (_isDualPane && mounted) {
        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && _previewContent != _editController.text) {
            setState(() {
              _previewContent = _editController.text;
            });
          }
        });
      }
    });

    KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
      if (event is KeyDownEvent) {
        final isCtrl =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
          if (_isEditing || _isDualPane) {
            final oldText = _editController.text;
            if (isShift) {
              _undoController.redo();
            } else {
              _undoController.undo();
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fixCursorAfterUndoRedo(oldText, _editController.text);
            });
          }
          return KeyEventResult.handled;
        }

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyW) {
          if (widget.windowId == null) {
            _requestClose();
            return KeyEventResult.handled;
          }
        }
        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
          setState(() => _isSearchVisible = !_isSearchVisible);
          return KeyEventResult.handled;
        }
        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
          _saveFile();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    _focusNode.onKeyEvent = handleKeyEvent;
    _previewFocusNode.onKeyEvent = handleKeyEvent;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_isEditing) {
          _focusNode.requestFocus();
        } else {
          _previewFocusNode.requestFocus();
        }
      }
    });
  }

  void _onEditorScroll() {
    if (!_isDualPane) return;
    if (_isSyncingScroll) return;
    if (!_editorScrollController.hasClients || !_scrollController.hasClients)
      return;
    if (_editorScrollController.position.maxScrollExtent == 0) return;

    final ratio =
        _editorScrollController.offset /
        _editorScrollController.position.maxScrollExtent;
    final target = _scrollController.position.maxScrollExtent * ratio;

    if ((_scrollController.offset - target).abs() > 1.0) {
      _isSyncingScroll = true;
      _scrollController.jumpTo(target);
      _isSyncingScroll = false;
    }
  }

  void _onPreviewScroll() {
    if (!_isDualPane) return;
    if (_isSyncingScroll) return;
    if (!_editorScrollController.hasClients || !_scrollController.hasClients)
      return;
    if (_scrollController.position.maxScrollExtent == 0) return;

    final ratio =
        _scrollController.offset / _scrollController.position.maxScrollExtent;
    final target = _editorScrollController.position.maxScrollExtent * ratio;

    if ((_editorScrollController.offset - target).abs() > 1.0) {
      _isSyncingScroll = true;
      _editorScrollController.jumpTo(target);
      _isSyncingScroll = false;
    }
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
          _previewContent = content;
          _lastText = content;
          _editController.value = TextEditingValue(
            text: content,
            selection: const TextSelection.collapsed(offset: 0),
          );
          _hasChanges = false;
          _isLoading = false;
        });
        if (_isEditing) {
          _focusNode.requestFocus();
        } else {
          _previewFocusNode.requestFocus();
        }
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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _executeClose() async {
    if (widget.windowId != null) {
      await windowManager.hide();
    } else if (widget.isStandalone) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      ref.read(previewFileProvider.notifier).state = null;
    }
  }

  Future<void> _requestClose() async {
    debugPrint('_requestClose called!');
    if (!_hasChanges) {
      await _executeClose();
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Do you want to save them before closing?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFA6E22E)),
            ),
          ),
        ],
      ),
    );

    if (result == 'discard') {
      await _executeClose();
    } else if (result == 'save') {
      await _saveFile();
      await _executeClose();
    }
  }

  @override
  void dispose() {
    if (widget.windowId != null) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    _debounceTimer?.cancel();
    _focusNode.dispose();
    _previewFocusNode.dispose();
    _scrollController.dispose();
    _editorScrollController.dispose();
    _lineNumbersScrollController.dispose();
    _editController.dispose();
    _undoController.dispose();
    _lineNumbersRepaintNotifier.dispose();
    _editorWidthRatioNotifier.dispose();
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

  Timer? _hideTimer;
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isEditing) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _onInteraction() {
    // Wake up global HUD if it was manually hidden
    if (widget.windowId == null && !ref.read(previewHudVisibleProvider)) {
      // Immediate update is safe here because listeners handle 'mounted' check
      ref.read(previewHudVisibleProvider.notifier).state = true;
    }

    if (mounted && !_isControlsVisible) {
      setState(() => _isControlsVisible = true);
    }
    _startHideTimer();
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

  void _switchToPreview() {
    double percentage = 0.0;
    if (_isEditing && _editController.text.isNotEmpty) {
      final offset = _editController.selection.baseOffset;
      if (offset >= 0) {
        percentage = offset / _editController.text.length;
      }
    }

    setState(() {
      _isEditing = false;
      _isDualPane = false;
    });

    _previewFocusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final viewportHeight = _scrollController.position.viewportDimension;
        if (maxScroll > 0) {
          final targetY = percentage * (maxScroll + viewportHeight);
          final centeredOffset = targetY - (viewportHeight / 2);
          _scrollController.jumpTo(centeredOffset.clamp(0.0, maxScroll));
        }
      }
    });
  }

  void _switchToEditor() {
    double percentage = 0.0;
    if (!_isEditing && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final viewportHeight = _scrollController.position.viewportDimension;
      if (maxScroll > 0) {
        final centerOffset = _scrollController.offset + (viewportHeight / 2);
        percentage = (centerOffset / (maxScroll + viewportHeight)).clamp(
          0.0,
          1.0,
        );
      }
    }

    setState(() {
      _isEditing = true;
      _isDualPane = false;
    });

    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editorScrollController.hasClients) {
        final maxScroll = _editorScrollController.position.maxScrollExtent;
        final viewportHeight =
            _editorScrollController.position.viewportDimension;
        if (maxScroll > 0) {
          final targetY = percentage * (maxScroll + viewportHeight);
          final centeredOffset = targetY - (viewportHeight / 2);
          _editorScrollController.jumpTo(centeredOffset.clamp(0.0, maxScroll));
        }

        if (_editController.text.isNotEmpty) {
          final targetOffset = (percentage * _editController.text.length)
              .clamp(0, _editController.text.length)
              .toInt();
          _editController.selection = TextSelection.collapsed(
            offset: targetOffset,
          );
        }
      }
    });
  }

  void _fixCursorAfterUndoRedo(String oldText, String newText) {
    if (oldText == newText) return;

    int prefixLen = 0;
    int minLen = math.min(oldText.length, newText.length);
    while (prefixLen < minLen && oldText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    int suffixLen = 0;
    while (suffixLen < (minLen - prefixLen) &&
        oldText[oldText.length - 1 - suffixLen] ==
            newText[newText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    int cursorOffset = newText.length - suffixLen;

    _editController.selection = TextSelection.collapsed(offset: cursorOffset);

    // Ensure the editor scrolls to the reverted line
    if (_editorScrollController.hasClients) {
      final double lineHeight = 15 * 1.5; // FontSize * height
      final textBeforeCursor = _editController.text.substring(
        0,
        cursorOffset.clamp(0, _editController.text.length),
      );
      final lineIndex = '\n'.allMatches(textBeforeCursor).length;
      final targetOffset = lineIndex * lineHeight;
      final viewportHeight = _editorScrollController.position.viewportDimension;
      final centeredOffset = targetOffset - (viewportHeight / 2);
      _editorScrollController.jumpTo(
        centeredOffset.clamp(
          0.0,
          _editorScrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  void _toggleDualPane() {
    // Capture the offset from whichever view is currently active
    final double currentOffset;
    if (_isEditing && _editorScrollController.hasClients) {
      currentOffset = _editorScrollController.offset;
    } else if (!_isEditing && _scrollController.hasClients) {
      currentOffset = _scrollController.offset;
    } else {
      currentOffset = 0.0;
    }

    setState(() {
      _isDualPane = !_isDualPane;
      if (_isDualPane) {
        // Initialize preview content and enter editing mode for dual pane
        _previewContent = _editController.text;
        _isEditing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Sync BOTH controllers to the captured offset
          if (_editorScrollController.hasClients) {
            _editorScrollController.jumpTo(currentOffset);
          }
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(currentOffset);
          }
          // Focus the editor so undo/redo works
          _focusNode.requestFocus();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.windowId == null && !widget.isStandalone) {
      ref.listen(previewHudVisibleProvider, (previous, next) {
        if (mounted) {
          setState(() => _isGlobalHudVisible = next);
        }
      });
    }

    // In standalone mode, we ignore the global HUD visibility provider as the window
    // itself is the dedicated viewer. We only care about the internal control timer.
    final isVisible =
        _isControlsVisible &&
        (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.backslash, control: true):
            const DualPaneIntent(),
        const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
            const DualPaneIntent(),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            const EditorModeIntent(),
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
            const EditorModeIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyV,
          control: true,
          shift: true,
        ): const PreviewModeIntent(),
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true, shift: true):
            const PreviewModeIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            const CloseIntent(),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
            const CloseIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) {
              if ((_isEditing || _isDualPane) && _hasChanges) _saveFile();
              return null;
            },
          ),
          EditorModeIntent: CallbackAction<EditorModeIntent>(
            onInvoke: (intent) {
              _switchToEditor();
              return null;
            },
          ),
          DualPaneIntent: CallbackAction<DualPaneIntent>(
            onInvoke: (intent) {
              _toggleDualPane();
              if (_isEditing) {
                _focusNode.requestFocus();
              } else {
                _previewFocusNode.requestFocus();
              }
              return null;
            },
          ),
          PreviewModeIntent: CallbackAction<PreviewModeIntent>(
            onInvoke: (intent) {
              _switchToPreview();
              return null;
            },
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) {
              setState(() => _isSearchVisible = true);
              return null;
            },
          ),
          CloseIntent: CallbackAction<CloseIntent>(
            onInvoke: (intent) {
              if (_isSearchVisible) {
                setState(() => _isSearchVisible = false);
              } else {
                _requestClose();
              }
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _previewFocusNode,
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent, // Fix disjointed aesthetic
            body: Stack(
              children: [
                // Content
                Positioned.fill(
                  child: _isLoading
                      ? Center(child: BubbleLoader(size: 80))
                      : MouseRegion(
                          onHover: (_) => _onInteraction(),
                          cursor: _isResizingDualPane
                              ? SystemMouseCursors.resizeLeftRight
                              : MouseCursor.defer,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
                            child: _isDualPane
                                ? () {
                                    final editor = _buildEditor();
                                    final markdown = _buildMarkdown();
                                    return ValueListenableBuilder<double>(
                                      valueListenable:
                                          _editorWidthRatioNotifier,
                                      builder: (context, ratio, child) {
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                SizedBox(
                                                  width:
                                                      (constraints.maxWidth -
                                                          16) *
                                                      ratio,
                                                  child: editor,
                                                ),
                                                GestureDetector(
                                                  key: const Key(
                                                    'dual_pane_divider',
                                                  ),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onPanStart: (_) => setState(
                                                    () => _isResizingDualPane =
                                                        true,
                                                  ),
                                                  onPanUpdate: (details) {
                                                    final newRatio =
                                                        _editorWidthRatioNotifier
                                                            .value +
                                                        (details.delta.dx /
                                                            (constraints
                                                                    .maxWidth -
                                                                16));
                                                    _editorWidthRatioNotifier
                                                        .value = newRatio.clamp(
                                                      0.1,
                                                      0.9,
                                                    );
                                                  },
                                                  onPanEnd: (_) => setState(
                                                    () => _isResizingDualPane =
                                                        false,
                                                  ),
                                                  onPanCancel: () => setState(
                                                    () => _isResizingDualPane =
                                                        false,
                                                  ),
                                                  child: MouseRegion(
                                                    cursor: SystemMouseCursors
                                                        .resizeLeftRight,
                                                    child: Container(
                                                      width: 16,
                                                      color: Colors.transparent,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Container(
                                                        width: 2,
                                                        color: Colors.white
                                                            .withOpacity(0.1),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(child: markdown),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  }()
                                : (_isEditing
                                      ? _buildEditor()
                                      : _buildMarkdown()),
                          ),
                        ),
                ),
                if (_isResizingDualPane)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: Container(color: Colors.transparent),
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
                      metadata: _isDualPane
                          ? 'Dual Pane'
                          : (_isEditing
                                ? 'Editing Mode'
                                : 'Markdown Documentation'),
                      isStandalone:
                          widget.isStandalone || widget.windowId != null,
                      onPopOut: _openInNewWindow,
                      onClose: _requestClose,
                      extraActions: [
                        if (_isEditing) ...[
                          _buildTopButton(
                            icon: Icons.save_rounded,
                            onPressed: _hasChanges ? _saveFile : () {},
                            color: _hasChanges
                                ? const Color(0xFFA6E22E)
                                : Colors.white24,
                            tooltip: 'Save Changes',
                          ),
                          const SizedBox(width: 8),
                        ],
                        _buildTopButton(
                          icon: Icons.splitscreen_rounded,
                          onPressed: () {
                            _toggleDualPane();
                            if (_isEditing) {
                              _focusNode.requestFocus();
                            } else {
                              _previewFocusNode.requestFocus();
                            }
                          },
                          color: _isDualPane
                              ? const Color(0xFFA6E22E)
                              : Colors.white,
                          tooltip: 'Toggle Dual Pane (Ctrl + \\)',
                        ),
                        const SizedBox(width: 8),
                        if (!_isDualPane)
                          _buildTopButton(
                            icon: _isEditing
                                ? Icons.visibility_rounded
                                : Icons.edit_rounded,
                            onPressed: () {
                              if (_isEditing) {
                                _switchToPreview();
                              } else {
                                _switchToEditor();
                              }
                            },
                            tooltip: _isEditing ? 'View Preview' : 'Edit File',
                          ),
                        if (!_isDualPane) const SizedBox(width: 8),
                        _buildTopButton(
                          icon: Icons.search_rounded,
                          onPressed: () => setState(
                            () => _isSearchVisible = !_isSearchVisible,
                          ),
                          color: _isSearchVisible
                              ? const Color(0xFFA6E22E)
                              : Colors.white,
                          tooltip: 'Search (Ctrl + F)',
                        ),
                        const SizedBox(width: 8),
                        _buildTopButton(
                          icon: Icons.settings_rounded,
                          onPressed: () => SettingsDialog.show(
                            context,
                            initialTab: 1,
                            section: 'Documents',
                          ),
                          tooltip: 'Document Settings',
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                if (_isSearchVisible)
                  ValueListenableBuilder<_SearchPosition>(
                    valueListenable: _searchPosition,
                    builder: (context, pos, child) {
                      return Positioned(
                        top: pos.top,
                        right: pos.right,
                        left: pos.left,
                        bottom: pos.bottom,
                        child: child!,
                      );
                    },
                    child: _buildSearchOverlay(),
                  ),
              ],
            ),
          ),
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
      child: ExcludeFocus(
        child: IconButton(
          icon: Icon(icon, color: color, size: 18),
          onPressed: onPressed,
          tooltip: tooltip,
          splashRadius: 20,
        ),
      ),
    );
  }

  void _updateSearchMatches() {
    if (_searchQuery.isEmpty) {
      if (_totalSearchMatches != 0 || _currentSearchMatchIndex != -1) {
        setState(() {
          _totalSearchMatches = 0;
          _currentSearchMatchIndex = -1;
        });
      }
      return;
    }

    RegExp searchExp;
    try {
      if (_searchUseRegex) {
        searchExp = RegExp(_searchQuery, caseSensitive: _searchCaseSensitive);
      } else {
        searchExp = RegExp(
          RegExp.escape(_searchQuery),
          caseSensitive: _searchCaseSensitive,
        );
      }
    } catch (e) {
      setState(() {
        _totalSearchMatches = 0;
        _currentSearchMatchIndex = -1;
      });
      return;
    }

    final matches = searchExp.allMatches(_editController.text).toList();
    setState(() {
      _totalSearchMatches = matches.length;
      if (_totalSearchMatches > 0) {
        if (_currentSearchMatchIndex >= _totalSearchMatches ||
            _currentSearchMatchIndex < 0) {
          _currentSearchMatchIndex = 0;
        }
      } else {
        _currentSearchMatchIndex = -1;
      }

      _editController.searchQuery = _searchQuery;
      _editController.caseSensitive = _searchCaseSensitive;
      _editController.useRegex = _searchUseRegex;
      _editController.currentMatchIndex = _currentSearchMatchIndex;
    });
  }

  void _scrollToCurrentMatch() {
    if (_currentSearchMatchIndex < 0 || _totalSearchMatches == 0) return;

    RegExp searchExp;
    try {
      if (_searchUseRegex) {
        searchExp = RegExp(_searchQuery, caseSensitive: _searchCaseSensitive);
      } else {
        searchExp = RegExp(
          RegExp.escape(_searchQuery),
          caseSensitive: _searchCaseSensitive,
        );
      }
    } catch (e) {
      return;
    }

    final matches = searchExp.allMatches(_editController.text).toList();
    if (_currentSearchMatchIndex < matches.length) {
      final match = matches[_currentSearchMatchIndex];

      // Calculate line number for editor scroll
      final textBeforeMatch = _editController.text.substring(0, match.start);
      final lineIndex = '\n'.allMatches(textBeforeMatch).length;

      // Editor Scroll
      if (_isEditing && _editorScrollController.hasClients) {
        final double lineHeight = 15 * 1.5; // FontSize * height
        final double targetOffset = lineIndex * lineHeight;
        final viewportHeight =
            _editorScrollController.position.viewportDimension;
        final centeredOffset = targetOffset - (viewportHeight / 2);
        _editorScrollController.jumpTo(
          centeredOffset.clamp(
            0.0,
            _editorScrollController.position.maxScrollExtent,
          ),
        );

        // Select text in editor
        _editController.selection = TextSelection(
          baseOffset: match.start,
          extentOffset: match.end,
        );
      }

      // Preview Scroll
      if (!_isEditing && _scrollController.hasClients) {
        final totalLines = '\n'.allMatches(_editController.text).length + 1;
        final percentage = lineIndex / totalLines;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final viewportHeight = _scrollController.position.viewportDimension;
        if (maxScroll > 0) {
          final targetY = percentage * (maxScroll + viewportHeight);
          final centeredOffset = targetY - (viewportHeight / 2);
          _scrollController.jumpTo(centeredOffset.clamp(0.0, maxScroll));
        }
      }
    }
  }

  void _onSearchNext() {
    if (_totalSearchMatches > 0 &&
        _currentSearchMatchIndex < _totalSearchMatches - 1) {
      setState(() {
        _currentSearchMatchIndex = _currentSearchMatchIndex + 1;
        _editController.currentMatchIndex = _currentSearchMatchIndex;
      });
      _scrollToCurrentMatch();
    }
  }

  void _onSearchPrev() {
    if (_totalSearchMatches > 0 && _currentSearchMatchIndex > 0) {
      setState(() {
        _currentSearchMatchIndex = _currentSearchMatchIndex - 1;
        _editController.currentMatchIndex = _currentSearchMatchIndex;
      });
      _scrollToCurrentMatch();
    }
  }

  void _replaceCurrentMatch(String replacement) {
    if (_currentSearchMatchIndex < 0 || _totalSearchMatches == 0) return;

    RegExp searchExp;
    try {
      if (_searchUseRegex) {
        searchExp = RegExp(_searchQuery, caseSensitive: _searchCaseSensitive);
      } else {
        searchExp = RegExp(
          RegExp.escape(_searchQuery),
          caseSensitive: _searchCaseSensitive,
        );
      }
    } catch (e) {
      return;
    }

    final matches = searchExp.allMatches(_editController.text).toList();
    if (_currentSearchMatchIndex < matches.length) {
      final match = matches[_currentSearchMatchIndex];
      final newText = _editController.text.replaceRange(
        match.start,
        match.end,
        replacement,
      );

      // Update text and keep cursor position
      final cursorOffset = match.start + replacement.length;
      _editController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );

      // Matches will be updated automatically via the listener
      setState(() => _hasChanges = true);
    }
  }

  void _replaceAllMatches(String replacement) {
    if (_totalSearchMatches == 0) return;

    RegExp searchExp;
    try {
      if (_searchUseRegex) {
        searchExp = RegExp(_searchQuery, caseSensitive: _searchCaseSensitive);
      } else {
        searchExp = RegExp(
          RegExp.escape(_searchQuery),
          caseSensitive: _searchCaseSensitive,
        );
      }
    } catch (e) {
      return;
    }

    final newText = _editController.text.replaceAll(searchExp, replacement);
    _editController.value = TextEditingValue(
      text: newText,
      selection: const TextSelection.collapsed(offset: 0),
    );

    setState(() => _hasChanges = true);
  }

  Widget _buildSearchOverlay() {
    return SearchReplaceOverlay(
      initialQuery: _searchQuery,
      initialCaseSensitive: _searchCaseSensitive,
      initialUseRegex: _searchUseRegex,
      totalMatches: _totalSearchMatches,
      currentMatchIndex: _currentSearchMatchIndex,
      isPreviewMode: !_isEditing && !_isDualPane,
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
          _updateSearchMatches();
          _scrollToCurrentMatch();
        });
      },
      onReplace: _replaceCurrentMatch,
      onReplaceAll: _replaceAllMatches,
      onNext: _onSearchNext,
      onPrev: _onSearchPrev,
      onClose: () => setState(() => _isSearchVisible = false),
      onCaseSensitiveChanged: (val) {
        setState(() {
          _searchCaseSensitive = val;
          _updateSearchMatches();
        });
      },
      onUseRegexChanged: (value) {
        setState(() {
          _searchUseRegex = value;
        });
        _updateSearchMatches();
      },
      onDragUpdate: (details) {
        final currentPos = _searchPosition.value;
        double newTop = (currentPos.top ?? 100.0) + details.delta.dy;

        double? newRight;
        double? newLeft = currentPos.left;

        if (currentPos.left == null) {
          newRight = (currentPos.right ?? 16.0) - details.delta.dx;
        } else {
          newLeft = currentPos.left! + details.delta.dx;
        }

        _searchPosition.value = _SearchPosition(
          top: newTop,
          right: newRight,
          left: newLeft,
        );
      },
    );
  }

  Widget _buildEditor() {
    return Container(
      color: const Color(0xFF181818), // Seamless background
      child: SingleChildScrollView(
        controller: _editorScrollController,
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: TextField(
                key: _editorKey,
                focusNode: _focusNode,
                controller: _editController,
                undoController: _undoController,
                scrollPhysics:
                    const NeverScrollableScrollPhysics(), // Managed by SingleChildScrollView
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFABB2BF),
                  fontSize: 15,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  // 56px for line numbers + 16px internal padding
                  contentPadding: EdgeInsets.fromLTRB(72, 24, 0, 24),
                  border: InputBorder.none,
                  hintText: 'Start typing...',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                cursorWidth: 2.0,
                cursorColor: const Color(0xFFA6E22E),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 56, // Line numbers column width
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.5,
                    ),
                  ),
                ),
                child: CustomPaint(
                  painter: LineNumbersPainter(
                    editorKey: _editorKey,
                    controller: _editController,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF495162),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    repaint: _lineNumbersRepaintNotifier,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdown() {
    String textToRender = _isEditing ? _previewContent : _content;

    // Frontmatter Parsing
    Map<String, String> frontmatter = {};
    List<String> tags = [];

    if (textToRender.startsWith('---\n')) {
      final endIdx = textToRender.indexOf('\n---\n', 4);
      if (endIdx != -1) {
        final fmString = textToRender.substring(4, endIdx);
        textToRender = textToRender.substring(endIdx + 5);

        for (final line in fmString.split('\n')) {
          final colonIdx = line.indexOf(':');
          if (colonIdx != -1) {
            final key = line.substring(0, colonIdx).trim();
            final value = line.substring(colonIdx + 1).trim();

            if (key == 'tags' && value.startsWith('[') && value.endsWith(']')) {
              final tagsStr = value.substring(1, value.length - 1);
              tags = tagsStr
                  .split(',')
                  .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
                  .toList();
            } else {
              frontmatter[key] = value;
            }
          }
        }
      }
    }

    // Pre-process Math and Mermaid
    String htmlContent = _processAdvancedMarkdown(textToRender);
    htmlContent = htmlContent.replaceAll(
      RegExp(
        r'<input[^>]*type="checkbox"[^>]*checked="(true|checked)"[^>]*>(?:</input>)?',
      ),
      '<task-checked></task-checked>',
    );
    htmlContent = htmlContent.replaceAll(
      RegExp(r'<input[^>]*type="checkbox"[^>]*>(?:</input>)?'),
      '<task-unchecked></task-unchecked>',
    );

    final htmlWidget = Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (frontmatter.isNotEmpty || tags.isNotEmpty)
                          _buildFrontmatterTable(frontmatter, tags),
                        if (frontmatter.isNotEmpty || tags.isNotEmpty)
                          const SizedBox(height: 32),
                        SelectionArea(
                          child: Container(
                            key: _htmlKey,
                            child: Html(
                              data: htmlContent,
                              style: _buildHtmlStyles(),
                              extensions: [
                                TagExtension(
                                  tagsToExtend: {"math-display"},
                                  builder: (context) {
                                    final mathCode =
                                        context.element?.text ?? '';
                                    return _buildMathJax(
                                      mathCode,
                                      display: true,
                                    );
                                  },
                                ),
                                TagExtension(
                                  tagsToExtend: {"math-inline"},
                                  builder: (context) {
                                    final mathCode =
                                        context.element?.text ?? '';
                                    return _buildMathJax(
                                      mathCode,
                                      display: false,
                                    );
                                  },
                                ),
                                TagExtension(
                                  tagsToExtend: {"mermaid"},
                                  builder: (context) {
                                    final mermaidCode =
                                        context.element?.text ?? '';
                                    return _buildMermaidDiagram(mermaidCode);
                                  },
                                ),
                                TagExtension(
                                  tagsToExtend: {"pre"},
                                  builder: (context) {
                                    final codeElement = context
                                        .element
                                        ?.children
                                        .where((e) => e.localName == 'code')
                                        .firstOrNull;
                                    if (codeElement != null) {
                                      final code = codeElement.text;
                                      final classes = codeElement.classes;
                                      String language = '';
                                      for (final c in classes) {
                                        if (c.startsWith('language-')) {
                                          language = c.replaceFirst(
                                            'language-',
                                            '',
                                          );
                                        }
                                      }
                                      return _buildCodeBlock(code, language);
                                    }
                                    return _buildCodeBlock(
                                      context.element?.text ?? '',
                                      '',
                                    );
                                  },
                                ),
                                TagExtension(
                                  tagsToExtend: {
                                    "task-checked",
                                    "task-unchecked",
                                  },
                                  builder: (context) {
                                    final checked =
                                        context.element?.localName ==
                                        'task-checked';
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                        top: 2.0,
                                      ),
                                      child: Icon(
                                        checked
                                            ? Icons.check_box_rounded
                                            : Icons
                                                  .check_box_outline_blank_rounded,
                                        color: checked
                                            ? const Color(0xFF64B5F6)
                                            : Colors.white54,
                                        size: 18,
                                      ),
                                    );
                                  },
                                ),
                                const TableHtmlExtension(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(scrollbars: !_isDualPane),
      child: Listener(
        onPointerDown: (details) => _pointerDownPosition = details.position,
        onPointerUp: (details) {
          if (_pointerDownPosition != null &&
              (details.position - _pointerDownPosition!).distance < 5.0) {
            final now = DateTime.now();
            if (_lastClickTime == null ||
                now.difference(_lastClickTime!).inMilliseconds > 300) {
              _lastClickTime = now;
              return; // Wait for double click
            }
            _lastClickTime = null; // Reset

            if (!_isDualPane) {
              // 1. Walk the Render Tree to find the RenderParagraph closest to the click Y-coordinate
              // MUST DO THIS BEFORE setState DESTROYS THE PREVIEW WIDGET!
              String? clickedText;
              double? finalMinDistance;
              if (_htmlKey.currentContext?.findRenderObject() != null) {
                final rootRenderObject = _htmlKey.currentContext!
                    .findRenderObject()!;
                final List<dynamic> paragraphs = [];

                void walk(RenderObject object) {
                  try {
                    final dynamic dynObj = object;
                    String textStr = '';
                    try {
                      textStr = dynObj.text.toPlainText();
                    } catch (_) {
                      try {
                        textStr = dynObj.text.toString();
                      } catch (_) {}
                    }
                    if (textStr.trim().isNotEmpty && textStr.trim() != 'null') {
                      paragraphs.add(object);
                    }
                  } catch (e) {}
                  object.visitChildren(walk);
                }

                walk(rootRenderObject);

                final htmlBox =
                    _htmlKey.currentContext!.findRenderObject() as RenderBox?;
                if (htmlBox == null) return;
                final localPos = htmlBox.globalToLocal(details.position);

                dynamic closestParagraph;
                double minDistance = double.infinity;

                for (final p in paragraphs) {
                  try {
                    final RenderBox box = p as RenderBox;
                    final offset = box.localToGlobal(Offset.zero);
                    final yCenter = offset.dy + (box.size.height / 2);
                    final distance = (yCenter - details.position.dy).abs();

                    String textStr = '';
                    try {
                      textStr = (p as dynamic).text.toPlainText();
                    } catch (_) {
                      try {
                        textStr = (p as dynamic).text.toString();
                      } catch (_) {}
                    }
                    final text = textStr.trim();
                    if (text.isNotEmpty &&
                        text != 'null' &&
                        distance < minDistance) {
                      minDistance = distance;
                      closestParagraph = p;
                    }
                  } catch (e) {}
                }

                if (closestParagraph != null) {
                  try {
                    try {
                      clickedText = (closestParagraph as dynamic).text
                          .toPlainText();
                    } catch (_) {
                      try {
                        clickedText = (closestParagraph as dynamic).text
                            .toString();
                      } catch (_) {}
                    }
                  } catch (e) {}
                }
              }

              if (clickedText == null) return;
              clickedText = clickedText.trim();
              if (clickedText.isEmpty) return;

              final maxScrollExt = _scrollController.hasClients
                  ? _scrollController.position.maxScrollExtent
                  : 0;
              final viewHeight = _scrollController.hasClients
                  ? _scrollController.position.viewportDimension
                  : 1;

              double scrollPercentage = 0;
              if (maxScrollExt > 0) {
                final absoluteY =
                    _scrollController.offset + details.localPosition.dy;
                scrollPercentage = absoluteY / (maxScrollExt + viewHeight);
              } else {
                scrollPercentage = details.localPosition.dy / viewHeight;
              }

              setState(() {
                _isEditing = true;
              });
              _focusNode.requestFocus();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_editorScrollController.hasClients) {
                  final lines = _editController.text.split('\n');

                  int targetLineIndex = -1;

                  if (clickedText!.isNotEmpty) {
                    final sanitizedTarget = clickedText!.replaceAll(
                      RegExp(r'[\s\*_#>`~\-\+]'),
                      '',
                    );
                    final searchSnippet = sanitizedTarget.length > 50
                        ? sanitizedTarget.substring(0, 50)
                        : sanitizedTarget;

                    int bestMatchIndex = -1;
                    int closestDistance = 999999;

                    int expectedIndex = (scrollPercentage * lines.length)
                        .toInt();

                    for (int i = 0; i < lines.length; i++) {
                      final sanitizedLine = lines[i].replaceAll(
                        RegExp(r'[\s\*_#>`~\-\+]'),
                        '',
                      );
                      if (sanitizedLine.contains(searchSnippet) ||
                          searchSnippet.contains(sanitizedLine)) {
                        if (sanitizedLine.isEmpty && searchSnippet.isNotEmpty)
                          continue;
                        int distance = (i - expectedIndex).abs();
                        if (distance < closestDistance) {
                          closestDistance = distance;
                          bestMatchIndex = i;
                        }
                      }
                    }

                    if (bestMatchIndex != -1) {
                      targetLineIndex = bestMatchIndex;
                    } else {
                      targetLineIndex = expectedIndex;
                    }
                  } else {
                    targetLineIndex = (scrollPercentage * lines.length).toInt();
                  }

                  targetLineIndex = targetLineIndex.clamp(0, lines.length - 1);

                  int charOffset = 0;
                  for (int i = 0; i < targetLineIndex; i++) {
                    charOffset += lines[i].length + 1;
                  }

                  int lineLength = 0;
                  if (targetLineIndex < lines.length) {
                    lineLength = lines[targetLineIndex].length;
                  }
                  _editController.selection = TextSelection(
                    baseOffset: charOffset,
                    extentOffset: charOffset + lineLength,
                  );

                  // 4. Scroll the editor exactly to that line
                  final textStyle = const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    height: 1.5,
                  );
                  final textPainter = TextPainter(
                    text: TextSpan(text: '1', style: textStyle),
                    textDirection: TextDirection.ltr,
                    strutStyle: const StrutStyle(
                      fontSize: 15,
                      height: 1.5,
                      forceStrutHeight: true,
                    ),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final exactLineHeight = textPainter.preferredLineHeight;

                  final targetEditorAbsoluteY =
                      targetLineIndex * exactLineHeight;
                  final edMaxExt =
                      _editorScrollController.position.maxScrollExtent;
                  // Subtract localPosition.dy to keep the physical screen position identical
                  final targetOffset =
                      (targetEditorAbsoluteY - details.localPosition.dy).clamp(
                        0.0,
                        edMaxExt,
                      );

                  _editorScrollController.jumpTo(targetOffset);
                }
              });
            }
          } // <--- Added closing brace for if (_pointerDownPosition != null ...)
        },
        child: htmlWidget,
      ),
    );
  }

  String _processAdvancedMarkdown(String mdText) {
    // 1. Extract Mermaid Blocks
    final mermaidBlocks = <String>[];
    mdText = mdText.replaceAllMapped(
      RegExp(
        r'(?:```|~~~)[Mm]ermaid[ \t]*\r?\n(.*?)\r?\n[ \t]*(?:```|~~~)',
        dotAll: true,
        caseSensitive: false,
      ),
      (match) {
        final code = match.group(1) ?? '';
        final id = mermaidBlocks.length;
        mermaidBlocks.add(code);
        return '%%%MERMAID_$id%%%';
      },
    );

    // 2. Display Math
    mdText = mdText.replaceAllMapped(RegExp(r'\$\$(.*?)\$\$', dotAll: true), (
      match,
    ) {
      return '<math-display>${match.group(1)}</math-display>';
    });

    // 3. Inline Math
    mdText = mdText.replaceAllMapped(RegExp(r'\$([^\$]+)\$'), (match) {
      return '<math-inline>${match.group(1)}</math-inline>';
    });

    // Convert to HTML using Dart markdown package
    String html = md.markdownToHtml(
      mdText,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );

    // Restore Mermaid Blocks
    for (int i = 0; i < mermaidBlocks.length; i++) {
      // Escape the code so HTML parsing doesn't break on < or > inside mermaid
      final escapedCode = const HtmlEscape().convert(mermaidBlocks[i]);
      // markdownToHtml might wrap our placeholder in a paragraph
      html = html.replaceAll(
        '<p>%%%MERMAID_$i%%%</p>',
        '<mermaid>$escapedCode</mermaid>',
      );
      html = html.replaceAll(
        '%%%MERMAID_$i%%%',
        '<mermaid>$escapedCode</mermaid>',
      );
    }

    if (_searchQuery.isNotEmpty && !_isEditing) {
      html = HtmlSearchHighlighter.highlightMatches(
        html,
        _searchQuery,
        caseSensitive: _searchCaseSensitive,
        useRegex: _searchUseRegex,
        currentMatchIndex: _currentSearchMatchIndex,
      );
    }

    return html;
  }

  Widget _buildFrontmatterTable(
    Map<String, String> frontmatter,
    List<String> tags,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        children: [
          ...frontmatter.entries.map(
            (e) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    e.key,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    e.value,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (tags.isNotEmpty)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'tags',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64B5F6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMathJax(String mathText, {required bool display}) {
    try {
      return Container(
        margin: display
            ? const EdgeInsets.symmetric(vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 4),
        alignment: display ? Alignment.center : null,
        child: Math.tex(
          mathText.trim(),
          mathStyle: display ? MathStyle.display : MathStyle.text,
          textStyle: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    } catch (e) {
      return Text(
        mathText,
        style: const TextStyle(
          color: Colors.white70,
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  TextSpan _highlightMermaidSyntax(String code) {
    final List<TextSpan> spans = [];
    final regex = RegExp(
      r'(\b(?:sequenceDiagram|autonumber|actor|participant)\b)|(->>|-->|-->>|-)|(\(.*?\))',
    );

    code.trim().splitMapJoin(
      regex,
      onMatch: (Match match) {
        if (match.group(1) != null) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64B5F6)),
            ),
          );
        } else if (match.group(2) != null) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: GoogleFonts.jetBrainsMono(color: Colors.white70),
            ),
          );
        } else if (match.group(3) != null) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFFAED581)),
            ),
          );
        }
        return '';
      },
      onNonMatch: (String text) {
        spans.add(
          TextSpan(
            text: text,
            style: GoogleFonts.jetBrainsMono(color: Colors.white),
          ),
        );
        return '';
      },
    );

    return TextSpan(
      children: spans,
      style: GoogleFonts.jetBrainsMono(fontSize: 14, height: 1.5),
    );
  }

  Widget _buildMermaidDiagram(String code) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!_mermaidFutures.containsKey(code)) {
      _mermaidFutures[code] = MermaidOfflineRenderer.renderToPng(
        code,
        isDarkMode: isDarkMode,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _mermaidFutures[code],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Rendering diagram offline...',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withOpacity(0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Failed to render diagram. Showing source code.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCodeBlock(code, 'mermaid'),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, Style> _buildHtmlStyles() {
    return {
      "body": Style(
        color: const Color(0xFFD0D0D0),
        fontFamily: 'Inter',
        fontSize: FontSize(16.0),
        lineHeight: LineHeight.number(1.6),
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      "h1": Style(
        color: Colors.white,
        fontSize: FontSize(32.0),
        fontWeight: FontWeight.w800,
        margin: Margins.only(top: 32.0, bottom: 16.0),
      ),
      "h2": Style(
        color: Colors.white,
        fontSize: FontSize(26.0),
        fontWeight: FontWeight.w700,
        margin: Margins.only(top: 28.0, bottom: 16.0),
      ),
      "h3": Style(
        color: Colors.white,
        fontSize: FontSize(22.0),
        fontWeight: FontWeight.w600,
        margin: Margins.only(top: 24.0, bottom: 12.0),
      ),
      "h4": Style(
        color: Colors.white.withOpacity(0.9),
        fontSize: FontSize(18.0),
        fontWeight: FontWeight.w600,
        margin: Margins.only(top: 20.0, bottom: 12.0),
      ),
      "p": Style(
        margin: Margins.only(bottom: 16.0),
      ),
      "li": Style(
        margin: Margins.only(bottom: 8.0),
      ),
      "table": Style(
        backgroundColor: Colors.transparent,
        margin: Margins.only(bottom: 24.0),
        width: Width.auto(),
      ),
      "th": Style(
        padding: HtmlPaddings.all(12.0),
        backgroundColor: const Color(0xFF1E293B),
        fontWeight: FontWeight.w600,
        color: Colors.white,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      "td": Style(
        padding: HtmlPaddings.all(12.0),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        backgroundColor: const Color(0xFF16161E).withOpacity(0.5),
      ),
      "kbd": Style(
        backgroundColor: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        padding: HtmlPaddings.symmetric(horizontal: 6.0, vertical: 2.0),
        margin: Margins.symmetric(horizontal: 2.0),
        color: Colors.white,
        fontFamily: 'JetBrains Mono',
        fontSize: FontSize(13.0),
      ),
      "mark": Style(
        backgroundColor: Colors.yellow.withOpacity(0.3),
        color: Colors.white,
      ),
      "code": Style(
        backgroundColor: Colors.white.withOpacity(0.05),
        color: const Color(0xFFE2B4FF),
        fontFamily: 'JetBrains Mono',
        fontSize: FontSize(14.0),
        padding: HtmlPaddings.symmetric(horizontal: 6.0, vertical: 2.0),
      ),
      "pre": Style(
        backgroundColor: Colors.black.withOpacity(0.4),
        padding: HtmlPaddings.zero,
        margin: Margins.only(top: 16.0, bottom: 24.0),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      "blockquote": Style(
        margin: Margins.only(left: 0, right: 0, bottom: 16.0),
        padding: HtmlPaddings.only(left: 16.0, top: 4.0, bottom: 4.0),
        border: Border(
          left: BorderSide(color: const Color(0xFF64B5F6), width: 4.0),
        ),
        color: Colors.white.withOpacity(0.6),
        fontStyle: FontStyle.italic,
      ),
      "a": Style(
        color: const Color(0xFF64B5F6),
        textDecoration: TextDecoration.none,
      ),
    };
  }

  Widget _buildCodeBlock(String code, String language) {
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
            color: const Color(0xFFCE93D8),
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
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
          // Code Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: HighlightView(
              code.trim(),
              language: language.isNotEmpty ? language : 'markdown',
              theme: {
                ...atomOneDarkTheme,
                'root': TextStyle(
                  color: atomOneDarkTheme['root']?.color,
                  backgroundColor: Colors.transparent,
                ),
              },
              padding: const EdgeInsets.all(0),
              textStyle: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                height: 1.5,
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
              color: _copied ? const Color(0xFFA6E22E) : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              _copied ? 'COPIED' : 'COPY',
              style: GoogleFonts.outfit(
                color: _copied ? const Color(0xFFA6E22E) : Colors.white38,
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

class _SearchPosition {
  final double? top;
  final double? right;
  final double? left;
  final double? bottom;
  const _SearchPosition({this.top, this.right, this.left, this.bottom});
}
