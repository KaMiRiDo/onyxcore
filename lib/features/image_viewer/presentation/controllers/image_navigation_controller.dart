import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_precache_manager.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/utils/special_image_converter.dart';
import 'package:path/path.dart' as p;

class ImageNavigationController extends ChangeNotifier {

  ImageNavigationController({
    required this.isStandalone,
    required this.initParams,
    required this.windowId,
    required this.ref,
    required this.onNavigate,
    required this.onClearNavigation,
  });
  final bool isStandalone;
  final Map<String, dynamic>? initParams;
  final String? windowId;
  final WidgetRef ref;
  final void Function(FileItem nextItem) onNavigate;
  final VoidCallback onClearNavigation;

  Timer? _navigationThrottleTimer;
  bool _isEmpty = false;
  bool _isEmptyAtEnd = false;
  String? _indexString;
  List<FileItem> _standalonePlaylist = [];

  bool get isEmpty => _isEmpty;
  bool get isEmptyAtEnd => _isEmptyAtEnd;
  String? get indexString => _indexString;
  List<FileItem> get standalonePlaylist => _standalonePlaylist;

  @override
  void dispose() {
    _navigationThrottleTimer?.cancel();
    super.dispose();
  }

  void resetEmptyState() {
    if (_isEmpty) {
      _isEmpty = false;
      notifyListeners();
    }
  }

  List<FileItem> getPlaylist() {
    if (isStandalone) {
      return _standalonePlaylist;
    }
    
    var mediaItems = ref
        .read(filteredAndSortedImageQueueProvider)
        .where((i) => i.type == FileItemType.image)
        .toList();
    if (mediaItems.isEmpty) {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
      mediaItems = items.where((i) => i.type == FileItemType.image).toList();
    }
    return mediaItems;
  }

  void navigateForward(FileItem currentItem) {
    _navigateMedia(currentItem, forward: true);
  }

  void navigateBackward(FileItem currentItem) {
    _navigateMedia(currentItem, forward: false);
  }

  void _navigateMedia(FileItem currentItem, {required bool forward}) {
    if (_navigationThrottleTimer?.isActive ?? false) return;
    _navigationThrottleTimer = Timer(const Duration(milliseconds: 300), () {});

    final mediaItems = getPlaylist();
    if (mediaItems.isEmpty) return;

    final currentIndex = mediaItems.indexWhere((i) => i.path == currentItem.path);

    if (currentIndex == -1) {
      _isEmpty = true;
      _isEmptyAtEnd = true;
      notifyListeners();
      return;
    }

    if (_isEmpty) {
      if (_isEmptyAtEnd && forward) return;
      if (!_isEmptyAtEnd && !forward) return;

      _isEmpty = false;
      notifyListeners();
      onNavigate(mediaItems[currentIndex]);
      return;
    }

    int nextIndex;
    if (forward) {
      if (currentIndex == mediaItems.length - 1) {
        _isEmpty = true;
        _isEmptyAtEnd = true;
        notifyListeners();
        return;
      }
      nextIndex = currentIndex + 1;
    } else {
      if (currentIndex == 0) {
        _isEmpty = true;
        _isEmptyAtEnd = false;
        notifyListeners();
        return;
      }
      nextIndex = currentIndex - 1;
    }

    onNavigate(mediaItems[nextIndex]);
  }

  void navigateAfterDeletion(FileItem currentItem) {
    final mediaItems = getPlaylist();
    
    if (mediaItems.length > 1) {
      final currentIndex = mediaItems.indexWhere((i) => i.path == currentItem.path);
      if (currentIndex != -1) {
        final nextIndex = (currentIndex + 1) % mediaItems.length;
        onNavigate(mediaItems[nextIndex]);
      } else {
        onClearNavigation();
      }
    } else {
      onClearNavigation();
    }
  }

  Future<void> updateIndexData(FileItem currentItem) async {
    final useInitParams =
        windowId != null &&
        initParams != null &&
        initParams!['currentIndex'] != null &&
        !(isStandalone && _standalonePlaylist.isNotEmpty);

    if (useInitParams) {
      _indexString = '${initParams!['currentIndex']}/${initParams!['totalCount']}';
      notifyListeners();
    } else {
      final mediaItems = getPlaylist();
      final currentIndex = mediaItems.indexWhere((i) => i.path == currentItem.path) + 1;
      final totalCount = mediaItems.length;
      if (currentIndex > 0) {
        _indexString = '$currentIndex/$totalCount';
        notifyListeners();
      }
    }
  }

