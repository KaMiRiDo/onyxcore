import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';

class StandaloneWindowMediaList extends StatelessWidget {
  const StandaloneWindowMediaList({
    required this.isTrashView,
    required this.trashCount,
    required this.activeListPath,
    required this.customLists,
    required this.isListChanged,
    required this.onTrashTap,
    required this.onImportTap,
    required this.onListTap,
    required this.onCustomListClose,
    required this.onCustomListSave,
    required this.onCustomListLock,
    this.onCustomListLockToggle,
    this.onDefaultExport,
    this.isDefaultExportDisabled = false,
    super.key,
  });

  final bool isTrashView;
  final int trashCount;
  final String? activeListPath;
  final List<CustomListInfo> customLists;
  final bool Function(String path) isListChanged;

  final VoidCallback onTrashTap;
  final VoidCallback onImportTap;
  final void Function(String path) onListTap;
  final void Function(String path) onCustomListClose;
  final void Function(String path) onCustomListSave;
  final void Function(String path) onCustomListLock;
  final void Function(String path)? onCustomListLockToggle;
  final VoidCallback? onDefaultExport;
  final bool isDefaultExportDisabled;

  @override
  Widget build(BuildContext context) {
    final isSmallWindow = MediaQuery.of(context).size.width < 1100;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: isSmallWindow ? WrapAlignment.start : WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
              Text(
                'Media List',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: isSmallWindow ? 13 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    height: isSmallWindow ? 20 : 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onTrashTap,
                          icon: Icon(
                            Icons.delete_outline,
                            size: isSmallWindow ? 10 : 14,
                            color: isTrashView || trashCount > 0 ? Colors.redAccent : Colors.white70,
                          ),
                          label: Text(
                            'Trash',
                            style: GoogleFonts.outfit(
                              color: isTrashView || trashCount > 0 ? Colors.redAccent : Colors.white70,
                              fontSize: isSmallWindow ? 10 : 11,
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
                              padding: EdgeInsets.all(isSmallWindow ? 2 : 4),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$trashCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallWindow ? 8 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: isSmallWindow ? 20 : 28,
                    child: ElevatedButton.icon(
                      onPressed: onImportTap,
                      icon: Icon(
                        Icons.file_download_outlined,
                        size: isSmallWindow ? 10 : 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Import',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: isSmallWindow ? 10 : 11,
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
                    isSmallWindow: isSmallWindow,
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
                      isSmallWindow: isSmallWindow,
                      hasPassword: list.hasPassword,
                      isLocked: list.isLocked,
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
    bool isSmallWindow = false,
    bool hasPassword = false,
    bool isLocked = false,
  }) {
    final isBtnDisabled = isCustom
        ? !isChanged
        : (isDefaultExportDisabled || onDefaultExport == null);

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
                  Icon(
                    Icons.list_alt,
                    size: 20,
                    color: path.toLowerCase().endsWith('.json') 
                        ? Colors.redAccent 
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                      color: path.toLowerCase().endsWith('.json')
                          ? Colors.redAccent
                          : isActive
                              ? Colors.white
                              : Colors.white70,
                      fontSize: isSmallWindow ? 11 : 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (isCustom && path.toLowerCase().endsWith('.dml') && hasPassword)
                  GestureDetector(
                    onTap: () {
                      onCustomListLockToggle?.call(path);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        isLocked ? Icons.lock_outline : Icons.lock_open_rounded,
                        color: isLocked ? Colors.white70 : AppColors.violet,
                        size: 16,
                      ),
                    ),
                  ),
                if (isCustom && path.toLowerCase().endsWith('.dml'))
                  Theme(
                    data: Theme.of(context).copyWith(
                      hoverColor: Colors.white12,
                    ),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      offset: const Offset(0, 40),
                      onSelected: (value) {
                        if (value == 'close') {
                          _handleCloseAction(context, path, isChanged);
                        } else if (value == 'update') {
                          onCustomListSave(path);
                        } else if (value == 'lock') {
                          onCustomListLock(path);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'close',
                          height: 36,
                          child: Row(
                            children: [
                              const Icon(Icons.close, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text('Close', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'update',
                          height: 36,
                          enabled: !isBtnDisabled,
                          child: Row(
                            children: [
                              Icon(Icons.file_upload_outlined, color: isChanged ? AppColors.violet : (isBtnDisabled ? Colors.white30 : Colors.white70), size: 16),
                              const SizedBox(width: 8),
                              Text('Update', style: GoogleFonts.outfit(color: isChanged ? AppColors.violet : (isBtnDisabled ? Colors.white30 : Colors.white), fontSize: 13, fontWeight: isChanged ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'lock',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(hasPassword ? Icons.lock_open : Icons.lock_outline, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(hasPassword ? 'Remove Password' : 'Lock', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      child: SizedBox(
                        height: isSmallWindow ? 20 : 24,
                        width: isSmallWindow ? 20 : 24,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.more_vert, color: Colors.white70, size: 18),
                            if (isChanged)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.violet,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        height: isSmallWindow ? 20 : 24,
                        decoration: BoxDecoration(
                          gradient: isBtnDisabled
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
                          color: isBtnDisabled
                              ? const Color(0xFF1E1E1E).withValues(alpha: 0.5)
                              : null,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isBtnDisabled
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.transparent,
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: isBtnDisabled
                              ? null
                              : () {
                                  if (isCustom) {
                                    onCustomListSave(path);
                                  } else {
                                    onDefaultExport?.call();
                                  }
                                },
                          icon: Icon(
                            Icons.file_upload_outlined,
                            size: isSmallWindow ? 10 : 12,
                            color: isBtnDisabled ? Colors.white30 : Colors.white,
                          ),
                          label: Text(
                            isCustom ? 'Update' : 'Export',
                            style: GoogleFonts.outfit(
                              color: isBtnDisabled ? Colors.white30 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallWindow ? 9 : 10,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(horizontal: isSmallWindow ? 6 : 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _handleCloseAction(context, path, isChanged),
                          splashRadius: 16,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCloseAction(BuildContext context, String path, bool isChanged) {
    if (isChanged) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            'Unsaved Changes',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: GoogleFonts.outfit(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCustomListClose(path);
                  },
                  child: Text(
                    'Discard',
                    style: GoogleFonts.outfit(color: AppColors.error),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCustomListSave(path);
                  },
                  child: Text(
                    'Save',
                    style: GoogleFonts.outfit(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      onCustomListClose(path);
    }
  }
}
