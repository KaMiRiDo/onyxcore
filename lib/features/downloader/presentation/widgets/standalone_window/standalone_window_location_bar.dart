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
    final isSmallWindow = MediaQuery.of(context).size.width < 1100;
    
    final sizeStr = '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB';
    final isExportDisabled = isTrashView || (isCustom && !isChanged) || (!isCustom && totalVideos == 0 && totalImages == 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
          if (constraints.maxWidth > 550) ...[
            Text(
              'Location : ',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmallWindow ? 11 : 13,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, innerConstraints) {
                return Container(
                  height: isSmallWindow ? 24 : 36,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      if (innerConstraints.maxWidth > 100) const SizedBox(width: 12),
                  Expanded(
                    child: currentPath.isEmpty
                        ? Text(
                            'Select a folder',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: isSmallWindow ? 11 : 13,
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
                            child: Padding(
                              padding: EdgeInsets.only(left: constraints.maxWidth <= 400 ? 8.0 : 0),
                              child: Text(
                                currentPath,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: isSmallWindow ? 11 : 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ),
                      if (innerConstraints.maxWidth > 150)
                        SizedBox(
                          height: isSmallWindow ? 24 : 36,
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
                                fontSize: isSmallWindow ? 11 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          if (constraints.maxWidth > 650)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_outlined, 
                    size: isSmallWindow ? 12 : 16, 
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalVideos',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: isSmallWindow ? 11 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.image_outlined, 
                    size: isSmallWindow ? 12 : 16, 
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalImages',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: isSmallWindow ? 11 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•  $sizeStr',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: isSmallWindow ? 11 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Container(
            height: isSmallWindow ? 24 : 36,
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
                size: isSmallWindow ? 12 : 16,
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
                  fontSize: isSmallWindow ? 11 : 13,
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
            height: isSmallWindow ? 24 : 36,
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
                  fontSize: isSmallWindow ? 11 : 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
