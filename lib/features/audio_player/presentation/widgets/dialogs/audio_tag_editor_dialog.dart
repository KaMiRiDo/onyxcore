import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_metadata_utils.dart';
import 'package:audiotags/audiotags.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class AudioTagEditorDialog extends ConsumerStatefulWidget {
  final List<String> paths;
  final Function(String oldPath, String newPath)? onRename;

  const AudioTagEditorDialog({super.key, required this.paths, this.onRename});

  static Future<void> show(BuildContext context, List<String> paths, {Function(String, String)? onRename}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(179),
      barrierDismissible: false,
      builder: (context) => AudioTagEditorDialog(paths: paths, onRename: onRename),
    );
  }

  @override
  ConsumerState<AudioTagEditorDialog> createState() => _AudioTagEditorDialogState();
}

enum BulkRenameMode { baseName, prefix }

Uint8List? _prepareCoverArtWorker(Uint8List bytes) {
  return AudioMetadataUtils.prepareCoverArt(bytes);
}

class _AudioTagEditorDialogState extends ConsumerState<AudioTagEditorDialog> {
  bool _isLoading = true;
  bool _isProcessingImage = false;
  Tag? _initialTag;

  final _fileNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _genreController = TextEditingController();

  BulkRenameMode _renameMode = BulkRenameMode.prefix;
  final _bulkRenameController = TextEditingController();

  Uint8List? _newCoverArt;
  bool _clearCoverArt = false;
  String _commonPrefix = '';

