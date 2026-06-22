import 'dart:io' as io;
import 'dart:ui';
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import '../providers/file_picker_notifier.dart';
import 'file_entity_tile.dart';
import 'file_picker_preview_pane.dart';
import 'file_picker_new_folder_dialog.dart';

class CustomFilePickerDialog extends ConsumerStatefulWidget {
  final String? title;
  final bool allowMultiple;
  final List<String>? allowedExtensions;
  final bool saveMode;
  final String? actionText;
  final String? initialFileName;
  final String? initialDirectory;
  final bool pickDirectory;

  const CustomFilePickerDialog({
    this.title,
    this.allowMultiple = false,
    this.allowedExtensions,
    this.saveMode = false,
    this.actionText,
    this.initialFileName,
    this.initialDirectory,
    this.pickDirectory = false,
    super.key,
  });

  static String? _lastSelectedDirectory;

  static Future<List<String>?> show(
    BuildContext context, {
    String? title,
    bool allowMultiple = false,
    List<String>? allowedExtensions,
    bool saveMode = false,
    String? actionText,
    String? initialFileName,
    String? initialDirectory,
    bool pickDirectory = false,
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => CustomFilePickerDialog(
        title: title,
        allowMultiple: allowMultiple,
        allowedExtensions: allowedExtensions,
        saveMode: saveMode,
        actionText: actionText,
        initialFileName: initialFileName,
        initialDirectory: initialDirectory ?? _lastSelectedDirectory,
        pickDirectory: pickDirectory,
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (pickDirectory) {
        _lastSelectedDirectory = result.first;
      } else {
        _lastSelectedDirectory = p.dirname(result.first);
      }
    }

    return result;
  }

  @override
  ConsumerState<CustomFilePickerDialog> createState() =>
      _CustomFilePickerDialogState();
}

class _CustomFilePickerDialogState
    extends ConsumerState<CustomFilePickerDialog> {
  final ScrollController _scrollController = ScrollController();
  late double _width;
  late double _height;
  bool _isResizing = false;
  final TextEditingController _fileNameController = TextEditingController();
  final FocusNode _fileNameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    _width = settings?.filePickerWidth ?? 1000;
    _height = settings?.filePickerHeight ?? 650;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(filePickerProvider.notifier)
          .initialize(
            allowedExtensions: widget.allowedExtensions,
            initialDirectory: widget.initialDirectory,
            pickDirectory: widget.pickDirectory,
          );
    });

    _fileNameController.text = widget.initialFileName ?? '';
    _fileNameController.addListener(() {
      if (widget.saveMode) setState(() {});
    });

    if (widget.saveMode && widget.initialFileName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fileNameFocusNode.requestFocus();
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _fileNameController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: p
                  .basenameWithoutExtension(_fileNameController.text)
                  .length,
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _fileNameFocusNode.dispose();
    _fileNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateFolder() async {
    final currentPath = ref.read(filePickerProvider).value?.currentDirectory;
    if (currentPath == null) return;
    
    final folderName = await showDialog<String>(
      context: context,
      builder: (ctx) => const FilePickerNewFolderDialog(),
    );

    if (folderName != null && folderName.isNotEmpty) {
      final newFolderPath = p.join(currentPath, folderName);
      try {
        await io.Directory(newFolderPath).create();
        // navigate into new directory
        ref.read(filePickerProvider.notifier).goToDirectory(newFolderPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(filePickerProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true): _handleCreateFolder,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
            ref.read(filePickerProvider.notifier).goBack(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
            ref.read(filePickerProvider.notifier).goForward(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_isSelectionValid(stateAsync.value)) {
            _handleOpenOrSave(stateAsync.value);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          child: SizedBox(
            width: _width,
            height: _height,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616).withOpacity(0.98),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 60,
                            offset: const Offset(0, 30),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header
                          _buildHeader(stateAsync.value?.currentDirectory),

                          // Content
                          Expanded(
                            child: Row(
                              children: [
                                // Sidebar
                                _buildSidebar(),

                                // Divider
                                Container(
                                  width: 1,
                                  color: Colors.white.withOpacity(0.05),
                                ),

                                // Main List
                                Expanded(
                                  child: _buildMainContent(stateAsync),
                                ),

                                if (!widget.saveMode && !widget.pickDirectory) ...[
                                  // Preview Pane
                                  Container(
                                    width: 1,
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                  FilePickerPreviewPane(
                                    selectedPaths:
                                        stateAsync.value?.selection.toList() ??
                                        [],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Footer
                          _buildFooter(stateAsync.value),
                        ],
                      ),
                    ),
                  ),
                ),

                // Resize Handle
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _isResizing = true),
                      onPanUpdate: (details) {
                        setState(() {
                          _width = (_width + details.delta.dx).clamp(600, 1600);
                          _height = (_height + details.delta.dy).clamp(
                            400,
                            1200,
                          );
                        });
                      },
                      onPanEnd: (_) {
                        setState(() => _isResizing = false);
                        ref
                            .read(settingsProvider.notifier)
                            .setFilePickerDimensions(_width, _height);
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        padding: const EdgeInsets.all(4),
                        child: CustomPaint(painter: _ResizeHandlePainter()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? currentPath) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Text(
            widget.title ?? (widget.saveMode ? 'SAVE FILE' : 'SELECT FILES'),
            style: AppTheme.labelStyle.copyWith(letterSpacing: 1.5),
          ),
          const Spacer(),
          if (currentPath != null) ...[
            _buildBreadcrumbs(currentPath),
            const SizedBox(width: 12),
            _buildHeaderButton(
              icon: Icons.arrow_upward_rounded,
              onPressed: () => ref.read(filePickerProvider.notifier).goUp(),
              tooltip: 'Go Up',
            ),
          ],
          const SizedBox(width: 16),
          if (widget.pickDirectory) ...[
            _buildHeaderButton(
              icon: Icons.create_new_folder_rounded,
              onPressed: _handleCreateFolder,
              tooltip: 'New Folder',
            ),
            const SizedBox(width: 16),
          ],
          Row(
            children: [
              Text(
                'HIDDEN',
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 24,
                child: OnyxSwitch(
                  value:
                      ref.watch(filePickerProvider).value?.showHiddenFiles ??
                      false,
                  onChanged: (_) =>
                      ref.read(filePickerProvider.notifier).toggleHiddenFiles(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (path == '/') return const Text('/');

    // Show only last 3 parts to save space
    final displayParts = parts.length > 3
        ? parts.sublist(parts.length - 3)
        : parts;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (parts.length > 3) ...[
          const Text('...', style: TextStyle(color: Colors.white24)),
          const Text(' / ', style: TextStyle(color: Colors.white24)),
        ],
        ...displayParts.asMap().entries.map((entry) {
          final isLast = entry.key == displayParts.length - 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: isLast
                    ? null
                    : () {
                        final originalIndex =
                            entry.key +
                            (parts.length > 3 ? parts.length - 3 : 0);
                        final targetPath =
                            '/${parts.sublist(0, originalIndex + 1).join('/')}';
                        ref
                            .read(filePickerProvider.notifier)
                            .goToDirectory(targetPath);
                      },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.manrope(
                      color: isLast ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                const Text('/', style: TextStyle(color: Colors.white10)),
            ],
          );
        }),
      ],
    );
  }

  String _getHomeDirectory() {
    if (io.Platform.isWindows) {
      return io.Platform.environment['USERPROFILE'] ?? 'C:\\';
    }
    return io.Platform.environment['HOME'] ?? '/';
  }

  Widget _buildSidebar() {
    final home = _getHomeDirectory();
    return Container(
      width: 200,
      color: Colors.black.withOpacity(0.1),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSidebarItem('Home', Icons.home_rounded, home),
          _buildSidebarItem(
            'Documents',
            Icons.description_rounded,
            p.join(home, 'Documents'),
          ),
          _buildSidebarItem(
            'Downloads',
            Icons.file_download_rounded,
            p.join(home, 'Downloads'),
          ),
          _buildSidebarItem(
            'Videos',
            Icons.video_library_rounded,
            p.join(home, 'Videos'),
          ),
          _buildSidebarItem(
            'Pictures',
            Icons.image_rounded,
            p.join(home, 'Pictures'),
          ),
          _buildSidebarItem('Root', Icons.storage_rounded, '/'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData icon, String path) {
    final currentPath = ref.watch(filePickerProvider).value?.currentDirectory;
    final isSelected = currentPath == path;

    return InkWell(
      onTap: () => ref.read(filePickerProvider.notifier).goToDirectory(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.magenta : Colors.transparent,
              width: 3,
            ),
          ),
          color: isSelected ? AppColors.magenta.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.magenta : Colors.white38,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(AsyncValue<FilePickerState> stateAsync) {
    return stateAsync.when(
      loading: () => const Center(child: BubbleLoader(size: 60)),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (state) {
        if (state.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
            ref.read(filePickerProvider.notifier).clearError();
          });
        }

        if (state.contents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 48,
                  color: Colors.white.withOpacity(0.05),
                ),
                const SizedBox(height: 16),
                Text(
                  'No items found',
                  style: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Scrollbar(
          controller: _scrollController,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.contents.length,
            itemBuilder: (context, index) {
              final entity = state.contents[index];
              final isSelected = state.selection.contains(entity.path);

              return FileEntityTile(
                entity: entity,
                isSelected: isSelected,
                onTap: () {
                  if (widget.saveMode && entity is File) {
                    _fileNameController.text = p.basename(entity.path);
                    return;
                  }

                  final isShift =
                      HardwareKeyboard.instance.logicalKeysPressed.contains(
                        LogicalKeyboardKey.shiftLeft,
                      ) ||
                      HardwareKeyboard.instance.logicalKeysPressed.contains(
                        LogicalKeyboardKey.shiftRight,
                      );
                  final isCtrl =
                      HardwareKeyboard.instance.logicalKeysPressed.contains(
                        LogicalKeyboardKey.controlLeft,
                      ) ||
                      HardwareKeyboard.instance.logicalKeysPressed.contains(
                        LogicalKeyboardKey.controlRight,
                      );

                  ref
                      .read(filePickerProvider.notifier)
                      .toggleSelection(
                        entity.path,
                        isCtrl: widget.allowMultiple && isCtrl,
                        isShift: widget.allowMultiple && isShift,
                      );
                },
                onDoubleTap: () {
                  if (entity is Directory) {
                    ref
                        .read(filePickerProvider.notifier)
                        .goToDirectory(entity.path);
                  } else if (entity is File) {
                    Navigator.pop(context, [entity]);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  bool _isSelectionValid(FilePickerState? state) {
    if (widget.saveMode) {
      if (_fileNameController.text.trim().isEmpty) return false;
      if (widget.allowedExtensions != null &&
          widget.allowedExtensions!.isNotEmpty) {
        final ext = p
            .extension(_fileNameController.text)
            .toLowerCase()
            .replaceFirst('.', '');
        if (!widget.allowedExtensions!.contains(ext)) return false;
      }
      return true;
    }
    
    if (widget.pickDirectory) {
      if (state == null) return false;
      // if selection is empty, we allow picking the current directory
      if (state.selection.isEmpty) return true;
      for (final path in state.selection) {
        final entityIndex = state.contents.indexWhere((e) => e.path == path);
        if (entityIndex != -1) {
          if (state.contents[entityIndex] is File) return false;
        } else {
          if (io.File(path).existsSync()) return false;
        }
      }
      return true;
    }

    if (state == null || state.selection.isEmpty) return false;
    if (widget.allowedExtensions == null || widget.allowedExtensions!.isEmpty) {
      return true;
    }

    for (final path in state.selection) {
      // Find the entity in contents to check if it's a directory
      final entityIndex = state.contents.indexWhere((e) => e.path == path);

      if (entityIndex != -1) {
        if (state.contents[entityIndex] is Directory) return false;
      } else {
        // If not in current view, check via IO
        if (io.Directory(path).existsSync()) return false;
      }

      final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
      if (!widget.allowedExtensions!.contains(ext)) return false;
    }
    return true;
  }

  Widget _buildFooter(FilePickerState? state) {
    final hasSelection = widget.saveMode
        ? _fileNameController.text.isNotEmpty
        : (widget.pickDirectory ? true : (state?.selection.isNotEmpty ?? false));
    final selectionCount = state?.selection.length ?? 0;
    final isValid = _isSelectionValid(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          if (widget.saveMode)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextField(
                  controller: _fileNameController,
                  focusNode: _fileNameFocusNode,
                  onSubmitted: (_) {
                    if (isValid) _handleOpenOrSave(state);
                  },
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'File name',
                    hintStyle: GoogleFonts.manrope(color: Colors.white24),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.violet),
                    ),
                  ),
                ),
              ),
            )
          else ...[
            if (hasSelection)
              Text(
                '$selectionCount item${selectionCount > 1 ? 's' : ''} selected',
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            if (!isValid && hasSelection)
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.magenta, AppColors.violet],
                ).createShader(bounds),
                child: Text(
                  '* Select only ${widget.allowedExtensions?.join(', ') ?? 'valid'} files',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Spacer(),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'CANCEL',
              style: GoogleFonts.manrope(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildOpenButton(isValid, state),
        ],
      ),
    );
  }

  void _handleOpenOrSave(FilePickerState? state) {
    if (widget.saveMode) {
      if (state == null) return;
      final file = p.join(state.currentDirectory, _fileNameController.text);
      Navigator.pop(context, [file]);
    } else if (widget.pickDirectory) {
      if (state == null) return;
      if (state.selection.isEmpty) {
        Navigator.pop(context, [state.currentDirectory]);
      } else {
        Navigator.pop(context, state.selection.toList());
      }
    } else {
      final service = ref.read(fileSystemServiceProvider);
      final files = state!.selection
          .where((path) => service.getFile(path).existsSync())
          .toList();
      if (files.isNotEmpty) {
        Navigator.pop(context, files);
      }
    }
  }

  Widget _buildOpenButton(bool isValid, FilePickerState? state) {
    return InkWell(
      onTap: isValid ? () => _handleOpenOrSave(state) : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: isValid ? 1.0 : 0.2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.magenta, AppColors.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.actionText ?? (widget.saveMode ? 'SAVE' : 'OPEN'),
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw three diagonal lines for the handle
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.7),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.4, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
