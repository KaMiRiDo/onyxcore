import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/open_with_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/properties_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_popover.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/archive_manager/presentation/providers/archive_provider.dart';

/// Individual file/folder card — pixel-perfect replica of original _buildItemCard().
class ItemCard extends ConsumerStatefulWidget {
  const ItemCard({
    required this.item,
    required this.zoom,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onDoubleTap,
    required this.onHoverChanged,
    super.key,
  });

  final FileItem item;
  final double zoom;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<bool> onHoverChanged;

  @override
  ConsumerState<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<ItemCard> {
  Timer? _hoverTimer;
  late final GlobalKey _cardKey;

  @override
  void initState() {
    super.initState();
    _cardKey = GlobalKey(debugLabel: 'item_card_${widget.item.path}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(itemKeysProvider.notifier).update((state) {
          final newState = Map<String, GlobalKey>.from(state);
          newState[widget.item.path] = _cardKey;
          return newState;
        });
      }
    });
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draggingPaths = ref.watch(draggingPathsProvider);
    final currentPath = ref.watch(currentPathProvider);
    final isInTrash = currentPath.contains('.local/share/Trash/files') || currentPath.endsWith('Trash/files');
    final isSourceDragging = draggingPaths.contains(widget.item.path);
    final clipboard = ref.watch(clipboardProvider);
    final isCut = clipboard.isCut && clipboard.paths.contains(widget.item.path);

    final pinnedAsync = ref.watch(pinnedItemsProvider);
    final pinnedMap = pinnedAsync.value ?? const {};
    final isPinned = pinnedMap.containsKey(widget.item.path);

    Widget cardContent = Opacity(
      opacity: isCut ? 0.4 : (isSourceDragging ? 0.3 : 1.0),
      child: Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? AppColors.violet.withOpacity(0.12)
            : (widget.isHovered ? Colors.white.withOpacity(0.04) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isSelected
              ? AppColors.violet.withOpacity(0.2)
              : Colors.transparent,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 120 * widget.zoom,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildItemPreview(),
                if (isPinned && !isInTrash)
                  Positioned(
                    top: 8 * widget.zoom,
                    right: 8 * widget.zoom,
                    child: Container(
                      padding: EdgeInsets.all(4 * widget.zoom),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0).withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.push_pin,
                        size: 12 * widget.zoom,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                if (isInTrash)
                  Positioned(
                    top: 8 * widget.zoom,
                    right: 8 * widget.zoom,
                    child: Tooltip(
                      message: "Restore to original location",
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final taskId = ref.read(taskProvider.notifier).addTask(
                            title: 'Restoring item from Trash',
                            subtitle: 'Restore',
                            sourcePaths: [widget.item.path],
                            isLight: true,
                          );
                          final repo = ref.read(directoryRepositoryProvider);
                          try {
                            await repo.restoreFromTrash(
                              [widget.item.path],
                              taskId: taskId,
                              onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
                            );
                            ref.read(taskProvider.notifier).completeTask(taskId);
                            ref.read(selectionProvider.notifier).deselectAll();
                            ref.read(directoryItemsProvider.notifier).refresh();
                          } catch (e) {
                            ref.read(taskProvider.notifier).failTask(taskId, e.toString());
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error restoring: $e')));
                          }
                        },
                        // Glassmorphism: SizedBox → ClipOval → Stack(blur fill + centered icon)
                        child: SizedBox(
                          width: 34 * widget.zoom,
                          height: 34 * widget.zoom,
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Blur + frosted glass fill layer
                                BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.40),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                // Icon perfectly centered
                                Center(
                                  child: Icon(
                                    Icons.history_rounded,
                                    size: 22 * widget.zoom,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!widget.item.hasWritePermission)
                  Positioned(
                    top: 8 * widget.zoom,
                    right: (isPinned && !isInTrash) || isInTrash ? 32 * widget.zoom : 8 * widget.zoom,
                    child: Container(
                      padding: EdgeInsets.all(4 * widget.zoom),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8 * widget.zoom),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Icon(
                        Icons.lock,
                        size: 14 * widget.zoom,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8 * widget.zoom),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _truncateMiddle(widget.item.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13 * (widget.zoom < 1 ? widget.zoom.clamp(0.8, 1.0) : (widget.zoom > 1.2 ? 1.1 : 1.0)),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ));

    // DND Logic
    final isFolder = widget.item.type == FileItemType.folder;
    
    final Widget draggableWidget = Draggable<List<String>>(
      data: widget.isSelected 
          ? ref.read(selectionProvider).selectedPaths.toList()
          : [widget.item.path],
      dragAnchorStrategy: (Draggable<Object> draggable, BuildContext context, Offset position) {
        return const Offset(0, 0); // Position cursor at top-left of the miniature container
      },
      feedback: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: _buildItemPreview(scale: 0.4),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        // If it's already dimmed via isSourceDragging, don't double dip
        child: isSourceDragging ? (cardContent as Opacity).child : cardContent,
      ),
      onDragStarted: () {
        if (mounted) {
          final paths = widget.isSelected 
              ? ref.read(selectionProvider).selectedPaths 
              : {widget.item.path};
          ref.read(draggingPathsProvider.notifier).state = paths;
          ref.read(isDraggingProvider.notifier).state = true;
          if (!widget.isSelected) {
            ref.read(selectionProvider.notifier).selectMultiple([widget.item.path], isCtrl: false);
          }
        }
      },
      onDragCompleted: () {
        if (mounted) {
          ref.read(isDraggingProvider.notifier).state = false;
          ref.read(draggingPathsProvider.notifier).state = {};
        }
      },
      onDragEnd: (_) {
        if (mounted) {
          ref.read(isDraggingProvider.notifier).state = false;
          ref.read(draggingPathsProvider.notifier).state = {};
        }
      },
      onDraggableCanceled: (_, __) {
        if (mounted) {
          ref.read(isDraggingProvider.notifier).state = false;
          ref.read(draggingPathsProvider.notifier).state = {};
        }
      },
      child: cardContent,
    );

    Widget result = draggableWidget;

    if (isFolder) {
      result = DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) {
          if (details.data.contains(widget.item.path)) return false;
          
          _hoverTimer?.cancel();
          _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
            ref.read(navigationProvider.notifier).navigateTo(widget.item.path);
            ref.read(currentPathProvider.notifier).state = widget.item.path;
          });
          return true;
        },
        onLeave: (_) {
          _hoverTimer?.cancel();
        },
        onAcceptWithDetails: (details) async {
          _hoverTimer?.cancel();
          final repo = ref.read(directoryRepositoryProvider);
          final taskId = ref.read(taskProvider.notifier).addTask(
            title: 'Moving Files',
            subtitle: '${details.data.length} items to ${widget.item.name}',
            totalCount: details.data.length,
            sourcePaths: details.data,
            targetPath: widget.item.path,
          );
          try {
            await repo.moveItems(details.data, widget.item.path);
            ref.read(taskProvider.notifier).completeTask(taskId);
            ref.read(directoryItemsProvider.notifier).refresh();
            ref.read(selectionProvider.notifier).deselectAll();
          } catch (e) {
            ref.read(taskProvider.notifier).failTask(taskId, e.toString());
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isOver = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isOver ? AppColors.violet.withOpacity(0.1) : null,
            ),
            child: draggableWidget,
          );
        },
      );
    }

    final isDragging = ref.watch(isDraggingProvider);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) {
          if (!isDragging) {
            widget.onHoverChanged(true);
          }
        },
        onExit: (_) => widget.onHoverChanged(false),
        child: GestureDetector(
          key: _cardKey,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onSecondaryTapUp: (details) {
            if (!widget.isSelected) {
              widget.onTap();
            }
            _showContextMenu(context, details.globalPosition);
          },
          child: result,
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final selection = ref.read(selectionProvider).selectedPaths.toList();
    final paths = selection.isEmpty ? [widget.item.path] : selection;
    final currentPath = ref.read(currentPathProvider);
    final isInTrash = currentPath.contains('.local/share/Trash/files') || currentPath.endsWith('Trash/files');

    final pinnedAsync = ref.read(pinnedItemsProvider);
    final pinnedMap = pinnedAsync.value ?? const {};
    final isPinned = pinnedMap.containsKey(widget.item.path);

    final menuItems = [
      if (isInTrash) ...[
        ContextMenuItem(
          title: 'Restore',
          icon: Icons.restore_from_trash_rounded,
          onTap: () async {
            final taskId = ref.read(taskProvider.notifier).addTask(
              title: 'Restoring ${paths.length} items from Trash',
              subtitle: 'Restore',
              sourcePaths: paths,
              isLight: true,
            );
            final repo = ref.read(directoryRepositoryProvider);
            try {
              await repo.restoreFromTrash(paths, 
                taskId: taskId,
                onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
              );
              ref.read(taskProvider.notifier).completeTask(taskId);
              ref.read(selectionProvider.notifier).deselectAll();
              ref.read(directoryItemsProvider.notifier).refresh();
            } catch (e) {
              ref.read(taskProvider.notifier).failTask(taskId, e.toString());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error restoring: $e')));
            }
          },
        ),
        ContextMenuItem.divider(),
      ],
      if (paths.length == 1) ...[
        ContextMenuItem(
          title: 'Open',
          icon: Icons.open_in_browser_rounded,
          onTap: widget.onDoubleTap,
        ),
        ContextMenuItem(
          title: 'Open With...',
          icon: Icons.open_in_new_rounded,
          onTap: () => OpenWithDialog.show(context, widget.item.path),
        ),
        if (!isInTrash) ...[
          ContextMenuItem(
            title: isPinned ? 'Unpin File/Folder' : 'Pin File/Folder',
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            onTap: () async {
              if (isPinned) {
                await ref.read(pinnedItemsProvider.notifier).unpinItem(widget.item.path);
              } else {
                await ref.read(pinnedItemsProvider.notifier).pinItem(widget.item.path);
              }
            },
          ),
        ],
        ContextMenuItem.divider(),
      ],
      ContextMenuItem(
        title: 'Cut',
        icon: Icons.content_cut_rounded,
        shortcut: 'Ctrl+X',
        onTap: () {
          ref.read(clipboardProvider.notifier).cut(paths);
        },
      ),
      ContextMenuItem(
        title: 'Copy',
        icon: Icons.content_copy_rounded,
        shortcut: 'Ctrl+C',
        onTap: () {
          ref.read(clipboardProvider.notifier).copy(paths);
        },
      ),
      ContextMenuItem.divider(),
      if (!isInTrash) ...[
        ContextMenuItem(
          title: 'Rename...',
          icon: Icons.edit_rounded,
          shortcut: 'F2',
          onTap: () async {
            // ... (Rename logic remains same)
            if (paths.length == 1) {
              final existingNames = ref.read(filteredDirectoryItemsProvider).value?.map((i) => i.name).toList() ?? [];
              RenamePopover.show(
                context: context,
                position: position,
                paths: paths,
                existingNames: existingNames,
                onClose: () => ref.read(mainFocusNodeProvider).requestFocus(),
                onRename: (result) async {
                  final repo = ref.read(directoryRepositoryProvider);
                  try {
                    if (result is String) {
                      final oldPath = paths.first;
                      final taskId = ref.read(taskProvider.notifier).addTask(
                        title: 'Renaming item',
                        subtitle: '${p.basename(oldPath)} -> $result',
                        sourcePaths: [oldPath],
                        isLight: true,
                      );
                      try {
                        final newPath = await repo.renameItem(oldPath, result, 
                          taskId: taskId,
                          onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
                        );
                        ref.read(selectionProvider.notifier).deselectAll();
                        ref.read(selectionProvider.notifier).selectMultiple([newPath]);
                        ref.read(taskProvider.notifier).completeTask(taskId);
                      } catch (e) {
                        ref.read(taskProvider.notifier).failTask(taskId, e.toString());
                        rethrow;
                      }
                    }
                    ref.read(directoryItemsProvider.notifier).refresh();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming: $e')));
                  } finally {
                    ref.read(mainFocusNodeProvider).requestFocus();
                  }
                },
              );
            } else {
              final result = await showDialog(
                context: context,
                builder: (context) => RenameDialog(paths: paths),
              );

              if (result == null) {
                ref.read(mainFocusNodeProvider).requestFocus();
                return;
              }

              final repo = ref.read(directoryRepositoryProvider);
              try {
                if (result is String) {
                  final oldPath = paths.first;
                  final taskId = ref.read(taskProvider.notifier).addTask(
                    title: 'Renaming item',
                    subtitle: '${p.basename(oldPath)} -> $result',
                    sourcePaths: [oldPath],
                    isLight: true,
                  );
                  try {
                    final newPath = await repo.renameItem(oldPath, result, 
                      taskId: taskId,
                      onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
                    );
                    ref.read(selectionProvider.notifier).deselectAll();
                    ref.read(selectionProvider.notifier).selectMultiple([newPath]);
                    ref.read(taskProvider.notifier).completeTask(taskId);
                  } catch (e) {
                    ref.read(taskProvider.notifier).failTask(taskId, e.toString());
                    rethrow;
                  }
                } else if (result is Map) {
                  final mode = result['mode'] as RenameMode;
                  final value = result['value'] as String;
                  List<String> newPaths = [];
                  final taskId = ref.read(taskProvider.notifier).addTask(
                    title: 'Bulk renaming ${paths.length} items',
                    subtitle: mode == RenameMode.prefix ? 'Prefix: $value' : 'Index: $value',
                    sourcePaths: paths,
                    isLight: true,
                  );
                  try {
                    if (mode == RenameMode.prefix) {
                      newPaths = await repo.bulkRename(paths, 
                        prefix: value, 
                        taskId: taskId,
                        onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
                      );
                    } else {
                      newPaths = await repo.bulkRename(paths, 
                        baseName: value, 
                        taskId: taskId,
                        onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
                      );
                    }
                    ref.read(taskProvider.notifier).completeTask(taskId);
                  } catch (e) {
                    ref.read(taskProvider.notifier).failTask(taskId, e.toString());
                    rethrow;
                  }
                  ref.read(selectionProvider.notifier).deselectAll();
                  ref.read(selectionProvider.notifier).selectMultiple(newPaths);
                }
                ref.read(directoryItemsProvider.notifier).refresh();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming: $e')));
              } finally {
                ref.read(mainFocusNodeProvider).requestFocus();
              }
            }
          },
        ),
        ContextMenuItem(
          title: widget.item.type == FileItemType.archive ? 'Extract Here' : 'Compress...',
          icon: widget.item.type == FileItemType.archive ? Icons.unarchive_outlined : Icons.archive_outlined,
          onTap: () {
            if (widget.item.type == FileItemType.archive && paths.length == 1) {
              ref.read(archiveProvider.notifier).extractArchive(context, widget.item.path, currentPath);
            } else {
              ref.read(archiveProvider.notifier).compressItems(context, paths, currentPath);
            }
          },
        ),
      ],
      ContextMenuItem(
        title: isInTrash ? 'Delete Permanently' : 'Move to Trash',
        icon: Icons.delete_outline_rounded,
        shortcut: 'Delete',
        isDestructive: true,
        onTap: () async {
          final taskId = ref.read(taskProvider.notifier).addTask(
            title: isInTrash ? 'Deleting ${paths.length} items permanently' : 'Moving ${paths.length} items to Trash',
            subtitle: isInTrash ? 'Permanent deletion' : 'Trash',
            sourcePaths: paths,
            isLight: true,
          );
          final repo = ref.read(directoryRepositoryProvider);
          try {
            await repo.deleteItems(paths, 
              permanent: isInTrash, 
              taskId: taskId, 
              onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
              onProgress: (p, t) {
                ref.read(taskProvider.notifier).updateProgress(taskId, p / t);
                ref.read(taskProvider.notifier).updateItemCounts(taskId, p, t);
              },
            );
            ref.read(taskProvider.notifier).completeTask(taskId);
            ref.read(selectionProvider.notifier).deselectAll();
            ref.read(directoryItemsProvider.notifier).refresh();
          } catch (e) {
            ref.read(taskProvider.notifier).failTask(taskId, e.toString());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
          }
        },
      ),
      if (widget.item.type == FileItemType.folder)
        ContextMenuItem(
          title: 'Open in Terminal',
          icon: Icons.terminal_rounded,
          onTap: () {
            Process.run('gnome-terminal', ['--working-directory=${widget.item.path}']);
          },
        ),
      ContextMenuItem.divider(),
      ContextMenuItem(
        title: 'Properties',
        icon: Icons.info_outline_rounded,
        shortcut: 'Alt+Return',
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => PropertiesDialog(
              paths: paths,
              isInTrash: isInTrash,
            ),
          );
        },
      ),
    ];

    ContextMenu.show(context, position, menuItems);
  }

  Widget _buildItemPreview({double? scale}) {
    if (widget.item.type == FileItemType.folder) {
      final config = getFolderIconConfig(widget.item.name);
      return _buildArchivalIcon(config.icon, config.colors, hasTab: true, scale: scale);
    } else if (widget.item.type == FileItemType.image) {
      final isSvg = widget.item.name.toLowerCase().endsWith('.svg');
      if (isSvg) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SvgPicture.file(
            File(widget.item.path),
            fit: BoxFit.contain,
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.item.path),
          fit: BoxFit.contain,
          cacheWidth: 300,
          errorBuilder: (_, __, ___) => _buildSvgIcon('assets/icons/image.svg', isVertical: false, scale: scale),
        ),
      );
    } else if (widget.item.type == FileItemType.video) {
      return _buildSvgIcon('assets/icons/video.svg', isVertical: false, scale: scale);
    } else if (widget.item.type == FileItemType.audio) {
      return _buildSvgIcon('assets/icons/audio.svg', isVertical: false, scale: scale);
    } else {
      return _buildFileFallback(scale: scale);
    }
  }

  Widget _buildFileFallback({double? scale}) {
    final name = widget.item.name.toLowerCase();
    final ext = name.split('.').length > 1 ? '.${name.split('.').last}' : '';
    if (name.contains('readme') || ext == '.md') {
      return _buildSvgIcon('assets/icons/readme.svg', isVertical: true, scale: scale);
    } else if (['.exe', '.sh', '.bin', '.appimage', '.deb', '.rpm'].contains(ext)) {
      return _buildSvgIcon('assets/icons/exe.svg', isVertical: true, scale: scale);
    } else if (ext == '.zip' || ext == '.rar' || ext == '.7z') {
      return _buildSvgIcon('assets/icons/zip.svg', isVertical: false, scale: scale);
    }
    final config = getFileIconConfig(widget.item.name);
    return _buildArchivalIcon(config.icon, config.colors, isVertical: true, scale: scale);
  }

  Widget _buildSvgIcon(String assetPath, {required bool isVertical, double? scale}) {
    final s = scale ?? widget.zoom;
    return SizedBox(
      width: (isVertical ? 90 : 110) * s,
      height: (isVertical ? 120 : 110) * s,
      child: SvgPicture.asset(assetPath, fit: BoxFit.contain),
    );
  }

  String _truncateMiddle(String title, {int maxLength = 35}) {
    if (title.length <= maxLength) return title;
    final startLength = (maxLength * 0.6).floor();
    final endLength = (maxLength * 0.3).floor();
    return '${title.substring(0, startLength)}...${title.substring(title.length - endLength)}';
  }

  Widget _buildArchivalIcon(IconData icon, List<Color> colors, {bool hasTab = false, bool isVertical = false, double? scale}) {
    final s = scale ?? widget.zoom;
    return SizedBox(
      width: (isVertical ? 90 : 110) * s,
      height: (isVertical ? 120 : 110) * s,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasTab)
            Positioned(
              top: 0,
              left: 10 * s,
              child: Container(
                width: 38 * s,
                height: 14 * s,
                decoration: BoxDecoration(
                  color: colors.first.withOpacity(0.9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6 * s)),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            top: (hasTab ? 10 : 0) * s,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12 * s),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: (isVertical ? 48 : 42) * s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
