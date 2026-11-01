import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/file_comparison_tile.dart';
import 'package:path/path.dart' as p;

/// Card representing a single duplicate group: one source candidate matching one
/// or more destination candidate files.
///
/// Features side-by-side visual comparison, expandable/collapsible details, and
/// clear match status indicators.
class DuplicateGroupCard extends StatelessWidget {
  const DuplicateGroupCard({
    required this.match,
    this.isExpanded = true,
    this.onToggleExpanded,
    this.onOpenFile,
    super.key,
  });

  final DuplicateMatch match;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final void Function(String filePath)? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(match.sourcePath);
    final count = match.matchCount;
    final primaryPair = match.destinationMatches.isNotEmpty
        ? match.destinationMatches.first
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_copy_rounded,
                    color: AppColors.violet,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  // Source file name
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Match count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count ${count == 1 ? 'Match' : 'Matches'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Primary match type badge
                  if (primaryPair != null) ...[
                    _buildPrimaryBadge(primaryPair),
                    const SizedBox(width: 8),
                  ],
                  // Expand / Collapse Chevron Button
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'Toggle Group',
                    onPressed: onToggleExpanded,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          // Collapsible Comparison Details
          if (isExpanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final sourceTile = FileComparisonTile(
                    filePath: match.sourcePath,
                    isSource: true,
                    onOpen: onOpenFile != null
                        ? () => onOpenFile!(match.sourcePath)
                        : null,
                  );

                  final destinationTiles = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var i = 0;
                        i < match.destinationMatches.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(height: 8),
                        FileComparisonTile(
                          filePath: match.destinationMatches[i].destinationPath,
                          isSource: false,
                          matchType: match.destinationMatches[i].matchType,
                          similarityScore:
                              match.destinationMatches[i].similarityScore,
                          onOpen: onOpenFile != null
                              ? () => onOpenFile!(
                                  match.destinationMatches[i].destinationPath,
                                )
                              : null,
                        ),
                      ],
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sourceTile),
                        const SizedBox(width: 14),
                        const Center(
                          child: Icon(
                            Icons.compare_arrows_rounded,
                            color: Colors.white24,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: destinationTiles),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sourceTile,
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white24,
                            size: 20,
                          ),
                        ),
                      ),
                      destinationTiles,
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryBadge(MatchedPair pair) {
    final isExact = pair.matchType == MatchType.exact;
    final color = isExact ? Colors.greenAccent : Colors.amberAccent;
    final text = isExact
        ? 'Exact Match'
        : '${(pair.similarityScore * 100).toInt()}% Similarity';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
