import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';
import 'package:path/path.dart' as p;

/// Complete interactive comparison results view.
///
/// Features summary header statistics, virtualized lazy group rendering,
/// expand/collapse all controls, and an informative empty state.
class CompareResultsView extends StatefulWidget {
  const CompareResultsView({
    required this.result,
    this.sourceFolder,
    this.destinationFolder,
    this.onNewComparison,
    this.onOpenFile,
    this.onLocateFile,
    super.key,
  });

  final ComparisonResult result;
  final String? sourceFolder;
  final String? destinationFolder;
  final VoidCallback? onNewComparison;
  final void Function(String filePath)? onOpenFile;
  final void Function(String filePath)? onLocateFile;

  @override
  State<CompareResultsView> createState() => _CompareResultsViewState();
}

class _CompareResultsViewState extends State<CompareResultsView> {
  final Set<String> _collapsedSourcePaths = {};
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isCtrl) return false;

    if (event.logicalKey == LogicalKeyboardKey.bracketRight ||
        event.physicalKey == PhysicalKeyboardKey.bracketRight) {
      _collapseAll();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.bracketLeft ||
        event.physicalKey == PhysicalKeyboardKey.bracketLeft) {
      _expandAll();
      return true;
    }

    return false;
  }

  String get _effectiveSourceFolder {
    if (widget.sourceFolder != null && widget.sourceFolder!.isNotEmpty) {
      return widget.sourceFolder!;
    }
    if (widget.result.matches.isNotEmpty) {
      return p.dirname(widget.result.matches.first.sourcePath);
    }
    return '';
  }

  String get _effectiveDestinationFolder {
    if (widget.destinationFolder != null &&
        widget.destinationFolder!.isNotEmpty) {
      return widget.destinationFolder!;
    }
    if (widget.result.matches.isNotEmpty &&
        widget.result.matches.first.destinationMatches.isNotEmpty) {
      return p.dirname(
        widget.result.matches.first.destinationMatches.first.destinationPath,
      );
    }
    return '';
  }

  bool get _isAllCollapsed =>
      widget.result.matches.isNotEmpty &&
      widget.result.matches.every(
        (m) => _collapsedSourcePaths.contains(m.sourcePath),
      );

  void _collapseAll() {
    setState(() {
      _collapsedSourcePaths.addAll(
        widget.result.matches.map((m) => m.sourcePath),
      );
    });
  }

  void _expandAll() {
    setState(_collapsedSourcePaths.clear);
  }

  void _toggleAll() {
    setState(() {
      if (_isAllCollapsed) {
        _collapsedSourcePaths.clear();
      } else {
        _collapsedSourcePaths.addAll(
          widget.result.matches.map((m) => m.sourcePath),
        );
      }
    });
  }

  void _toggleGroup(String sourcePath) {
    setState(() {
      if (_collapsedSourcePaths.contains(sourcePath)) {
        _collapsedSourcePaths.remove(sourcePath);
      } else {
        _collapsedSourcePaths.add(sourcePath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.isEmpty) {
      return _buildEmptyState();
    }

    final totalGroups = widget.result.matches.length;
    final totalDests = widget.result.matches.fold<int>(
      0,
      (sum, m) => sum + m.matchCount,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.bracketRight, control: true):
            _collapseAll,
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            _collapseAll,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true):
            _expandAll,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            _expandAll,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Column(
          children: [
            // Top Summary & Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF161616),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  // Summary stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$totalGroups Duplicate ${totalGroups == 1 ? 'Group' : 'Groups'} Found',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.violet.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalDests Total ${totalDests == 1 ? 'Match' : 'Matches'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.violet,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.result.totalSourceCandidates} source / '
                        '${widget.result.totalDestinationCandidates} destination candidates evaluated'
                        '${widget.result.failures.isNotEmpty ? ' (${widget.result.failures.length} errors)' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  // Controls: Expand/Collapse All
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _toggleAll,
                        icon: Icon(
                          _isAllCollapsed
                              ? Icons.unfold_more_rounded
                              : Icons.unfold_less_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        label: Text(
                          _isAllCollapsed ? 'Expand All' : 'Collapse All',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Section Headers for Source & Destination
            if (_effectiveSourceFolder.isNotEmpty ||
                _effectiveDestinationFolder.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF161616),
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;
                    final sourceHeader = _buildSectionHeader(
                      label: 'SOURCE FOLDER',
                      path: _effectiveSourceFolder,
                      accentColor: AppColors.violet,
                      icon: Icons.folder_rounded,
                    );
                    final destHeader = _buildSectionHeader(
                      label: 'DESTINATION FOLDER',
                      path: _effectiveDestinationFolder,
                      accentColor: Colors.tealAccent,
                      icon: Icons.folder_copy_rounded,
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: sourceHeader),
                          const SizedBox(width: 52),
                          Expanded(child: destHeader),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sourceHeader,
                        const SizedBox(height: 6),
                        destHeader,
                      ],
                    );
                  },
                ),
              ),
            // Virtualized Results List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.result.matches.length,
                itemBuilder: (context, index) {
                  final match = widget.result.matches[index];
                  final isExpanded = !_collapsedSourcePaths.contains(
                    match.sourcePath,
                  );

                  return DuplicateGroupCard(
                    key: ValueKey(match.sourcePath),
                    match: match,
                    isExpanded: isExpanded,
                    onToggleExpanded: () => _toggleGroup(match.sourcePath),
                    onOpenFile: widget.onOpenFile,
                    onLocateFile: widget.onLocateFile,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required String path,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 15),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.greenAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Duplicates Found',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Analyzed ${widget.result.totalSourceCandidates} source and '
                '${widget.result.totalDestinationCandidates} destination candidates. '
                'No matching duplicates detected.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
