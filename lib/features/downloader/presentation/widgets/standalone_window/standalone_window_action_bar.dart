import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';

class StandaloneWindowActionBar extends StatelessWidget {
  const StandaloneWindowActionBar({
    super.key,
    required this.isTrashView,
    required this.trashNotEmpty,
    required this.hasItems,
    required this.currentGroup,
    required this.importedListName,
    required this.config,
    required this.rootIndex,
    required this.onRestoreAll,
    required this.onEmptyTrash,
    required this.onBackToRoot,
    required this.onClear,
    required this.onFormatChanged,
    required this.onFilterChanged,
    required this.matchTargetFormat,
    required this.getHeight,
  });

  final bool isTrashView;
  final bool trashNotEmpty;
  final bool hasItems;
  final MediaGroup? currentGroup;
  final String? importedListName;
  final DownloadConfig? config;
  final int? rootIndex;

  final VoidCallback onRestoreAll;
  final VoidCallback onEmptyTrash;
  final VoidCallback onBackToRoot;
  final VoidCallback onClear;
  final ValueChanged<MediaFormat> onFormatChanged;
  final ValueChanged<GroupDownloadType> onFilterChanged;
  final MediaFormat? Function(MediaInfo, MediaFormat?) matchTargetFormat;
  final int Function(String) getHeight;

  @override
  Widget build(BuildContext context) {
    if (isTrashView) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Trash',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trashNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Restore All'),
                onPressed: onRestoreAll,
                style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.violet,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Empty'),
                onPressed: onEmptyTrash,
                style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.error,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (currentGroup != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: onBackToRoot,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: InkWell(
                      onTap: onBackToRoot,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          importedListName ?? 'Default List',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.chevron_right, color: Colors.white54),
                  ),
                  Expanded(
                    child: Text(
                      currentGroup!.first.title.isNotEmpty
                          ? currentGroup!.first.title
                          : 'Group',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      importedListName ?? 'Default List',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasItems) ...[
            if (currentGroup != null &&
                config != null &&
                rootIndex != null &&
                rootIndex != -1) ...[
              if (currentGroup!.first.isPlaylist)
                SizedBox(
                  width: 140,
                  height: 36,
                  child: FormatSelectionDropdown(
                    item: currentGroup!.first,
                    config: config!,
                    index: rootIndex!,
                    group: currentGroup,
                    getHeight: getHeight,
                    matchTargetFormat: matchTargetFormat,
                    onChanged: onFormatChanged,
                  ),
                )
              else
                SizedBox(
                  width: 140,
                  height: 36,
                  child: GroupFilterDropdown(
                    selectedFilter: config!.groupFilter,
                    isEnabled:
                        currentGroup!.first.isProfile ||
                        (currentGroup!.items.any((i) => !i.isVideo) &&
                            currentGroup!.items.any((i) => i.isVideo)),
                    onChanged: onFilterChanged,
                  ),
                ),
              const SizedBox(width: 16),
            ],
            SizedBox(
              height: 36,
              child: TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Clear',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