  Future<void> initStandalonePlaylist(FileItem currentItem) async {
    try {
      final images = <FileItem>[];

      if (initParams != null && initParams!['playlistJson'] != null) {
        final list =
            jsonDecode(initParams!['playlistJson'] as String) as List<dynamic>;
        images.addAll(
          list.map((e) => FileItem.fromJson(e as Map<String, dynamic>)),
        );
      } else if (initParams != null && initParams!['playlistPaths'] != null) {
        final paths = List<String>.from(initParams!['playlistPaths'] as Iterable);
        for (final path in paths) {
          final file = File(path);
          if (file.existsSync()) {
            final name = p.basename(path);
            try {
              final stat = file.statSync();
              images.add(
                FileItem(
                  name: name,
                  path: path,
                  type: FileItemType.image,
                  sizeBytes: stat.size,
                  modified: stat.modified,
                ),
              );
            } catch (e) {
              debugPrint('Error stating file $path: $e');
            }
          }
        }
      } else {
        final absolutePath = File(currentItem.path).absolute.path;
        final parentDir = File(absolutePath).parent;
        if (!parentDir.existsSync()) return;

        final imagesResult = await Isolate.run(() {
          final result = <FileItem>[];
          final dir = Directory(parentDir.path);
          final entities = dir.listSync();

          for (final entity in entities) {
            if (FileSystemEntity.isFileSync(entity.path)) {
              final name = p.basename(entity.path);
              if (classifyFileType(name) == FileItemType.image) {
                try {
                  final stat = entity.statSync();
                  result.add(
                    FileItem(
                      name: name,
                      path: entity.path,
                      type: FileItemType.image,
                      sizeBytes: stat.size,
                      modified: stat.modified,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error stating file ${entity.path}: $e');
                }
              }
            }
          }

          result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return result;
        });
        
        images.addAll(imagesResult);
      }

      debugPrint('Added ${images.length} images to standalone playlist');
      _standalonePlaylist = images;
      notifyListeners();
      
      ref.read(imageQueueProvider.notifier).state = _standalonePlaylist;
      unawaited(updateIndexData(currentItem));
    } catch (e) {
      debugPrint('[ImageNavigationController] Error in initStandalonePlaylist: $e');
    }
  }

  Future<void> _doPrecache(String path) async {
    final pLower = path.toLowerCase();
    final isSpecial = pLower.endsWith('.heic') || pLower.endsWith('.heif') || pLower.endsWith('.avif') || pLower.endsWith('.dng') || pLower.endsWith('.raw');

    if (isSpecial) {
      final convertedPath = await SpecialImageConverter.convertIfNecessary(path);
      if (convertedPath != null) {
        await _resolveProvider(FileImage(File(convertedPath)));
      }
    } else {
      final provider = path.startsWith('http') 
          ? NetworkImage(path) 
          : FileImage(File(path)) as ImageProvider;
      await _resolveProvider(provider);
    }
  }

  Future<void> _resolveProvider(ImageProvider provider) async {
    final completer = Completer<void>();
    final stream = ResizeImage(provider, width: 1920, height: 1920, policy: ResizeImagePolicy.fit)
        .resolve(ImageConfiguration.empty);
        
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, sync) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e, s) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void precacheAdjacentImages(BuildContext context, FileItem currentItem) {
    if (isStandalone && initParams != null && initParams!['preloadPaths'] != null) {
      final preloadList = initParams!['preloadPaths'] as List<dynamic>;
      for (final p in preloadList) {
        final path = p.toString();
        if (path != currentItem.path && !path.toLowerCase().endsWith('.svg')) {
          ImagePrecacheManager.instance.enqueuePrecache(
            path: path,
            level: 1,
            precacheAction: (_) => _doPrecache(path),
          );
        }
      }
    } else if (!isStandalone && windowId == null) {
      final mediaItems = getPlaylist();
      if (mediaItems.isNotEmpty) {
        final currentIndex = mediaItems.indexWhere((i) => i.path == currentItem.path);
        if (currentIndex != -1) {
          
          void enqueueLevel(int level) {
            final nextPath = mediaItems[(currentIndex + level) % mediaItems.length].path;
            final prevPath = mediaItems[(currentIndex - level + mediaItems.length) % mediaItems.length].path;
            
            if (nextPath != currentItem.path && !nextPath.toLowerCase().endsWith('.svg')) {
              ImagePrecacheManager.instance.enqueuePrecache(
                path: nextPath,
                level: level,
                precacheAction: (_) => _doPrecache(nextPath),
              );
            }
            
            // Only precache previous for level 1
            if (level == 1 && prevPath != currentItem.path && prevPath != nextPath && !prevPath.toLowerCase().endsWith('.svg')) {
              ImagePrecacheManager.instance.enqueuePrecache(
                path: prevPath,
                level: level,
                precacheAction: (_) => _doPrecache(prevPath),
              );
            }
          }

          enqueueLevel(1);
          if (mediaItems.length > 2) enqueueLevel(2);
        }
      }
    }
  }

  void navigatePlaylistHistoryBack() {
    final history = ref.read(imagePathHistoryProvider);
    if (history.isNotEmpty) {
      final newPath = history.last;
      final currentPath = ref.read(imageCurrentPathProvider);

      ref.read(imagePathHistoryProvider.notifier).state = history.sublist(0, history.length - 1);
      ref.read(imagePathForwardHistoryProvider.notifier).update((state) => [...state, currentPath]);

      _openPlaylistFolder(newPath);
    }
  }

  void navigatePlaylistHistoryForward() {
    final forwardHistory = ref.read(imagePathForwardHistoryProvider);
    if (forwardHistory.isNotEmpty) {
      final newPath = forwardHistory.last;
      final currentPath = ref.read(imageCurrentPathProvider);

      ref.read(imagePathForwardHistoryProvider.notifier).state = forwardHistory.sublist(0, forwardHistory.length - 1);
      ref.read(imagePathHistoryProvider.notifier).update((state) => [...state, currentPath]);

      _openPlaylistFolder(newPath);
    }
  }

  Future<void> _openPlaylistFolder(String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(imageShowHiddenProvider);
    try {
      final items = await repo.listDirectory(path);
      final mediaFiles = await compute(processMediaQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
        'targetType': FileItemType.image.index,
      });

      ref.read(imageQueueProvider.notifier).state = mediaFiles;
      ref.read(imageCurrentPathProvider.notifier).state = path;
    } catch (_) {}
  }
}
