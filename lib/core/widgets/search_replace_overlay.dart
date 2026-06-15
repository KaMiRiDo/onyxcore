import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

class SearchReplaceOverlay extends StatefulWidget {
  final String initialQuery;
  final bool initialCaseSensitive;
  final bool initialUseRegex;
  final int totalMatches;
  final int currentMatchIndex;
  final bool isPreviewMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onReplace;
  final ValueChanged<String> onReplaceAll;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;
  final ValueChanged<bool> onCaseSensitiveChanged;
  final ValueChanged<bool> onUseRegexChanged;
  final GestureDragUpdateCallback? onDragUpdate;

  const SearchReplaceOverlay({
    Key? key,
    required this.initialQuery,
    required this.initialCaseSensitive,
    required this.initialUseRegex,
    required this.totalMatches,
    required this.currentMatchIndex,
    required this.isPreviewMode,
    required this.onSearchChanged,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
    required this.onCaseSensitiveChanged,
    required this.onUseRegexChanged,
    this.onDragUpdate,
  }) : super(key: key);

  @override
  State<SearchReplaceOverlay> createState() => _SearchReplaceOverlayState();
}

class _SearchReplaceOverlayState extends State<SearchReplaceOverlay> {
  late TextEditingController _searchController;
  late TextEditingController _replaceController;
  late FocusNode _searchFocusNode;
  bool _isReplaceExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _replaceController = TextEditingController();
    _searchFocusNode = FocusNode();

    // Auto-focus the search field when the overlay opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(SearchReplaceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        _searchController.text != widget.initialQuery) {
      _searchController.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMatches = widget.totalMatches > 0;
    final bool isSearchEmpty = _searchController.text.isEmpty;
    final bool canGoPrev = hasMatches && widget.currentMatchIndex > 0;
    final bool canGoNext =
        hasMatches && widget.currentMatchIndex < widget.totalMatches - 1;

    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: const Color(0xFF282828), // Darker grey for overlay
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.onDragUpdate != null)
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                onPanUpdate: widget.onDragUpdate,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(
                    Icons.drag_indicator,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSearchBox(canGoNext, canGoPrev),
                    ),
                    const SizedBox(width: 8),
                    // Nav buttons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIconButton(
                            icon: Icons.keyboard_arrow_up,
                            onPressed: canGoPrev ? widget.onPrev : null,
                            tooltip: 'Previous Match (Shift+Enter)',
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: Colors.white24,
                          ),
                          _buildIconButton(
                            icon: Icons.keyboard_arrow_down,
                            onPressed: canGoNext ? widget.onNext : null,
                            tooltip: 'Next Match (Enter)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.isPreviewMode)
                      _buildIconButton(
                        icon: Icons.find_replace,
                        isActive: _isReplaceExpanded,
                        onPressed: () {
                          setState(() {
                            _isReplaceExpanded = !_isReplaceExpanded;
                          });
                        },
                        tooltip: 'Toggle Replace',
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    if (!widget.isPreviewMode) const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.close,
                      onPressed: widget.onClose,
                      tooltip: 'Close (Esc)',
                    ),
                  ],
                ),
                if (_isReplaceExpanded && !widget.isPreviewMode) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReplaceBox(),
                      ),
                      const SizedBox(width: 8),
                      _buildTextButton('Replace', () {
                        if (hasMatches) {
                          widget.onReplace(_replaceController.text);
                        }
                      }, enabled: hasMatches),
                      const SizedBox(width: 8),
                      _buildTextButton('Replace All', () {
                        if (hasMatches) {
                          widget.onReplaceAll(_replaceController.text);
                        }
                      }, enabled: hasMatches),
                    ],
                  ),
                ],
                if (!isSearchEmpty && widget.totalMatches == 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white54,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'No results',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(bool canGoNext, bool canGoPrev) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): canGoNext
                    ? widget.onNext
                    : () {},
                const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                    canGoPrev ? widget.onPrev : () {},
                const SingleActivator(LogicalKeyboardKey.escape):
                    widget.onClose,
              },
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'Find',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white38,
                  ),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                widget.totalMatches > 0
                    ? '${widget.currentMatchIndex + 1} of ${widget.totalMatches}'
                    : '0 of 0',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ),
          _buildToggleIcon(
            label: 'Aa',
            isActive: widget.initialCaseSensitive,
            onTap: () =>
                widget.onCaseSensitiveChanged(!widget.initialCaseSensitive),
            tooltip: 'Match Case',
          ),
          const SizedBox(width: 4),
          _buildToggleIcon(
            label: '.*',
            isActive: widget.initialUseRegex,
            onTap: () => widget.onUseRegexChanged(!widget.initialUseRegex),
            tooltip: 'Use Regular Expression',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildReplaceBox() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.edit, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  if (widget.totalMatches > 0)
                    widget.onReplace(_replaceController.text);
                },
                const SingleActivator(LogicalKeyboardKey.escape):
                    widget.onClose,
              },
              child: TextField(
                controller: _replaceController,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'Replace',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
    Color? backgroundColor,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: onPressed == null
                  ? Colors.white24
                  : isActive
                  ? const Color(0xFFA6E22E)
                  : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleIcon({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? const Color(0xFFA6E22E) : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextButton(
    String text,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return Material(
      color: Colors.white.withOpacity(enabled ? 0.05 : 0.02),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: enabled ? Colors.white : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}