  final FocusNode _primaryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _bulkRenameController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _bulkRenameController.dispose();
    _primaryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (widget.paths.length == 1) {
      final tag = await AudioMetadataUtils.readTags(widget.paths.first);
      if (tag != null) {
        _initialTag = tag;
        _titleController.text = tag.title?.isNotEmpty == true ? tag.title! : p.basenameWithoutExtension(widget.paths.first);
        _artistController.text = tag.trackArtist ?? tag.albumArtist ?? '';
        _albumController.text = tag.album ?? '';
        _genreController.text = tag.genre ?? '';
      } else {
        _titleController.text = p.basenameWithoutExtension(widget.paths.first);
      }
      _titleController.selection = const TextSelection.collapsed(offset: 0);
    } else if (widget.paths.length > 1) {
      String? commonPrefix;
      for (final path in widget.paths) {
        final basename = p.basenameWithoutExtension(path);
        if (commonPrefix == null) {
          commonPrefix = basename;
        } else {
          int i = 0;
          while (i < commonPrefix.length && i < basename.length && commonPrefix[i] == basename[i]) {
            i++;
          }
          commonPrefix = commonPrefix.substring(0, i);
        }
      }
      if (commonPrefix != null && commonPrefix.isNotEmpty) {
        _commonPrefix = commonPrefix;
        _bulkRenameController.text = commonPrefix;
      }
      _bulkRenameController.selection = const TextSelection.collapsed(offset: 0);
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _primaryFocusNode.requestFocus();
      });
    }
  }

  Future<void> _pickImage() async {
    if (_isProcessingImage) return;
    try {
      final files = await CustomFilePickerDialog.show(
        context,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (files != null && files.isNotEmpty) {
        setState(() {
          _isProcessingImage = true;
        });

        final bytes = await files.first.readAsBytes();
        final processed = await compute(_prepareCoverArtWorker, bytes);

        if (!mounted) return;

        setState(() {
          _isProcessingImage = false;
          if (processed != null) {
            _newCoverArt = processed;
            _clearCoverArt = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }


  void _save() {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();
    final genre = _genreController.text.trim();

    final taskId = ref.read(taskProvider.notifier).addTask(
      title: 'Updating Audio Tags',
      subtitle: widget.paths.length == 1 ? p.basename(widget.paths.first) : '${widget.paths.length} items',
      totalCount: widget.paths.length,
      isLight: false, // Make it heavy so it respects concurrency limit
    );

    // Capture the ProviderContainer before the widget unmounts
    final container = ProviderScope.containerOf(context);

    _runSaveTask(container, taskId, title, artist, album, genre);
    Navigator.of(context).pop();
  }

  Future<void> _runSaveTask(
    ProviderContainer container,
    String taskId,
    String title,
    String artist,
    String album,
    String genre,
  ) async {
    final notifier = container.read(taskProvider.notifier);
    int processed = 0;

    Future<void> processFile(String path) async {
      if (notifier.isTaskCancelled(taskId)) return;

      try {
        final oldTag = await AudioMetadataUtils.readTags(path) ?? const Tag(pictures: []);

        List<Picture> newPictures = oldTag.pictures;
        if (_newCoverArt != null) {
          newPictures = [
            Picture(
              bytes: _newCoverArt!,
              mimeType: MimeType.jpeg,
              pictureType: PictureType.coverFront,
            )
          ];
        } else if (_clearCoverArt) {
          newPictures = [];
        }

        final newTag = Tag(
          title: widget.paths.length == 1 && title.isNotEmpty ? title : oldTag.title,
          trackArtist: artist.isNotEmpty ? artist : oldTag.trackArtist,
          album: album.isNotEmpty ? album : oldTag.album,
          genre: genre.isNotEmpty ? genre : oldTag.genre,
          pictures: newPictures,
          albumArtist: oldTag.albumArtist,
          year: oldTag.year,
          trackNumber: oldTag.trackNumber,
          trackTotal: oldTag.trackTotal,
          discNumber: oldTag.discNumber,
          discTotal: oldTag.discTotal,
          lyrics: oldTag.lyrics,
          duration: oldTag.duration,
          bpm: oldTag.bpm,
        );

        await AudioMetadataUtils.writeTags(path, newTag);
        
        if (_newCoverArt != null || _clearCoverArt) {
          try {
            final repo = container.read(settingsRepositoryProvider);
            final thumbPath = repo.getThumbnailPath(path);
            final thumbFile = File(thumbPath);
            if (thumbFile.existsSync()) {
              FileImage(thumbFile).evict();
              thumbFile.deleteSync();
            }

            // Forcefully remove the thumbnailPath from the current provider state
            // because `copyWith` ignores null values.
            FileItem clearThumb(FileItem item) {
              if (item.path != path) return item;
              return FileItem(
                path: item.path,
                name: item.name,
                type: item.type,
                modified: item.modified,
                sizeBytes: item.sizeBytes,
                thumbnailPath: null, // Explicitly clear
                imageAspectRatio: item.imageAspectRatio,
                itemCount: item.itemCount,
                isExecutable: item.isExecutable,
                hasWritePermission: item.hasWritePermission,
              );
            }

            final currentQueue = container.read(audioQueueProvider);
            container.read(audioQueueProvider.notifier).state = currentQueue.map<FileItem>(clearThumb).toList();

            final playingQueue = container.read(audioPlayingQueueProvider);
            container.read(audioPlayingQueueProvider.notifier).state = playingQueue.map<FileItem>(clearThumb).toList();
          } catch (_) {}
        }

        // Note: We deliberately do NOT call imageCache.clear() here because it would abort 
        // the asynchronous image decodes of files that were updated in previous iterations!

        // Determine the ultimate path
        String ultimatePath = path;

        if (widget.paths.length == 1 && title.isNotEmpty) {
          final dir = p.dirname(path);
          final ext = p.extension(path);
          final newPath = p.join(dir, '$title$ext');
          
          if (path != newPath) {
            try {
              await File(path).rename(newPath);
              ultimatePath = newPath;
              if (widget.onRename != null) {
                widget.onRename!(path, newPath);
              }
            } catch (e) {
              notifier.addLog(taskId, 'Error renaming ${p.basename(path)} to $title$ext: $e');
            }
          }
        } else if (widget.paths.length > 1) {
          final dir = p.dirname(path);
          final ext = p.extension(path);
          final renameValue = _bulkRenameController.text.trim();
          
          String newFileName = p.basenameWithoutExtension(path);
          if (_renameMode == BulkRenameMode.baseName) {
            if (renameValue.isNotEmpty) {
              final fileIndex = widget.paths.indexOf(path);
              newFileName = '${renameValue}_${fileIndex + 1}';
            }
          } else {
            final basename = p.basenameWithoutExtension(path);
            if (_commonPrefix.isNotEmpty && basename.startsWith(_commonPrefix)) {
              newFileName = '$renameValue${basename.substring(_commonPrefix.length)}';
            } else {
              newFileName = '$renameValue$basename';
            }
          }
          
          final newPath = p.join(dir, '$newFileName$ext');
          if (path != newPath) {
            try {
              await File(path).rename(newPath);
              ultimatePath = newPath;
              if (widget.onRename != null) {
                widget.onRename!(path, newPath);
              }
            } catch (e) {
              notifier.addLog(taskId, 'Error renaming ${p.basename(path)} to $newFileName$ext: $e');
            }
          }
        }

        // Force the UI to instantly reflect the new tag data by bypassing the native disk read cache
        // Uses ultimatePath because if the file was renamed, we need to populate the cache for the NEW path
        container.read(audioTagsOverridesProvider(ultimatePath).notifier).state = newTag;

        // Yield to the event loop so the UI can redraw this specific tile instantly
        // and Flutter can process its image decode queue sequentially without starvation.
        await Future.delayed(const Duration(milliseconds: 20));

      } catch (e) {
        notifier.addLog(taskId, 'Error on ${p.basename(path)}: $e');
      }

      processed++;
      notifier.updateItemCounts(taskId, processed, widget.paths.length);
      notifier.updateProgress(taskId, processed / widget.paths.length);
      notifier.updateCurrentItem(taskId, p.basename(path));
    }

    // Run with max concurrency 1 to prevent native audiotags race conditions
    int index = 0;
    Future<void> worker() async {
      while (index < widget.paths.length) {
        if (notifier.isTaskCancelled(taskId)) break;
        final i = index++;
        await processFile(widget.paths[i]);
      }
    }

    await Future.wait(List.generate(1, (_) => worker()));

    // Wait slightly to let any pending UI frames render before we wipe caches
    await Future.delayed(const Duration(milliseconds: 300));

    // Clear global image caches to completely eliminate any lingering phantom cover arts
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (!notifier.isTaskCancelled(taskId)) {
      notifier.completeTask(taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Material(
          type: MaterialType.transparency,
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: const Color(0xFF161616).withOpacity(0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.violet),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCoverArtSection(),
                        const SizedBox(height: 24),
                        if (widget.paths.length == 1) ...[
                          _buildTextField('Title', _titleController, focusNode: _primaryFocusNode),
                          const SizedBox(height: 16),
                        ] else ...[
                          _buildBulkRenameSection(),
                          const SizedBox(height: 16),
                        ],
                        _buildTextField('Artist', _artistController),
                        const SizedBox(height: 16),
                        _buildTextField('Album', _albumController),
                        const SizedBox(height: 16),
                        _buildTextField('Genre', _genreController),
                        if (widget.paths.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Fields left blank will not modify the existing tags of the selected files.',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.paths.length == 1 ? 'EDIT TAGS' : 'BULK EDIT TAGS (${widget.paths.length})',
            style: AppTheme.labelStyle.copyWith(
              letterSpacing: 2.0,
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverArtSection() {
    ImageProvider? imageProvider;
    if (_newCoverArt != null) {
      imageProvider = MemoryImage(_newCoverArt!);
    } else if (!_clearCoverArt && _initialTag?.pictures != null && _initialTag!.pictures.isNotEmpty) {
      imageProvider = MemoryImage(Uint8List.fromList(_initialTag!.pictures.first.bytes));
    }

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              image: imageProvider != null && !_isProcessingImage
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: Center(
              child: _isProcessingImage
                  ? const BubbleLoader(size: 60)
                  : _clearCoverArt
                      ? const Icon(Icons.layers_clear_rounded, size: 60, color: Colors.redAccent)
                      : imageProvider == null
                          ? const Icon(Icons.music_note, size: 60, color: Colors.white24)
                          : null,
            ),
          ),
          if ((imageProvider != null || widget.paths.length > 1) && !_isProcessingImage)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: _clearCoverArt ? AppColors.magenta : Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(
                    _clearCoverArt ? Icons.undo_rounded : Icons.delete_outline, 
                    size: 16, 
                    color: _clearCoverArt ? Colors.white : Colors.redAccent,
                  ),
                  tooltip: _clearCoverArt ? 'Undo Clear Covers' : (widget.paths.length > 1 ? 'Clear Covers for All' : 'Remove Cover'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() {
                      if (_clearCoverArt) {
                        _clearCoverArt = false;
                      } else {
                        _newCoverArt = null;
                        _clearCoverArt = true;
                      }
                    });
                  },
                ),
              ),
            ),
          if (!_isProcessingImage)
            Positioned(
              bottom: -4,
              right: -4,
              child: Material(
                color: AppColors.violet,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _pickImage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool autofocus = false, FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          onSubmitted: (_) => _save(),
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.violet),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkRenameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Name',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRadioButton(BulkRenameMode.prefix, 'Add Prefix'),
            const SizedBox(width: 16),
            _buildRadioButton(BulkRenameMode.baseName, 'Base Name + Counter'),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _renameMode == BulkRenameMode.baseName ? 'Base Name' : 'Prefix Text',
          _bulkRenameController,
          focusNode: _primaryFocusNode,
        ),
        const SizedBox(height: 16),
        _buildPreviewSection(),
      ],
    );
  }

  List<Map<String, String>> _getPreviews() {
    // Show up to 20 previews so it is meaningfully scrollable without hanging on massive lists
    final limit = widget.paths.length > 20 ? 20 : widget.paths.length;
    List<Map<String, String>> previews = [];
    final value = _bulkRenameController.text.trim();

    for (int i = 0; i < limit; i++) {
      final original = p.basename(widget.paths[i]);
      String newName = original;

      final ext = p.extension(original);
      if (_renameMode == BulkRenameMode.baseName) {
        if (value.isNotEmpty) {
          newName = "${value}_${i + 1}$ext";
        }
      } else if (_renameMode == BulkRenameMode.prefix) {
        String base = p.basenameWithoutExtension(original);
        if (_commonPrefix.isNotEmpty && base.startsWith(_commonPrefix)) {
          base = base.substring(_commonPrefix.length);
        }
        newName = "$value$base$ext";
      }

      previews.add({
        'original': original,
        'new': newName,
      });
    }
    return previews;
  }

  Widget _buildPreviewSection() {
    final previews = _getPreviews();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PREVIEW",
          style: GoogleFonts.manrope(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 100),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            shrinkWrap: true,
            itemCount: previews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = previews[index];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      item['original']!,
                      style: GoogleFonts.manrope(color: Colors.white38, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white12),
                  ),
                  Expanded(
                    child: Text(
                      item['new']!,
                      style: GoogleFonts.manrope(color: AppColors.violet, fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRadioButton(BulkRenameMode mode, String label) {
    final isSelected = _renameMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _renameMode = mode;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.violet : Colors.white54,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: isSelected
                ? Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.violet,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isProcessingImage ? null : AppTheme.primaryGradient,
                color: _isProcessingImage ? Colors.white10 : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: _isProcessingImage ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, // Let gradient show
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white38,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Save Tags',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _isProcessingImage ? Colors.white38 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
