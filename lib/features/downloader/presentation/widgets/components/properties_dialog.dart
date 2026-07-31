import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

class PropertiesDialog extends StatelessWidget {
  const PropertiesDialog({
    required this.selectedItems,
    required this.onClose,
    required this.onDownload,
    super.key,
  });

  final List<dynamic> selectedItems; // List of MediaGroup or MediaInfo
  final VoidCallback onClose;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (selectedItems.isEmpty) return const SizedBox.shrink();

    final isSingleGroup =
        selectedItems.length == 1 && selectedItems.first is MediaGroup;
    final isMulti = selectedItems.length > 1;

    // Determine logs to show if it's a single root item
    String? logs;
    if (isSingleGroup) {
      final group = selectedItems.first as MediaGroup;
      logs = group.first.fetchLogs;
    }

    // Collect data
    final names = <String>[];
    var videoCount = 0;
    var imageCount = 0;
    var totalBytes = 0;
    final engineIds = <String>{};

    for (final item in selectedItems) {
      if (item is MediaGroup) {
        names.add(
          item.first.title.isNotEmpty ? item.first.title : item.originalUrl,
        );
        videoCount += item.videoCount;
        imageCount += item.imageCount;
        totalBytes += item.totalFilesize;
        for (final info in item.items) {
          if (info.engineId != null) engineIds.add(info.engineId!);
        }
      } else if (item is MediaInfo) {
        names.add(item.title.isNotEmpty ? item.title : item.originalUrl);
        if (item.isVideo) {
          videoCount++;
        } else {
          imageCount++;
        }
        totalBytes += item.filesize ?? 0;
        if (item.engineId != null) engineIds.add(item.engineId!);
      }
    }

    final nameText = names.length > 3
        ? '${names.take(3).join(', ')} and ${names.length - 3} more'
        : names.join(', ');

    final sizeMB = totalBytes > 0
        ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB'
        : 'Unknown';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            onClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 420,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Column(
                          children: [
                            _buildHeaderIcon(isMulti, videoCount >= imageCount),
                            const SizedBox(height: 16),
                            Text(
                              nameText,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Size and Items Row
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Size: $sizeMB',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '•',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Items:',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (videoCount > 0 || imageCount == 0) ...[
                                  Text(
                                    '$videoCount',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.videocam_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ],
                                if (videoCount > 0 && imageCount > 0)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                if (imageCount > 0) ...[
                                  Text(
                                    '$imageCount',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.image_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                            if (engineIds.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: engineIds.map((engineId) {
                                  final engineObj = EngineRegistry.findById(
                                    engineId,
                                  );
                                  if (engineObj == null) {
                                    return Text(
                                      engineId,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    );
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: engineObj.color.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: engineObj.color.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          engineObj.icon,
                                          size: 12,
                                          color: engineObj.color,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          engineObj.displayName,
                                          style: GoogleFonts.manrope(
                                            color: engineObj.color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white54,
                          ),
                          onPressed: onClose,
                        ),
                      ),
                    ],
                  ),

                  // Extraction Logs
                  if (isSingleGroup && logs != null && logs.isNotEmpty) ...[
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: Material(
                              type: MaterialType.transparency,
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                collapsedIconColor: Colors.white54,
                                iconColor: Colors.white,
                                title: Text(
                                  'Extraction Logs',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                children: [
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(
                                      left: 8,
                                      right: 8,
                                      bottom: 8,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        logs,
                                        style: GoogleFonts.jetBrainsMono(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          height: 1.4,
                                        ),
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

                  const Divider(height: 1, color: Colors.white10),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: onClose,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.outfit(color: Colors.white70),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            onClose();
                            onDownload();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.violet,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            selectedItems.length > 1
                                ? 'Download All'
                                : 'Download',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(bool isMulti, bool isVideo) {
    if (isMulti) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.copy_all_rounded,
            size: 48,
            color: Colors.indigoAccent,
          ),
        ),
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isVideo
            ? AppColors.violet.withValues(alpha: 0.2)
            : Colors.blueAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          size: 48,
          color: isVideo ? AppColors.violet : Colors.blueAccent,
        ),
      ),
    );
  }
}
