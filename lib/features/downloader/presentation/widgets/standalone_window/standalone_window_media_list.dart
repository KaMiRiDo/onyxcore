import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';

class StandaloneWindowMediaList extends StatelessWidget {
  const StandaloneWindowMediaList({
    required this.isTrashView, required this.trashCount, required this.activeListPath, required this.customLists, required this.isListChanged, required this.onTrashTap, required this.onImportTap, required this.onListTap, required this.onCustomListClose, required this.onCustomListSave, super.key,
  });

  final bool isTrashView;
  final int trashCount;
  final String activeListPath;
  final List<CustomListInfo> customLists;
  final bool Function(String) isListChanged;

  final VoidCallback onTrashTap;
  final VoidCallback onImportTap;
  final void Function(String path) onListTap;
  final void Function(String path) onCustomListClose;
  final void Function(String path) onCustomListSave;

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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onTrashTap,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: isTrashView || trashCount > 0 ? Colors.redAccent : Colors.white70,
                          ),
                          label: Text(
                            'Trash',
                            style: GoogleFonts.outfit(
                              color: isTrashView || trashCount > 0 ? Colors.redAccent : Colors.white70,
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
                        if (trashCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$trashCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: onImportTap,
                      icon: const Icon(
                        Icons.file_download_outlined,
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
                  onTap: () => onListTap('default'),
                  child: _buildListItem(
                    context,
                    name: 'Default List',
                    isCustom: false,
                    path: 'default',
                    isActive: activeListPath == 'default' && !isTrashView,
                  ),
                ),
                for (final list in customLists)
                  GestureDetector(
                    onTap: () => onListTap(list.path),
                    child: _buildListItem(
                      context,
                      name: list.name,
                      isCustom: true,
                      path: list.path,
                      isChanged: isListChanged(list.path),
                      isActive: activeListPath == list.path && !isTrashView,
                    ),
                  ),
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
    required String path,
    bool isChanged = false,
    bool isActive = false,
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
                                  onCustomListClose(path);
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
                                  onCustomListSave(path);
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
                        onCustomListClose(path);
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
