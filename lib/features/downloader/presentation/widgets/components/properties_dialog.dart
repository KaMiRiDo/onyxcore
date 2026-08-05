import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

class PropertiesDialog extends StatefulWidget {
  const PropertiesDialog({
    required this.selectedItems,
    this.config,
    this.getFormatBytes,
    this.onClose,
    super.key,
  });

  final List<dynamic> selectedItems; // List of MediaGroup or MediaInfo
  final DownloadConfig? config;
  final int? Function(MediaInfo, MediaFormat?, DownloadConfig?)? getFormatBytes;
  final VoidCallback? onClose;

  @override
  State<PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<PropertiesDialog> {
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  int _getHeight(String resStr) {
    final match = RegExp(r'(\d+)p').firstMatch(resStr);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    final xMatch = RegExp(r'x(\d+)').firstMatch(resStr);
    if (xMatch != null) {
      return int.tryParse(xMatch.group(1)!) ?? 0;
    }
    return 0;
  }

  int? _getItemSizeInBytes(MediaInfo info) {
    if (info.formats.isNotEmpty) {
      MediaFormat? selectedFormat;
      if (widget.config != null) {
        selectedFormat =
            widget.config!.itemFormats[info.id] ?? widget.config!.format;
      }
      selectedFormat ??= info.formats
          .where((f) {
            final h = _getHeight(f.resolution);
            return h > 0 && h <= 1080;
          })
          .fold<MediaFormat?>(
            null,
            (a, b) => a == null
                ? b
                : ((a.filesize ?? 0) > (b.filesize ?? 0) ? a : b),
          ) ??
          info.formats.first;

      if (widget.getFormatBytes != null && widget.config != null) {
        final b = widget.getFormatBytes!(info, selectedFormat, widget.config);
        if (b != null && b > 0) return b;
      }

      if (selectedFormat.filesize != null && selectedFormat.filesize! > 0) {
        var size = selectedFormat.filesize!;
        final noAudio =
            selectedFormat.audioCodec == 'none' || selectedFormat.audioCodec == null;
        if (noAudio &&
            !selectedFormat.resolution.toLowerCase().contains('audio') &&
            widget.config?.mode != DownloadMode.audioOnly) {
          final audioFormats = info.formats.where(
            (f) => f.resolution.toLowerCase().contains('audio'),
          );
          if (audioFormats.isNotEmpty) {
            final sortedAudio = audioFormats.toList()
              ..sort((a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0));
            size += sortedAudio.first.filesize ?? 0;
          }
        }
        return size;
      }

      for (final f in info.formats) {
        if (f.filesize != null && f.filesize! > 0) {
          return f.filesize;
        }
      }
    }

    return info.filesize;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedItems.isEmpty) return const SizedBox.shrink();

    final isSingleGroup =
        widget.selectedItems.length == 1 && widget.selectedItems.first is MediaGroup;
    final isMulti = widget.selectedItems.length > 1;

    // Determine logs and error state to show if it's a single root item
    String? logs;
    var isError = false;
    if (isSingleGroup) {
      final group = widget.selectedItems.first as MediaGroup;
      logs = group.first.fetchLogs;
      isError = group.first.isError || group.first.errorMessage != null;
    }

    final hasLogs = isSingleGroup && logs != null && logs.isNotEmpty;

    // Collect data
    final names = <String>[];
    var videoCount = 0;
    var imageCount = 0;
    var totalBytes = 0;
    final engineIds = <String>{};
    DateTime? uploadDate;

    for (final item in widget.selectedItems) {
      if (item is MediaGroup) {
        names.add(
          item.first.title.isNotEmpty ? item.first.title : item.originalUrl,
        );
        videoCount += item.videoCount;
        imageCount += item.imageCount;
        if (item.isSingle || item.items.length == 1) {
          final bytes = _getItemSizeInBytes(item.first);
          totalBytes += bytes ?? item.totalFilesize;
        } else {
          var groupBytes = 0;
          var hasCustom = false;
          for (final subItem in item.items) {
            if (subItem.isError) continue;
            final b = _getItemSizeInBytes(subItem);
            if (b != null && b > 0) {
              groupBytes += b;
              hasCustom = true;
            }
          }
          if (hasCustom) {
            totalBytes += groupBytes;
          } else {
            totalBytes += item.totalFilesize;
          }
        }
        uploadDate ??= item.uploadDate;
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
        final bytes = _getItemSizeInBytes(item);
        totalBytes += bytes ?? (item.filesize ?? 0);
        uploadDate ??= item.uploadDate;
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
            _handleClose();
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
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          24,
                          24,
                          hasLogs ? 16 : 24,
                        ),
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
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  uploadDate != null
                                      ? 'Uploaded: ${uploadDate.hour != 0 || uploadDate.minute != 0 || uploadDate.second != 0 ? DateFormat('MMM d, yyyy, h:mm a').format(uploadDate) : DateFormat('MMM d, yyyy').format(uploadDate)}'
                                      : 'Uploaded: Unknown',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
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
                          ],
                        ),
                      ),
                      if (hasLogs)
                        Flexible(
                          child: Padding(
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
                                    initiallyExpanded: isError,
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
                                        height: 180,
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          left: 8,
                                          right: 8,
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Scrollbar(
                                            controller: _logScrollController,
                                            thumbVisibility: true,
                                            child: SingleChildScrollView(
                                              controller: _logScrollController,
                                              physics: const BouncingScrollPhysics(
                                                parent:
                                                    AlwaysScrollableScrollPhysics(),
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              child: SelectableText(
                                                logs,
                                                style: GoogleFonts.jetBrainsMono(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                  height: 1.4,
                                                ),
                                              ),
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
                      onPressed: _handleClose,
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
