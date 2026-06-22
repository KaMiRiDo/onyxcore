import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/widgets/tooltip_if_truncated.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

/// Shared media tile widget used by both audio and video playlist sidebars.
///
/// Renders a consistent tile layout with 44×44 thumbnail container, title with
/// tooltip-if-truncated, subtitle, and an optional active indicator slot.
/// Customization is provided via slots: [coverArt], [subtitle], [activeIndicator],
/// and [defaultMediaIcon].
class MediaTile extends StatelessWidget {
  final FileItem item;
  final bool isActive;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(TapDownDetails details, BuildContext context)?
      onSecondaryTapDown;

  /// Optional cover art widget (e.g. ID3 album art for audio).
  /// If null, the default icon is shown.
  final Widget? coverArt;

  /// Subtitle text displayed below the title.
  final String subtitle;

  /// Widget shown on the right side when [isActive] is true.
  /// Typically a PlayingEqAnimation (audio) or play/pause icon (video).
  final Widget? activeIndicator;

  /// The icon used when no cover art or thumbnail is available.
  /// Audio uses `Icons.music_note_rounded`, video uses `Icons.play_arrow_rounded`.
  final IconData defaultMediaIcon;

  /// The size of the default media icon. Defaults to 24.
  final double defaultMediaIconSize;

  const MediaTile({
    super.key,
    required this.item,
    required this.isActive,
    required this.isSelected,
    required this.subtitle,
    required this.defaultMediaIcon,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTapDown,
    this.coverArt,
    this.activeIndicator,
    this.defaultMediaIconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isFolder = item.type == FileItemType.folder;

    return Builder(
      builder: (innerContext) {
        return GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onSecondaryTapDown: onSecondaryTapDown != null
              ? (details) => onSecondaryTapDown!(details, innerContext)
              : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.1)
                  : (isActive
                        ? Colors.white.withOpacity(0.03)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: isSelected || isActive
                  ? Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                    )
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF181818),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      coverArt ??
                      (item.thumbnailPath != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(item.thumbnailPath!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                  cacheHeight: 150,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildDefaultIcon(isFolder),
                                ),
                                _buildDefaultIcon(isFolder, hasImage: true),
                              ],
                            )
                          : _buildDefaultIcon(isFolder)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TooltipIfTruncated(
                        text: item.name,
                        style: TextStyle(
                          color: isActive ? AppColors.magenta : Colors.white,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isActive && activeIndicator != null)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: activeIndicator,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultIcon(bool isFolder, {bool hasImage = false}) {
    if (isFolder) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                AppColors.magenta.withOpacity(0.08),
                const Color(0xFF181818),
              ),
              Color.alphaBlend(
                AppColors.violet.withOpacity(0.03),
                const Color(0xFF181818),
              ),
            ],
          ),
        ),
        child: Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.magenta, AppColors.violet],
            ).createShader(bounds),
            child: const Icon(
              Icons.folder_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!hasImage)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    AppColors.magenta.withOpacity(0.08),
                    const Color(0xFF181818),
                  ),
                  Color.alphaBlend(
                    AppColors.violet.withOpacity(0.03),
                    const Color(0xFF181818),
                  ),
                ],
              ),
            ),
          ),
        if (hasImage)
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
        Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.magenta, AppColors.violet],
            ).createShader(bounds),
            child: Icon(
              defaultMediaIcon,
              size: defaultMediaIconSize,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(hasImage ? 0.4 : 0.2),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
