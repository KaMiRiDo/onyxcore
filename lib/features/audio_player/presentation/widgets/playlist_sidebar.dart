import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import '../providers/audio_player_providers.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/playing_eq_animation.dart';
import 'package:path/path.dart' as p;

class PlaylistSidebar extends ConsumerStatefulWidget {
  const PlaylistSidebar({super.key});

  @override
  ConsumerState<PlaylistSidebar> createState() => _PlaylistSidebarState();
}

class _PlaylistSidebarState extends ConsumerState<PlaylistSidebar> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _breadcrumbController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _breadcrumbController.dispose();
    super.dispose();
  }

  void _handleSelect(WidgetRef ref, int index, List<FileItem> items) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    final selection = ref.read(audioSelectionProvider);
    final anchor = ref.read(audioSelectionAnchorProvider);
    final newSelection = Set<String>.from(selection);
    
    if (isShift && anchor != null) {
      final start = math.min(anchor, index);
      final end = math.max(anchor, index);
      for (var i = start; i <= end; i++) {
        newSelection.add(items[i].path);
      }
    } else if (isCtrl) {
      final path = items[index].path;
      if (newSelection.contains(path)) {
        newSelection.remove(path);
      } else {
        newSelection.add(path);
      }
      ref.read(audioSelectionAnchorProvider.notifier).state = index;
    } else {
      newSelection.clear();
      newSelection.add(items[index].path);
      ref.read(audioSelectionAnchorProvider.notifier).state = index;
    }
    
    ref.read(audioSelectionProvider.notifier).state = newSelection;
  }

  void _openFolder(WidgetRef ref, String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    try {
      final items = await repo.listDirectory(path);
      
      final List<FileItem> audioFiles = [];
      for (final item in items) {
        if (item.type == FileItemType.audio) {
          audioFiles.add(item);
        } else if (item.type == FileItemType.folder) {
          try {
            final subItems = await repo.listDirectory(item.path);
            final hasAudio = subItems.any((sub) => sub.type == FileItemType.audio);
            if (hasAudio) {
              audioFiles.add(item);
            }
          } catch (_) {}
        }
      }
      
      final currentPath = ref.read(audioCurrentPathProvider);
      ref.read(audioPathHistoryProvider.notifier).update((state) => [...state, currentPath]);
      ref.read(audioPathForwardHistoryProvider.notifier).state = [];
      
      ref.read(audioCurrentPathProvider.notifier).state = path;
      ref.read(audioQueueProvider.notifier).state = audioFiles;
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_breadcrumbController.hasClients) {
          _breadcrumbController.animateTo(
            _breadcrumbController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint("Error opening folder: $e");
    }
  }

  Widget _buildBreadcrumbs(String currentPath, String rootPath) {
    if (currentPath.isEmpty || rootPath.isEmpty) return const SizedBox.shrink();
    
    final baseDir = p.dirname(rootPath);
    final relativePath = p.relative(currentPath, from: baseDir);
    final allSegments = p.split(relativePath);
    
    List<Widget> breadcrumbWidgets = [];
    String accumulatedPath = baseDir;
    
    for (int i = 0; i < allSegments.length; i++) {
      final segment = allSegments[i];
      accumulatedPath = p.join(accumulatedPath, segment);
      final isLast = i == allSegments.length - 1;
      final targetPath = accumulatedPath; 
      
      breadcrumbWidgets.add(
        InkWell(
          onTap: isLast ? null : () {
            _openFolder(ref, targetPath);
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              segment,
              style: TextStyle(
                color: isLast ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        )
      );
      
      if (!isLast) {
        breadcrumbWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text('/', style: TextStyle(color: Colors.white24, fontSize: 12)),
          )
        );
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.folder_open_rounded, color: Colors.white38, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: _breadcrumbController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: breadcrumbWidgets,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(filteredAndSortedAudioQueueProvider);
    final activeIndex = ref.watch(activeTrackIndexProvider);
    final player = ref.watch(audioPlayerProvider);
    final shuffle = ref.watch(audioShuffleProvider);
    final repeat = ref.watch(audioRepeatProvider);
    final currentPath = ref.watch(audioCurrentPathProvider);
    final rootPath = ref.watch(audioRootPathProvider);
    final selection = ref.watch(audioSelectionProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Matte dark grey
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.03))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Up Next",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: shuffle ? AppColors.violet : Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        ref.read(audioShuffleProvider.notifier).state = !shuffle;
                      },
                      tooltip: "Shuffle",
                    ),
                    IconButton(
                      icon: Icon(
                        repeat == PlaylistMode.loop ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        color: repeat != PlaylistMode.none ? AppColors.violet : Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        final nextMode = repeat == PlaylistMode.none 
                            ? PlaylistMode.loop 
                            : (repeat == PlaylistMode.loop ? PlaylistMode.single : PlaylistMode.none);
                        ref.read(audioRepeatProvider.notifier).state = nextMode;
                        player?.setPlaylistMode(nextMode);
                      },
                      tooltip: "Repeat",
                    ),
                    PopupMenuButton<SortOption>(
                      icon: const Icon(Icons.sort_rounded, color: Colors.white70, size: 20),
                      tooltip: "Sort",
                      color: const Color(0xFF2C2C2C),
                      onSelected: (option) {
                        ref.read(audioSortOptionProvider.notifier).state = option;
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: SortOption.aToZ, child: Text("A to Z", style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: SortOption.zToA, child: Text("Z to A", style: TextStyle(color: Colors.white))),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: SortOption.lastModified, child: Text("Last Modified", style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: SortOption.firstModified, child: Text("First Modified", style: TextStyle(color: Colors.white))),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: SortOption.sizeSmallToLarge, child: Text("Size (Small to Large)", style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: SortOption.sizeLargeToSmall, child: Text("Size (Large to Small)", style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: SizedBox(
              height: 36,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => ref.read(audioSearchQueryProvider.notifier).state = val,
              ),
            ),
          ),

          // Breadcrumbs
          _buildBreadcrumbs(currentPath, rootPath),

          // Track List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                // Need to find real index in the original queue for player.jump
                final originalQueue = ref.read(audioQueueProvider);
                final realIndex = originalQueue.indexWhere((i) => i.path == item.path);
                final isActive = realIndex != -1 && realIndex == activeIndex;
                final isSelected = selection.contains(item.path);

                return _TrackTile(
                  item: item,
                  isActive: isActive,
                  isSelected: isSelected,
                  isPlaying: ref.watch(audioPlayingProvider).value ?? false,
                  onTap: () {
                    _handleSelect(ref, index, queue);
                  },
                  onDoubleTap: () {
                    if (item.type == FileItemType.folder) {
                      _openFolder(ref, item.path);
                      return;
                    }
                    if (realIndex != -1) {
                      ref.read(activeTrackIndexProvider.notifier).state = realIndex;
                      player?.jump(realIndex);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final FileItem item;
  final bool isActive;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _TrackTile({
    required this.item,
    required this.isActive,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFolder = item.type == FileItemType.folder;
    
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withOpacity(0.1) 
              : (isActive ? Colors.white.withOpacity(0.03) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isSelected || isActive 
              ? Border.all(color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05))
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
                border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.thumbnailPath != null 
                  ? Image.file(
                      File(item.thumbnailPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(isFolder),
                    )
                  : _buildDefaultIcon(isFolder),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isActive ? AppColors.magenta : Colors.white,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFolder ? "Folder" : "Audio File",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isActive)
              SizedBox(
                width: 24,
                height: 24,
                child: isPlaying ? const PlayingEqAnimation() : const Icon(Icons.pause_rounded, color: AppColors.magenta, size: 16),
              )
          ],
        ),
      ),
    );
  }
  
  Widget _buildDefaultIcon(bool isFolder) {
    if (isFolder) {
      return const Center(child: Icon(Icons.folder_rounded, color: Colors.white54, size: 20));
    }
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(AppColors.magenta.withOpacity(0.08), const Color(0xFF181818)),
                Color.alphaBlend(AppColors.violet.withOpacity(0.03), const Color(0xFF181818)),
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
              child: const Icon(Icons.music_note_rounded, size: 24, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
