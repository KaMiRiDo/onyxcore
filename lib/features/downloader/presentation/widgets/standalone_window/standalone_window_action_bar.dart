import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloader_filter_overlay.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';

class StandaloneWindowActionBar extends StatelessWidget {
  const StandaloneWindowActionBar({
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
    required this.searchController,
    required this.searchFocusNode,
    required this.isSearchVisible,
    this.listFilter = 'added_desc',
    this.onListFilterChanged,
    this.sortOrder = 'added_desc',
    this.onSortChanged,
    this.filterSettings = const DownloaderFilterSettings(),
    this.onFilterSettingsChanged,
    this.availableTypes = const {},
    this.availableDates = const {},
    this.availableDatesByType = const {},
    this.hasImages = true,
    this.hasVideos = true,
    this.hasPlaylists = true,
    this.hasProfiles = true,
    this.hasGroups = true,
    this.activeTagNotifier,
    this.onTagTap,
    this.onTagSecondaryTapDown,
    super.key,
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
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isSearchVisible;
  final String listFilter;
  final ValueChanged<String>? onListFilterChanged;
  final String sortOrder;
  final ValueChanged<String>? onSortChanged;
  final DownloaderFilterSettings filterSettings;
  final ValueChanged<DownloaderFilterSettings>? onFilterSettingsChanged;
  final Set<DownloaderItemType> availableTypes;
  final Set<DateTime> availableDates;
  final Map<DownloaderItemType, Set<DateTime>> availableDatesByType;
  final bool hasImages;
  final bool hasVideos;
  final bool hasPlaylists;
  final bool hasProfiles;
  final bool hasGroups;
  final ValueNotifier<Map<String, String>?>? activeTagNotifier;
  final void Function(String url, String sort)? onTagTap;
  final void Function(TapDownDetails details, String url)? onTagSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final isSmallWindow = MediaQuery.of(context).size.width < 1100;
    
    if (isTrashView) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallWindow ? 8 : 12),
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
                  fontSize: isSmallWindow ? 14 : 18,
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallWindow ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
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
                                fontSize: isSmallWindow ? 13 : 16,
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
                            fontSize: isSmallWindow ? 14 : 18,
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
                            fontSize: isSmallWindow ? 14 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (activeTagNotifier != null)
                      ValueListenableBuilder<Map<String, String>?>(
                        valueListenable: activeTagNotifier!,
                        builder: (context, activeTag, child) {
                          if (activeTag == null) return const SizedBox.shrink();
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.chevron_right, color: Colors.white54),
                              ),
                              GestureDetector(
                                onTap: () => onTagTap?.call(activeTag['url']!, activeTag['sort']!),
                                onSecondaryTapDown: (details) => onTagSecondaryTapDown?.call(details, activeTag['url']!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sell, color: Colors.amber, size: 10),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          activeTag['tag']!,
                                          style: GoogleFonts.outfit(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Search Box
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, child) {
                    final isActive = value.text.isNotEmpty;
                    final isFocused = searchFocusNode.hasFocus;
                    return Container(
                      height: isSmallWindow ? 28 : 36,
                      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isActive || isFocused
                            ? AppColors.magenta.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive || isFocused ? AppColors.magenta : Colors.white10,
                          width: isActive || isFocused ? 1.5 : 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: isSmallWindow ? 11 : 12,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: isSmallWindow ? 11 : 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isActive || isFocused ? AppColors.magenta : Colors.white30,
                            size: isSmallWindow ? 14 : 16,
                          ),
                          suffixIcon: isActive
                              ? IconButton(
                                  icon: Icon(Icons.close, size: isSmallWindow ? 14 : 16, color: Colors.white54),
                                  onPressed: () {
                                    searchController.clear();
                                    searchFocusNode.unfocus();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : null,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmallWindow ? 4 : 11),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) {},
                      ),
                    );
                  },
                ),
              ),
              ),
              const Spacer(),
              if (hasItems) ...[
                Builder(
                  builder: (btnContext) {
                    return DownloaderFilterButton(
                      filterSettings: filterSettings,
                      onPressed: () {
                        final renderBox =
                            btnContext.findRenderObject() as RenderBox?;
                        final offset =
                            renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                        DownloaderFilterOverlay.show(
                          context: btnContext,
                          position: offset,
                          initialSettings: filterSettings,
                          availableTypes: availableTypes,
                          availableDates: availableDates,
                          availableDatesByType: availableDatesByType,
                          onFilterChanged: (newSettings) {
                            onFilterSettingsChanged?.call(newSettings);
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: 10),
                DownloaderSortDropdown(
                  selectedSort: sortOrder,
                  onChanged: (val) {
                    onSortChanged?.call(val);
                    onListFilterChanged?.call(val);
                  },
                ),
                const SizedBox(width: 10),
                if (currentGroup != null) ...[
                  if (currentGroup!.first.isPlaylist &&
                      config != null &&
                      rootIndex != null) ...[
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
                    ),
                    const SizedBox(width: 10),
                  ] else if (currentGroup!.items
                          .where((i) => !i.isProfile)
                          .any((i) => !i.isVideo) &&
                      currentGroup!.items
                          .where((i) => !i.isProfile)
                          .any((i) => i.isVideo)) ...[
                    SizedBox(
                      width: 140,
                      height: 36,
                      child: GroupFilterDropdown(
                        selectedFilter:
                            config?.groupFilter ?? GroupDownloadType.all,
                        isEnabled: true,
                        hasVideos: currentGroup!.items
                            .where((i) => !i.isProfile)
                            .any((i) => i.isVideo),
                        hasImages: currentGroup!.items
                            .where((i) => !i.isProfile)
                            .any((i) => !i.isVideo),
                        onChanged: onFilterChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
                SizedBox(
                  height: 36,
                  child: TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Clear',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
