import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

class EngineSelectorDropdown extends StatelessWidget {

  const EngineSelectorDropdown({
    required this.selectedEngine, required this.onChanged, super.key,
  });
  final String selectedEngine;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final engines = EngineRegistry.allEngines;
    final options = [
      {
        'key': 'auto',
        'label': 'Auto Select',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.violet,
        'installed': true,
      },
      ...engines.map(
        (e) => {
          'key': e.id,
          'label': e.displayName,
          'icon': e.icon,
          'color': e.color,
          'installed': e.isInstalled,
        },
      ),
    ];

    final selected = options.firstWhere(
      (o) => o['key'] == selectedEngine,
      orElse: () => options.first,
    );

    return PopupMenuButton<String>(
      popUpAnimationStyle: AnimationStyle.noAnimation,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt['key'] == selectedEngine;
        final isInstalled = opt['installed']! as bool;
        return PopupMenuItem<String>(
          value: opt['key']! as String,
          enabled: isInstalled,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt['icon']! as IconData,
                  size: 16,
                  color: isInstalled
                      ? (opt['color']! as Color)
                      : (opt['color']! as Color).withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  opt['label']! as String,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isInstalled
                        ? (isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.8))
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 38,
        width: 155,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected['icon']! as IconData,
                    size: 16,
                    color: selected['color']! as Color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selected['label']! as String,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class GroupFilterDropdown extends StatelessWidget {

  const GroupFilterDropdown({
    required this.selectedFilter, required this.isEnabled, required this.onChanged, super.key,
    this.hasVideos = true,
    this.hasImages = true,
  });
  final GroupDownloadType selectedFilter;
  final bool isEnabled;
  final bool hasVideos;
  final bool hasImages;
  final ValueChanged<GroupDownloadType> onChanged;

  String _getLabel(GroupDownloadType type) {
    if (!hasVideos && hasImages) return 'Images';
    if (hasVideos && !hasImages) return 'Videos';
    
    switch (type) {
      case GroupDownloadType.all:
        return 'All';
      case GroupDownloadType.images:
        return 'Images Only';
      case GroupDownloadType.videos:
        return 'Videos Only';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actuallyEnabled = isEnabled && hasVideos && hasImages;
    final displayFilter = (!hasVideos && hasImages) 
        ? GroupDownloadType.images 
        : (hasVideos && !hasImages) ? GroupDownloadType.videos : selectedFilter;

    return PopupMenuButton<GroupDownloadType>(
      enabled: actuallyEnabled,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      color: const Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (context) => GroupDownloadType.values.map((f) {
        final isSelected = f == selectedFilter;
        return PopupMenuItem<GroupDownloadType>(
          value: f,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getLabel(f),
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selectedFilter != GroupDownloadType.all && actuallyEnabled
              ? AppColors.violet.withValues(alpha: 0.1) 
              : Colors.white.withValues(alpha: actuallyEnabled ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectedFilter != GroupDownloadType.all && actuallyEnabled
                ? AppColors.violet.withValues(alpha: 0.5) 
                : Colors.white.withValues(alpha: actuallyEnabled ? 0.1 : 0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _getLabel(displayFilter),
                style: GoogleFonts.manrope(
                  color: actuallyEnabled ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actuallyEnabled)
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

class FormatSelectionDropdown extends StatelessWidget {

  const FormatSelectionDropdown({
    required this.item, required this.config, required this.index, required this.onChanged, required this.getHeight, required this.matchTargetFormat, super.key,
    this.isItemLevel = false,
    this.group,
  });
  final MediaInfo item;
  final DownloadConfig config;
  final int index;
  final bool isItemLevel;
  final MediaGroup? group;
  final ValueChanged<MediaFormat> onChanged;
  final int Function(String) getHeight;
  final MediaFormat? Function(MediaInfo, MediaFormat?) matchTargetFormat;

  String getTitle(MediaFormat f) {
    final sizeText = (f.filesize != null)
        ? ' (${(f.filesize! / 1024 / 1024).toStringAsFixed(1)}MB)'
        : '';
    var title = f.resolution;
    if (f.resolution.toLowerCase() == 'original' && item.width != null && item.height != null) {
      title = '${item.width}x${item.height}';
    } else if (f.resolution.toLowerCase() == 'audio only') {
      title = 'Audio';
    }
    return '$title$sizeText';
  }

  @override
  Widget build(BuildContext context) {
    var formats = <MediaFormat>[];

    if (group != null && item.isPlaylist) {
      final formatSet = <String, MediaFormat>{};
      for (final vid in group!.items) {
        if (vid.isVideo) {
          final sortedFormats = vid.formats.toList()
            ..sort((a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0));
          for (final f in sortedFormats) {
            if (!formatSet.containsKey(f.resolution)) {
              formatSet[f.resolution] = f;
            } else {
              final existing = formatSet[f.resolution]!;
              if ((f.filesize ?? 0) > (existing.filesize ?? 0)) {
                formatSet[f.resolution] = f;
              }
            }
          }
        }
      }
      formats = formatSet.values.toList();

      if (formats.isEmpty) {
        formats = [
          const MediaFormat(
            formatId:
                'bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best',
            extension: 'mp4',
            resolution: '1080p',
            formatString: '1080p mp4',
          ),
          const MediaFormat(
            formatId:
                'bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best',
            extension: 'mp4',
            resolution: '720p',
            formatString: '720p mp4',
          ),
          const MediaFormat(
            formatId:
                'bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best',
            extension: 'mp4',
            resolution: '480p',
            formatString: '480p mp4',
          ),
          const MediaFormat(
            formatId: 'bestaudio[ext=m4a]/bestaudio',
            extension: 'm4a',
            resolution: 'audio',
            formatString: 'Audio Only',
          ),
        ];
      }
    } else {
      formats = item.formats.toSet().toList();
    }

    formats.sort((a, b) {
      final aAudio =
          a.resolution == 'audio only' || a.resolution.toLowerCase() == 'audio';
      final bAudio =
          b.resolution == 'audio only' || b.resolution.toLowerCase() == 'audio';
      if (aAudio != bAudio) return aAudio ? 1 : -1;

      final hA = getHeight(a.resolution);
      final hB = getHeight(b.resolution);
      if (hA != hB) return hB.compareTo(hA);

      final sizeA = a.filesize ?? 0;
      final sizeB = b.filesize ?? 0;
      return sizeB.compareTo(sizeA);
    });

    final maxH = formats.fold<int>(0, (max, f) {
      final h = getHeight(f.resolution);
      return h > max ? h : max;
    });

    if (maxH >= 480) {
      formats = formats.where((f) {
        if (f.resolution == 'audio only' ||
            f.resolution.toLowerCase() == 'audio') {
          return true;
        }
        return getHeight(f.resolution) >= 480;
      }).toList();
    }

    final currentFormat = isItemLevel
        ? config.itemFormats[item.id] ?? config.format
        : config.format;

    var isMixed = false;
    if (!isItemLevel && group != null && item.isPlaylist) {
      for (final vid in group!.items) {
        if (vid.isVideo) {
          final individualFormat = config.itemFormats[vid.id];
          if (individualFormat != null &&
              individualFormat.resolution != config.format?.resolution) {
            isMixed = true;
            break;
          }
        }
      }
    }

    final hasMultiple = formats.length > 1;
    final displayFormat = isItemLevel
        ? matchTargetFormat(item, currentFormat)
        : (formats.contains(currentFormat)
              ? currentFormat
              : (formats.isNotEmpty ? formats.first : null));

    var titleText = 'Original';
    if (isMixed) {
      titleText = 'Mixed';
    } else if (displayFormat != null) {
      titleText = getTitle(displayFormat);
    } else if (formats.length == 1) {
      titleText = getTitle(formats.first);
    }

    return PopupMenuButton<MediaFormat>(
      enabled: hasMultiple,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFF1E1E1E),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (context) => formats.map<PopupMenuEntry<MediaFormat>>((f) {
        final isSelected = !isMixed && (displayFormat?.resolution == f.resolution &&
                displayFormat?.extension == f.extension);

        return PopupMenuItem<MediaFormat>(
          value: f,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.violet.withValues(alpha: 0.2) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    getTitle(f),
                    style: GoogleFonts.outfit(
                      color: isSelected ? AppColors.violet : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: AppColors.violet),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                titleText,
                style: GoogleFonts.outfit(
                  color: hasMultiple ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasMultiple) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
