import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import '../theme.dart';
import 'video_player_page.dart';
import 'image_viewer_page.dart';
import '../../services/settings_service.dart';

enum _ItemType { folder, image, video, other }

class _GalleryItem {
  final FileSystemEntity entity;
  final _ItemType type;
  String title;
  final DateTime modified;
  int? sizeBytes;
  Duration? duration;
  String? thumbnailPath;
  double? imageAspectRatio;

  _GalleryItem({
    required this.entity,
    required this.type,
    required this.title,
    required this.modified,
    this.sizeBytes,
    this.thumbnailPath,
    this.imageAspectRatio,
  });
}

class GalleryPage extends StatefulWidget {
  final String? initialPath;
  const GalleryPage({Key? key, this.initialPath}) : super(key: key);

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final SettingsService _settingsService = SettingsService();
  final String _homePath = Platform.environment['HOME'] ?? '/';
  late String _currentPath;
  
  List<_GalleryItem> _items = [];
  Set<String> _selectedPaths = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;
  int _totalSizeBytes = 0;

  // Processing state
  bool _isProcessing = false;
  String _processingMessage = "";
  double _processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? _homePath;
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);
    final dir = Directory(_currentPath);
    if (!await dir.exists()) {
      _currentPath = _homePath;
    }

    try {
      final List<FileSystemEntity> entities = await Directory(_currentPath).list().toList();
      final List<_GalleryItem> folders = [];
      final List<_GalleryItem> files = [];

      _totalSizeBytes = 0;

      for (var entity in entities) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue; // Hide hidden files

        final stat = entity.statSync();
        if (entity is Directory) {
          folders.add(_GalleryItem(
            entity: entity,
            type: _ItemType.folder,
            title: name,
            modified: stat.modified,
          ));
        } else if (entity is File) {
          _totalSizeBytes += stat.size as int;
          final ext = p.extension(entity.path).toLowerCase();
          _ItemType type = _ItemType.other;
          if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
            type = _ItemType.image;
          } else if (['.mp4', '.mkv', '.mov', '.avi'].contains(ext)) {
            type = _ItemType.video;
          }

          files.add(_GalleryItem(
            entity: entity,
            type: type,
            title: name,
            modified: stat.modified,
            sizeBytes: stat.size,
          ));
        }
      }

      // Sort: Folders first, then files (by modification date descending)
      folders.sort((a, b) => b.modified.compareTo(a.modified));
      files.sort((a, b) => b.modified.compareTo(a.modified));

      setState(() {
        _items = [...folders, ...files];
        _isLoading = false;
      });

      _generateMetadataAsync();
    } catch (e) {
      debugPrint("Error loading directory: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateMetadataAsync() async {
    for (var item in _items) {
      if (item.type == _ItemType.image && item.imageAspectRatio == null) {
        final path = item.entity.path;
        final cached = _settingsService.imageAspectRatioCache[path];
        if (cached != null) {
          item.imageAspectRatio = cached;
        } else {
          try {
            final session = await FFprobeKit.getMediaInformation(path);
            final info = session.getMediaInformation();
            if (info != null && info.getStreams().isNotEmpty) {
              final stream = info.getStreams().first;
              final w = stream.getWidth() ?? 1;
              final h = stream.getHeight() ?? 1;
              item.imageAspectRatio = w / h;
              _settingsService.saveImageAspectRatio(path, item.imageAspectRatio!);
            }
          } catch (_) {
            item.imageAspectRatio = 1.0;
          }
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
      _selectedPaths.clear();
      _isSelectionMode = false;
    });
    _loadDirectory();
  }

  void _onItemTap(_GalleryItem item) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedPaths.contains(item.entity.path)) {
          _selectedPaths.remove(item.entity.path);
        } else {
          _selectedPaths.add(item.entity.path);
        }
        if (_selectedPaths.isEmpty) _isSelectionMode = false;
      });
    } else {
      if (item.type == _ItemType.folder) {
        _navigateTo(item.entity.path);
      } else if (item.type == _ItemType.image) {
        final images = _items.where((i) => i.type == _ItemType.image).toList();
        final initialIndex = images.indexOf(item);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(
              imagePaths: images.map<String>((i) => i.entity.path).toList(),
              initialIndex: initialIndex,
            ),
          ),
        ).then((_) => _loadDirectory());
      } else if (item.type == _ItemType.video) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerPage(videoPath: item.entity.path),
          ),
        ).then((_) => _loadDirectory());
      }
    }
  }

  void _toggleSelection(_GalleryItem item) {
    setState(() {
      _isSelectionMode = true;
      if (_selectedPaths.contains(item.entity.path)) {
        _selectedPaths.remove(item.entity.path);
      } else {
        _selectedPaths.add(item.entity.path);
      }
      if (_selectedPaths.isEmpty) _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                _buildActionBar(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ShaderMask(
              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                "ONYXCORE",
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(Icons.home, "Home", _homePath),
                _buildSidebarItem(Icons.access_time, "Recent", ""),
                _buildSidebarItem(Icons.star_outline, "Starred", ""),
                _buildSidebarItem(Icons.description_outlined, "Documents", p.join(_homePath, "Documents")),
                _buildSidebarItem(Icons.download_outlined, "Downloads", p.join(_homePath, "Downloads")),
                _buildSidebarItem(Icons.music_note_outlined, "Music", p.join(_homePath, "Music")),
                _buildSidebarItem(Icons.image_outlined, "Pictures", p.join(_homePath, "Pictures")),
                _buildSidebarItem(Icons.videocam_outlined, "Videos", p.join(_homePath, "Videos")),
                _buildSidebarItem(Icons.delete_outline, "Trash", ""),
                
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text("OTHER LOCATIONS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.2)),
                ),
                _buildSidebarItem(Icons.dns_outlined, "Network", ""),

                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text("CLOUD STORAGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.2)),
                ),
                _buildCloudItem("Alex's Cloud", "Connected"),
                _buildSidebarItem(Icons.add, "Add Account", ""),
              ],
            ),
          ),
          
          _buildStorageIndicator(),
          const SizedBox(height: 16),
          _buildOverviewButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCloudItem(String name, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network("https://i.pravatar.cc/150?u=alex", width: 32, height: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(status, style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Storage (60%)", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Text("1.2 TB / 2.0 TB", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              widthFactor: 0.6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: AppTheme.violet.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: InkWell(
          onTap: () {}, // Placeholder
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.auto_graph, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("Overview", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, String path) {
    final bool isActive = _currentPath == path && path.isNotEmpty;
    
    Widget content = Row(
      children: [
        isActive 
          ? _buildGradientWidget(Icon(icon, size: 20, color: Colors.white))
          : Icon(icon, color: AppTheme.textMuted, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: isActive
            ? _buildGradientWidget(
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.manrope(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: () {
          if (path.isNotEmpty) _navigateTo(path);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
          ),
          child: isActive 
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: content,
                ),
              )
            : content,
        ),
      ),
    );
  }

  Widget _buildGradientWidget(Widget child) {
    return ShaderMask(
      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
      child: child,
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          _buildBreadcrumbs(),
          const Spacer(),
          Container(
            width: 320,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: "Search archive...",
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final relPath = _currentPath.replaceFirst(_homePath, "Home");
    final parts = relPath.split('/').where((s) => s.isNotEmpty).toList();
    
    return Row(
      children: parts.asMap().entries.map((entry) {
        final index = entry.key;
        final name = entry.value;
        final isLast = index == parts.length - 1;
        
        return Row(
          children: [
            if (index > 0) 
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
              ),
            InkWell(
              onTap: () {
                final targetRel = parts.sublist(0, index + 1).join('/');
                final targetPath = targetRel.replaceFirst("Home", _homePath);
                _navigateTo(targetPath);
              },
              child: _buildGradientText(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGradientText(String text, {required TextStyle style}) {
    return ShaderMask(
      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ElevatedButton.icon(
                onPressed: _addFolder,
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: Text(
                  "Add",
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildViewOption(Icons.grid_view_rounded, true),
                  _buildViewOption(Icons.sort_rounded, false),
                  _buildViewOption(Icons.filter_list_rounded, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOption(IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: isActive ? Colors.white : AppTheme.textMuted),
    );
  }

  Widget _buildMainContent() {
    if (_items.isEmpty) {
      return const Center(child: Text("This folder is empty", style: TextStyle(color: AppTheme.textMuted)));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 8;
    if (screenWidth < 1300) crossAxisCount = 7;
    if (screenWidth < 1000) crossAxisCount = 5;
    if (screenWidth < 750) crossAxisCount = 4;
    if (screenWidth < 500) crossAxisCount = 3;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return _buildItemCard(_items[index]);
      },
    );
  }

  Widget _buildItemCard(_GalleryItem item) {
    final bool isSelected = _selectedPaths.contains(item.entity.path);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onItemTap(item),
        onLongPress: () => _toggleSelection(item),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.magenta : Colors.white.withOpacity(0.05), width: 1.0),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppTheme.violet.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: -10,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Expanded(
                    child: Center(child: _buildItemPreview(item)),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _truncateMiddle(item.title),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                      style: AppTheme.labelStyle,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview(_GalleryItem item) {
    if (item.type == _ItemType.folder) {
      final config = _getFolderConfig(item.title);
      return _buildArchivalIcon(config.icon, config.colors);
    } else {
      final config = _getFileConfig(item.title);
      return _buildArchivalIcon(config.icon, config.colors);
    }
  }

  // Helper to build the standardized folder/file icon
  Widget _buildArchivalIcon(IconData icon, List<Color> colors) {
    return SizedBox(
      width: 110,
      height: 80,
      child: Stack(
        children: [
          // Folder/File Shape Body
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            top: 10,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  icon, 
                  size: 32, 
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateMiddle(String title, {int maxLength = 50}) {
    if (title.length <= maxLength) return title;
    
    final int extIndex = title.lastIndexOf('.');
    String ext = "";
    String base = title;
    
    // Preserve extension if it's reasonably short (e.g. .pdf, .docx)
    if (extIndex != -1 && (title.length - extIndex) <= 8) {
      ext = title.substring(extIndex);
      base = title.substring(0, extIndex);
    }
    
    final int startChars = maxLength - ext.length - 3; // 3 for '...'
    if (startChars <= 10) return title.substring(0, maxLength - 3) + "...";
    
    return base.substring(0, startChars) + "..." + ext;
  }

  _FolderConfig _getFileConfig(String name) {
    final ext = p.extension(name).toLowerCase();
    
    // Mapping from target UI
    if (ext == ".mp4" || ext == ".mov" || ext == ".mkv") {
      return _FolderConfig(Icons.movie_creation_rounded, [const Color(0xFFFF5252), const Color(0xFFFF1744)]);
    }
    if (ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp") {
      return _FolderConfig(Icons.image_rounded, [const Color(0xFF69F0AE), const Color(0xFF00E676)]);
    }
    if (ext == ".pdf") {
      return _FolderConfig(Icons.picture_as_pdf_rounded, [const Color(0xFF448AFF), const Color(0xFF2979FF)]);
    }
    if (ext == ".xlsx" || ext == ".csv") {
      return _FolderConfig(Icons.table_chart_rounded, [const Color(0xFF00C853), const Color(0xFF00E676)]);
    }
    if (ext == ".zip" || ext == ".rar" || ext == ".7z" || ext == ".tar") {
      return _FolderConfig(Icons.inventory_2_rounded, [const Color(0xFFFF9100), const Color(0xFFFFAB40)]);
    }
    if (ext == ".mp3" || ext == ".wav" || ext == ".flac") {
      return _FolderConfig(Icons.music_note_rounded, [const Color(0xFFE040FB), const Color(0xFFD500F9)]);
    }
    if (ext == ".txt" || ext == ".md") {
      return _FolderConfig(Icons.description_rounded, [const Color(0xFF40C4FF), const Color(0xFF00B0FF)]);
    }
    
    return _FolderConfig(Icons.insert_drive_file_rounded, [const Color(0xFF90A4AE), const Color(0xFF78909C)]);
  }

  _FolderConfig _getFolderConfig(String name) {
    final lowName = name.toLowerCase();
    
    // Exact mapping from target UI
    if (lowName.contains("drive")) {
      return _FolderConfig(Icons.storage_rounded, [const Color(0xFF00C2FF), const Color(0xFF007BFF)]);
    }
    if (lowName.contains("android")) {
      return _FolderConfig(Icons.android_rounded, [const Color(0xFF3DDC84), const Color(0xFF00C853)]);
    }
    if (lowName.contains("desktop")) {
      return _FolderConfig(Icons.desktop_windows_rounded, [const Color(0xFFFFD54F), const Color(0xFFFFA000)]);
    }
    if (lowName.contains("document")) {
      return _FolderConfig(Icons.article_rounded, [const Color(0xFF9575CD), const Color(0xFF673AB7)]);
    }
    if (lowName.contains("download")) {
      return _FolderConfig(Icons.file_download_rounded, [const Color(0xFF4FC3F7), const Color(0xFF0288D1)]);
    }
    if (lowName.contains("music")) {
      return _FolderConfig(Icons.library_music_rounded, [const Color(0xFFF06292), const Color(0xFFE91E63)]);
    }
    if (lowName.contains("picture")) {
      return _FolderConfig(Icons.photo_library_rounded, [const Color(0xFFFFB74D), const Color(0xFFF57C00)]);
    }
    if (lowName.contains("video")) {
      return _FolderConfig(Icons.movie_creation_rounded, [const Color(0xFFFF7043), const Color(0xFFD84315)]);
    }
    if (lowName.contains("snap")) {
      return _FolderConfig(Icons.view_in_ar_rounded, [const Color(0xFFBA68C8), const Color(0xFF8E24AA)]);
    }
    if (lowName.contains("public")) {
      return _FolderConfig(Icons.cloud_done_rounded, [const Color(0xFF4DB6AC), const Color(0xFF00897B)]);
    }
    
    // Generic Folder (Yellow/Gold)
    return _FolderConfig(Icons.folder_rounded, [const Color(0xFFFFC107), const Color(0xFFFFA000)]);
  }

  // Actions
  void _addFolder() async {
    final name = await _showInputDialog("New Folder", "Folder Name");
    if (name != null && name.isNotEmpty) {
      await Directory(p.join(_currentPath, name)).create();
      _loadDirectory();
    }
  }

  void _deleteSelected() async {
    final confirm = await _showConfirmDialog("Delete Items", "Are you sure you want to delete ${_selectedPaths.length} items?");
    if (confirm) {
      for (var path in _selectedPaths) {
        if (FileSystemEntity.typeSync(path) == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      }
      _selectedPaths.clear();
      _isSelectionMode = false;
      _loadDirectory();
    }
  }

  Future<String?> _showInputDialog(String title, String label) => showDialog<String>(
    context: context,
    builder: (ctx) {
      final ctrl = TextEditingController();
      return AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text("CREATE")),
        ],
      );
    }
  );

  Future<bool> _showConfirmDialog(String title, String message) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))),
      ],
    )
  ).then((v) => v ?? false);
}

class _FolderConfig {
  final IconData icon;
  final List<Color> colors;
  _FolderConfig(this.icon, this.colors);
}
