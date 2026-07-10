import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

class StandaloneWindowMediaList extends StatelessWidget {
  const StandaloneWindowMediaList({
    super.key,
    required this.isTrashView,
    required this.importedListName,
    required this.isListChanged,
    required this.lastCustomListName,
    required this.lastCustomListVideos,
    required this.lastCustomListImages,
    required this.lastCustomListSize,
    required this.onTrashTap,
    required this.onImportTap,
    required this.onDefaultListTap,
    required this.onCustomListTap,
    required this.onCustomListClose,
    required this.onCustomListSave,
  });

  final bool isTrashView;
  final String? importedListName;
  final bool isListChanged;
  final String? lastCustomListName;
  final int lastCustomListVideos;
  final int lastCustomListImages;
  final int lastCustomListSize;

  final VoidCallback onTrashTap;
  final VoidCallback onImportTap;
  final VoidCallback onDefaultListTap;
  final VoidCallback onCustomListTap;
  final VoidCallback onCustomListClose;
  final VoidCallback onCustomListSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Media List',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: onTrashTap,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: isTrashView ? Colors.redAccent : Colors.white70,
                      ),
                      label: Text(
                        'Trash',
                        style: GoogleFonts.outfit(
                          color: isTrashView ? Colors.redAccent : Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTrashView
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : const Color(0xFF262626),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isTrashView
                                ? Colors.redAccent.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: onImportTap,
                      icon: const Icon(
                        Icons.file_upload_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Import',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262626),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Default List Item
                GestureDetector(
                  onTap: onDefaultListTap,
                  child: _buildListItem(
                    context,
                    name: 'Default List',
                    isCustom: false,
                    isActive: importedListName == null && !isTrashView,
                  ),
                ),
                if (importedListName != null || lastCustomListName != null) ...[
                  GestureDetector(
                    onTap: onCustomListTap,
                    child: _buildListItem(
                      context,
                      name: importedListName ?? lastCustomListName!,
                      isCustom: true,
                      isChanged: isListChanged,
                      isActive: importedListName != null && !isTrashView,
                      cachedVideos: lastCustomListVideos,
                      cachedImages: lastCustomListImages,
                      cachedSize: lastCustomListSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required String name,
    required bool isCustom,
    bool isChanged = false,
    bool isActive = false,
    int? cachedVideos,
    int? cachedImages,
    int? cachedSize,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.magenta, AppColors.violet],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 13, right: 16, top: 12, bottom: 12),
            child: Row(
              children: [
                if (isActive)
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(Icons.list_alt, size: 20, color: Colors.white),
                  )
                else
                  const Icon(Icons.list_alt, color: Colors.white54, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: isActive
                      ? ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.magenta, AppColors.violet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            name,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : Text(
                          name,
                          style: GoogleFonts.outfit(
                              color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (isChanged) {
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: Text(
                              'Unsaved Changes',
                              style: GoogleFonts.outfit(color: Colors.white),
                            ),
                            content: Text(
                              'You have unsaved changes. Are you sure you want to discard them?',
                              style: GoogleFonts.outfit(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.outfit(
                                      color: Colors.white70),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onCustomListClose();
                                },
                                child: Text(
                                  'Discard',
                                  style: GoogleFonts.outfit(
                                      color: AppColors.error),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.violet,
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  onCustomListSave();
                                },
                                child: Text(
                                  'Save',
                                  style: GoogleFonts.outfit(
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        onCustomListClose();
                      }
                    },
                    icon: const Icon(Icons.close,
                        size: 16, color: Colors.white54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
