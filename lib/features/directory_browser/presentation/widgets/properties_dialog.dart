import 'dart:ui';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/directory_size_utils.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';

class PropertiesDialog extends ConsumerStatefulWidget {
  final List<String> paths;
  final bool isInTrash;
  const PropertiesDialog({super.key, required this.paths, this.isInTrash = false});

  @override
  ConsumerState<PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends ConsumerState<PropertiesDialog> {
  ReceivePort? _receivePort;
  Isolate? _isolate;
  
  int _currentSize = 0;
  int _currentFilesCount = 0;
  int _currentFoldersCount = 0;
  bool _isCalculating = false;
  bool _hasError = false;

  FileItem? _singleItem;
  String? _restorePath;
  
  @override
  void initState() {
    super.initState();
    _isCalculating = true;
    
    if (widget.paths.length == 1) {
      _loadSingleItem();
    }
    _startIncrementalCalculation();
  }

  Future<void> _loadSingleItem() async {
    final repo = ref.read(directoryRepositoryProvider);
    try {
      final items = await repo.listDirectory(p.dirname(widget.paths.first));
      final item = items.firstWhere((e) => e.path == widget.paths.first);
      if (mounted) {
        setState(() {
          _singleItem = item;
        });
      }
    } catch (e) {
      debugPrint('Error loading single item for properties: $e');
    }
    // Read original restore path from .trashinfo if in Trash
    if (widget.isInTrash) {
      try {
        final name = p.basename(widget.paths.first);
        final trashInfoPath = p.join(
          Platform.environment['HOME'] ?? '',
          '.local', 'share', 'Trash', 'info', '$name.trashinfo',
        );
        final infoFile = File(trashInfoPath);
        if (await infoFile.exists()) {
          final lines = await infoFile.readAsLines();
          for (final line in lines) {
            if (line.startsWith('Path=')) {
              final raw = line.substring(5);
              // URL-decode the path
              final decoded = Uri.decodeFull(raw);
              if (mounted) setState(() => _restorePath = decoded);
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Could not read trashinfo: $e');
      }
    }
  }

  Future<void> _startIncrementalCalculation() async {
    _receivePort = ReceivePort();
    
    _receivePort!.listen((message) {
      if (!mounted) return;
      if (message is DirectorySizeUpdate) {
        setState(() {
          _currentSize = message.size;
          _currentFilesCount = message.filesCount;
          _currentFoldersCount = message.foldersCount;
          if (message.isFinished) {
            _isCalculating = false;
            _cleanupIsolate();
          }
        });
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _isCalculating = false;
        _hasError = true;
      });
      _cleanupIsolate();
    });

    try {
      _isolate = await Isolate.spawn(
        calculateDirectorySizeIncremental,
        DirectorySizeArgs(
          paths: widget.paths,
          sendPort: _receivePort!.sendPort,
          updateFrequency: 500,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalculating = false;
        _hasError = true;
      });
    }
  }

  void _cleanupIsolate() {
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  @override
  void dispose() {
    _cleanupIsolate();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy HH:mm:ss').format(date);
  }

  String _getParentFolder() {
    if (widget.paths.isEmpty) return '/';
    return p.dirname(widget.paths.first);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMulti = widget.paths.length > 1;
    final String title = widget.paths.map((path) => p.basename(path)).join(", ");

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 420,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Stack(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Icon and Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildHeaderIcon(isMulti),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _buildSizeInfo(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Details Sections
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSection([
                          _buildRow('Parent Folder', 
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getParentFolder(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                if (!widget.isInTrash)
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                    color: Colors.white54,
                                    onPressed: () {
                                      final parentPath = _getParentFolder();
                                      Navigator.of(context).pop();
                                      ref.read(navigationProvider.notifier).navigateTo(parentPath);
                                      ref.read(currentPathProvider.notifier).state = parentPath;
                                    },
                                  ),
                              ],
                            ),
                            isBottom: !isMulti && (!widget.isInTrash || _restorePath == null),
                          ),
                          if (widget.isInTrash && _restorePath != null)
                            _buildRow(
                              'Restore Path',
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _restorePath!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        color: AppColors.violet,
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              isBottom: true,
                            ),
                        ]),
                        if (!isMulti && _singleItem != null) ...[
                          const SizedBox(height: 16),
                          _buildSection([
                            _buildRow('Modified', 
                              Text(
                                _formatDate(_singleItem!.modified),
                                style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            _buildRow('Created', 
                              Text(
                                _formatDate(_singleItem!.modified), // Fallback
                                style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                              ),
                              isBottom: true,
                            ),
                          ]),
                        ],
                      ],
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

  Widget _buildHeaderIcon(bool isMulti) {
    if (isMulti) {
      return Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.copy_all_rounded, size: 48, color: Colors.indigoAccent),
        ),
      );
    }
    
    final isFolder = FileSystemEntity.isDirectorySync(widget.paths.first);
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: isFolder ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          isFolder ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
          size: 48,
          color: isFolder ? Colors.blueAccent : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildRow(String label, Widget content, {bool isBottom = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isBottom ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildSizeInfo() {
    if (_hasError) {
      return Text('Size: Unknown (Permission Denied)', style: GoogleFonts.manrope(color: Colors.white54, fontSize: 14));
    }

    final totalItems = _currentFilesCount + _currentFoldersCount;
    String detailText = '${NumberFormat.decimalPattern().format(totalItems)} items';
    if (_currentFoldersCount > 0) {
      detailText = '${NumberFormat.decimalPattern().format(_currentFoldersCount)} folders, ${NumberFormat.decimalPattern().format(_currentFilesCount)} files';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isCalculating) ...[
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
          const SizedBox(width: 8),
        ],
        Text(
          '$detailText, totalling ${formatBytes(_currentSize)}',
          style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
