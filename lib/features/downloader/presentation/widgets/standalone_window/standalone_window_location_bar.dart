import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

class StandaloneWindowLocationBar extends StatelessWidget {
  const StandaloneWindowLocationBar({
    required this.isTrashView,
    required this.isCustom,
    required this.isChanged,
    required this.currentPath,
    required this.totalVideos,
    required this.totalImages,
    required this.totalSize,
    required this.onChangeLocation,
    required this.onExport,
    required this.onDownloadAll,
    this.selectionCount = 0,
    super.key,
  });

  final bool isTrashView;
  final bool isCustom;
  final bool isChanged;
  final String currentPath;
  final int totalVideos;
  final int totalImages;
  final int totalSize;

  final VoidCallback onChangeLocation;
  final VoidCallback onExport;
  final VoidCallback onDownloadAll;
  final int selectionCount;

  @override
  Widget build(BuildContext context) {
    final sizeStr = '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB';
    final statsTextBase = '$totalVideos Videos • $totalImages Images • ';
    final isExportDisabled = isTrashView || (isCustom && !isChanged) || (!isCustom && totalVideos == 0 && totalImages == 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Text(
            'Location : ',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white10),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      if (constraints.maxWidth > 30) const SizedBox(width: 12),
                      Expanded(
                        child: currentPath.isEmpty
                            ? Text(
                                'Select a folder',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            : ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    AppColors.magenta,
                                    AppColors.violet,
                                    AppColors.indigo,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Text(
                                  currentPath,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                      if (constraints.maxWidth > 120)
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: onChangeLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E1E),
                              elevation: 0,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              minimumSize: Size.zero,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              'Change',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2, // 2/3 of the flex space
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: statsTextBase,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: sizeStr,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: isExportDisabled
                  ? null
                  : const LinearGradient(
                      colors: [
                        AppColors.magenta,
                        AppColors.violet,
                        AppColors.indigo,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isExportDisabled
                  ? const Color(0xFF1E1E1E).withValues(alpha: 0.5)
                  : null,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isExportDisabled
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.transparent,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: isExportDisabled
                  ? null
                  : onExport,
              icon: Icon(
                Icons.file_upload_outlined,
                size: 16,
                color: isExportDisabled
                    ? Colors.white30
                    : Colors.white,
              ),
              label: Text(
                isCustom ? 'Update' : 'Export',
                style: GoogleFonts.outfit(
                  color: isExportDisabled
                      ? Colors.white30
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: ElevatedButton(
              onPressed: onDownloadAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(
                selectionCount > 0 ? 'Download $selectionCount' : 'Download All',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
