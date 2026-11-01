import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';

/// Complete interactive comparison results view.
///
/// Features summary header statistics, virtualized lazy group rendering,
/// expand/collapse all controls, and an informative empty state.
class CompareResultsView extends StatefulWidget {
  const CompareResultsView({
    required this.result,
    this.onNewComparison,
    this.onOpenFile,
    super.key,
  });

  final ComparisonResult result;
  final VoidCallback? onNewComparison;
  final void Function(String filePath)? onOpenFile;

  @override
  State<CompareResultsView> createState() => _CompareResultsViewState();
}

class _CompareResultsViewState extends State<CompareResultsView> {
  final Set<String> _collapsedSourcePaths = {};

  bool get _isAllCollapsed =>
      widget.result.matches.isNotEmpty &&
      widget.result.matches.every(
        (m) => _collapsedSourcePaths.contains(m.sourcePath),
      );

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

    return Column(
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
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$totalGroups Duplicate ${totalGroups == 1 ? 'Group' : 'Groups'}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
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
              // Controls: Expand/Collapse All and New Comparison
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onNewComparison,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'New Comparison',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: Colors.greenAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Duplicates Found',
                style: GoogleFonts.inter(
                  fontSize: 20,
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
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: widget.onNewComparison,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'New Comparison',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
