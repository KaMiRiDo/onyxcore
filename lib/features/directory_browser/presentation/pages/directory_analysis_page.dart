import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_analysis_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';

class DirectoryAnalysisPage extends ConsumerWidget {
  final String path;

  const DirectoryAnalysisPage({super.key, required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(directoryAnalysisProvider(path));

    return Container(
      color: AppColors.background,
      child: analysisAsync.when(
        data: (result) => _AnalysisView(result: result),
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.violet),
              const SizedBox(height: 24),
              const Text('Analyzing Directory...', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel Analysis'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textBody,
                  side: const BorderSide(color: AppColors.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  ref.read(isAnalysisActiveProvider.notifier).set(false);
                },
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Text('Error analyzing directory:\n$err', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

class _AnalysisView extends ConsumerWidget {
  final DirectoryAnalysisResult result;

  const _AnalysisView({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildHeader(),
        const SizedBox(height: 48),
        _buildCategoryDeepDive(),
        const SizedBox(height: 48),
        _buildLargeFilesArchive(),
      ],
    );
  }

  Widget _buildHeader() {
    final folderName = p.basename(result.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          folderName.isEmpty ? result.path : folderName,
          style: const TextStyle(
            color: AppColors.textBody,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.path,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDeepDive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY DEEP DIVE',
          style: TextStyle(
            color: AppColors.textMuted.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _CategoryCard(type: FileItemType.image, title: 'Images', stats: result.categoryStats[FileItemType.image]!)),
            const SizedBox(width: 16),
            Expanded(child: _CategoryCard(type: FileItemType.video, title: 'Videos', stats: result.categoryStats[FileItemType.video]!)),
            const SizedBox(width: 16),
            Expanded(child: _CategoryCard(type: FileItemType.audio, title: 'Music', stats: result.categoryStats[FileItemType.audio]!)),
            const SizedBox(width: 16),
            Expanded(child: _CategoryCard(type: FileItemType.document, title: 'Documents', stats: result.categoryStats[FileItemType.document]!)),
          ],
        ),
      ],
    );
  }

  Widget _buildLargeFilesArchive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LARGE FILES ARCHIVE',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('NAME', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text('TYPE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text('SIZE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text('MODIFIED', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderColor),
              // List
              if (result.topLargeFiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No large files found.', style: TextStyle(color: AppColors.textMuted))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.topLargeFiles.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderColor),
                  itemBuilder: (context, index) {
                    final item = result.topLargeFiles[index];
                    return _LargeFileRow(
                      item: item,
                      index: index,
                      allPaths: result.topLargeFiles.map((e) => e.path).toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final FileItemType type;
  final String title;
  final CategoryStats stats;

  const _CategoryCard({required this.type, required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    FileIconConfig config;
    switch (type) {
      case FileItemType.image: config = FileIconConfig(Icons.image_rounded, [const Color(0xFFD32F2F), const Color(0xFFFF5252)]); break;
      case FileItemType.video: config = FileIconConfig(Icons.movie_rounded, [const Color(0xFF1565C0), const Color(0xFF448AFF)]); break;
      case FileItemType.audio: config = FileIconConfig(Icons.music_note_rounded, [const Color(0xFF2E7D32), const Color(0xFF69F0AE)]); break;
      case FileItemType.document: config = FileIconConfig(Icons.description_rounded, [const Color(0xFFF57F17), const Color(0xFFFFD600)]); break;
      default: config = FileIconConfig(Icons.insert_drive_file_rounded, [AppColors.textMuted, AppColors.textMuted]); break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: config.colors.first.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: config.colors.first.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: config.colors.first, size: 24),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textBody,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.count.toString()} items • ${StringUtils.formatBytes(stats.totalBytes)}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeFileRow extends ConsumerWidget {
  final FileStatWithInfo item;
  final int index;
  final List<String> allPaths;

  const _LargeFileRow({required this.item, required this.index, required this.allPaths});

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _handleSelectionTap(WidgetRef ref) {
    final isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                    HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
    final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                   HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);

    ref.read(selectionProvider.notifier).onItemTap(
      currentIndex: index,
      allPaths: allPaths,
      isShift: isShift,
      isCtrl: isCtrl,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = getFileIconConfig(item.name);
    final isSelected = ref.watch(selectionProvider).selectedPaths.contains(item.path);

    final fileItem = FileItem(
      path: item.path,
      name: item.name,
      type: item.type,
      modified: item.stat.modified,
      sizeBytes: item.stat.size,
    );
    
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (!isSelected) {
          ref.read(selectionProvider.notifier).select(item.path);
        }
      },
      child: InkWell(
        onTap: () => _handleSelectionTap(ref),
        onDoubleTap: () {
          ref.read(previewFileProvider.notifier).state = fileItem;
        },
        child: Container(
          color: isSelected ? AppColors.violet.withOpacity(0.1) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: config.colors.first.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(config.icon, size: 18, color: config.colors.first),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(color: AppColors.textBody, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1, 
              child: Text(
                '${item.type.name[0].toUpperCase()}${item.type.name.substring(1)} File', 
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(flex: 1, child: Text(StringUtils.formatBytes(item.stat.size), style: const TextStyle(color: AppColors.textBody, fontWeight: FontWeight.w600))),
            Expanded(flex: 1, child: Text(_formatDate(item.stat.modified), style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
            const SizedBox(width: 16),
            const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
      ),
    );
  }
}
