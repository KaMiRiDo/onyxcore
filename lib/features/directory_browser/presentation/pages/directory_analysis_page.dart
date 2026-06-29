import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/core/utils/directory_size_utils.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_analysis_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';

import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
final analysisCurrentPathProvider = StateProvider.family<String, String>((ref, initialPath) => initialPath);

final sizeFilterProvider = StateProvider<int?>((ref) => null);
final typeFilterProvider = StateProvider<Set<FileItemType>>((ref) => {});
final extensionFilterProvider = StateProvider<Set<String>>((ref) => {});

final availableExtensionsProvider = Provider.family<Set<String>, String>((ref, analysisPath) {
  final types = ref.watch(typeFilterProvider);
  final analysis = ref.watch(directoryAnalysisProvider(analysisPath)).value;
  if (analysis == null) return {};

  final exts = <String>{};
  for (final file in analysis.allFiles) {
    if (types.isEmpty || types.contains(file.type)) {
      final ext = p.extension(file.name).toLowerCase();
      if (ext.isNotEmpty) {
        exts.add(ext);
      }
    }
  }
  return exts;
});

class BrowserItem {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final FileItemType? type;
  final DateTime modified;

  BrowserItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    this.type,
    required this.modified,
  });
}

final displayedItemsPageProvider = StateProvider.autoDispose.family<int, String>((ref, path) => 50);

// Args for the heavy filter-only isolate step (no currentPath — that's cheap)
class _FilterOnlyArgs {
  final List<FileStatWithInfo> allFiles;
  final Set<FileItemType> typeFilter;
  final Set<String> extFilter;
  final int? sizeFilter;

  _FilterOnlyArgs({
    required this.allFiles,
    required this.typeFilter,
    required this.extFilter,
    required this.sizeFilter,
  });
}

// Runs in isolate: only applies type/size/ext filters — no path grouping
List<FileStatWithInfo> _computeFilterOnly(_FilterOnlyArgs args) {
  Iterable<FileStatWithInfo> files = args.allFiles;

  if (args.sizeFilter != null) {
    final bytes = args.sizeFilter! * 1024 * 1024;
    files = files.where((f) => f.stat.size > bytes);
  }
  if (args.typeFilter.isNotEmpty) {
    files = files.where((f) =>
      args.typeFilter.contains(f.type) ||
      (args.typeFilter.contains(FileItemType.other) && f.type == FileItemType.archive)
    );
  }
  if (args.extFilter.isNotEmpty) {
    files = files.where((f) => args.extFilter.contains(p.extension(f.name).toLowerCase()));
  }

  return files.toList();
}

// Fast dirname using pure string ops (avoids p.dirname overhead for 500K+ calls)
String _fastDirname(String path) {
  final idx = path.lastIndexOf('/');
  if (idx < 0) return '.';
  if (idx == 0) return '/';
  return path.substring(0, idx);
}

// Groups pre-filtered files by current path using fast string prefix matching.
// Replaces p.isWithin / p.relative / p.split / p.join with simple indexOf/substring
// — gives 5-10x speedup for large filtered sets.
List<BrowserItem> _groupByCurrentPath(List<FileStatWithInfo> filteredFiles, String currentPath) {
  // Build prefix once — avoids repeated string concatenation in the loop
  final prefix = currentPath.endsWith('/') ? currentPath : '$currentPath/';
  final items = <String, BrowserItem>{};

  for (final f in filteredFiles) {
    final dir = _fastDirname(f.path);
    if (dir == currentPath) {
      // Direct child file in current directory
      items[f.path] = BrowserItem(
        path: f.path,
        name: f.name,
        isDirectory: false,
        size: f.stat.size,
        type: f.type,
        modified: f.stat.modified,
      );
    } else if (f.path.startsWith(prefix)) {
      // File is inside a subdirectory — extract top-level folder name
      final rest = f.path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash < 0) continue; // no subfolder separator — skip
      final topFolder = rest.substring(0, slash);
      final folderPath = '$prefix$topFolder';

      if (items.containsKey(folderPath)) {
        final existing = items[folderPath]!;
        items[folderPath] = BrowserItem(
          path: folderPath,
          name: topFolder,
          isDirectory: true,
          size: existing.size + f.stat.size,
          modified: existing.modified.isAfter(f.stat.modified) ? existing.modified : f.stat.modified,
        );
      } else {
        items[folderPath] = BrowserItem(
          path: folderPath,
          name: topFolder,
          isDirectory: true,
          size: f.stat.size,
          modified: f.stat.modified,
        );
      }
    }
  }

  return items.values.toList()..sort((a, b) => b.size.compareTo(a.size));
}

// Args for compute()-based grouping
class _GroupArgs {
  final List<FileStatWithInfo> filteredFiles;
  final String currentPath;
  _GroupArgs(this.filteredFiles, this.currentPath);
}

List<BrowserItem> _computeGroupByPath(_GroupArgs args) =>
    _groupByCurrentPath(args.filteredFiles, args.currentPath);

/// Layer 1 — Heavy: filters all files in a background isolate via compute().
/// Only re-runs when the raw file list OR filter settings change.
final filteredFilesProvider = FutureProvider.family<List<FileStatWithInfo>, String>((ref, analysisPath) async {
  final analysis = ref.watch(directoryAnalysisProvider(analysisPath)).value;
  if (analysis == null) return [];

  final typeFilter = ref.watch(typeFilterProvider);
  final extFilter = ref.watch(extensionFilterProvider);
  final sizeFilter = ref.watch(sizeFilterProvider);

  return compute(_computeFilterOnly, _FilterOnlyArgs(
    allFiles: analysis.allFiles,
    typeFilter: typeFilter,
    extFilter: extFilter,
    sizeFilter: sizeFilter,
  ));
});

/// Layer 2 — Async grouping: groups the pre-filtered files by current path in a
/// background isolate. Navigation changes ONLY trigger this provider (not Layer 1).
/// The UI shows previous data while this runs — navigation feels instant.
final displayedItemsProvider = FutureProvider.family<List<BrowserItem>, String>((ref, analysisPath) async {
  final filteredFiles = await ref.watch(filteredFilesProvider(analysisPath).future);
  final currentPath = ref.watch(analysisCurrentPathProvider(analysisPath));

  // Offload to isolate for large sets; inline for small sets (avoids isolate spawn overhead)
  if (filteredFiles.length < 500) {
    return _groupByCurrentPath(filteredFiles, currentPath);
  }
  return compute(_computeGroupByPath, _GroupArgs(filteredFiles, currentPath));
});

class DirectoryAnalysisPage extends ConsumerWidget {
  final String path;

  const DirectoryAnalysisPage({super.key, required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(directoryAnalysisProvider(path));

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            HardwareKeyboard.instance.isAltPressed) {
          ref.read(isAnalysisActiveProvider.notifier).set(false);
          ref.invalidate(directoryAnalysisProvider(path));
          ref.invalidate(analysisCurrentPathProvider(path));
          ref.invalidate(filteredFilesProvider(path));
          ref.invalidate(displayedItemsProvider(path));
          ref.invalidate(typeFilterProvider);
          ref.invalidate(sizeFilterProvider);
          ref.invalidate(extensionFilterProvider);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onSecondaryTapUp: (_) {},
        onSecondaryTapDown: (_) {},
        child: Container(
          color: AppColors.background,
          child: analysisAsync.when(
          data: (result) => _AnalysisView(result: result, path: path),
          loading: () {
            final progress = ref.watch(directoryAnalysisProgressProvider(path));
            return Center(
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Match properties dialog overlay color
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    const CircularBubbleLoader(size: 48),
                    const SizedBox(height: 24),
                    const Text(
                      'Analysis in progress ...',
                      style: TextStyle(
                        color: AppColors.textBody,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total files:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(
                          progress != null ? NumberFormat.decimalPattern().format(progress.totalItems) : '0',
                          style: const TextStyle(color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total size:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(
                          progress != null ? formatBytes(progress.totalBytes) : '0 B',
                          style: const TextStyle(color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        ref.read(isAnalysisActiveProvider.notifier).set(false);
                        ref.invalidate(directoryAnalysisProvider(path));
                        ref.invalidate(analysisCurrentPathProvider(path));
                        ref.invalidate(displayedItemsProvider(path));
                        ref.invalidate(typeFilterProvider);
                        ref.invalidate(sizeFilterProvider);
                        ref.invalidate(extensionFilterProvider);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.violet,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
          error: (err, stack) => Center(
            child: Text(
              'Error analyzing directory:\n$err',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _AnalysisView extends ConsumerWidget {
  final DirectoryAnalysisResult result;
  final String path;

  const _AnalysisView({required this.result, required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildOverviewSection(),
        const SizedBox(height: 32),
        _buildLargeFilesArchive(path),
      ],
    );
  }

  Widget _buildOverviewSection() {
    final folderName = p.basename(result.path);
    final isRoot = folderName.isEmpty;
    final displayName = isRoot ? result.path : folderName;

    final percentages = <FileItemType, double>{};
    if (result.totalBytes > 0) {
      for (final type in FileItemType.values) {
        if (result.categoryStats.containsKey(type)) {
          percentages[type] = result.categoryStats[type]!.totalBytes / result.totalBytes;
        }
      }
    }

    final rawOtherStats = result.categoryStats[FileItemType.other] ?? const CategoryStats();
    final combinedOtherStats = CategoryStats(
      count: rawOtherStats.count,
      totalBytes: rawOtherStats.totalBytes,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.textBody,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.path,
                  style: TextStyle(
                    color: AppColors.textMuted.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(150, 150),
                  painter: _DonutChartPainter(percentages: percentages, strokeWidth: 14),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Storage',
                      style: TextStyle(
                        color: AppColors.textMuted.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      StringUtils.formatBytes(result.totalBytes),
                      style: const TextStyle(
                        color: AppColors.textBody,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.totalItems} items',
                      style: TextStyle(
                        color: AppColors.textMuted.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: _CategoryCard(
                    type: FileItemType.image,
                    title: 'Images',
                    stats: result.categoryStats[FileItemType.image]!,
                    totalBytes: result.totalBytes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    type: FileItemType.video,
                    title: 'Videos',
                    stats: result.categoryStats[FileItemType.video]!,
                    totalBytes: result.totalBytes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    type: FileItemType.audio,
                    title: 'Music',
                    stats: result.categoryStats[FileItemType.audio]!,
                    totalBytes: result.totalBytes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    type: FileItemType.document,
                    title: 'Documents',
                    stats: result.categoryStats[FileItemType.document]!,
                    totalBytes: result.totalBytes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    type: FileItemType.archive,
                    title: 'Archives',
                    stats: result.categoryStats[FileItemType.archive] ?? const CategoryStats(),
                    totalBytes: result.totalBytes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    type: FileItemType.other,
                    title: 'Other',
                    stats: combinedOtherStats,
                    totalBytes: result.totalBytes,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeFilesArchive(String path) {
    Widget buildColHeader(String title) {
      return Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textBody,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.unfold_more_rounded, size: 14, color: AppColors.textMuted),
        ],
      );
    }

    List<Widget> buildBreadcrumbSegments(WidgetRef ref, String basePath, String currentPath) {
      final relative = p.relative(currentPath, from: basePath);
      final parts = p.split(relative);
      final widgets = <Widget>[];
      var accumPath = basePath;

      for (int i = 0; i < parts.length; i++) {
        accumPath = p.join(accumPath, parts[i]);
        final isLast = i == parts.length - 1;
        final currentAccumPath = accumPath; // capture for closure
        
        widgets.add(
          InkWell(
            onTap: isLast ? null : () {
              ref.read(displayedItemsPageProvider(basePath).notifier).state = 50;
              ref.read(analysisCurrentPathProvider(basePath).notifier).state = currentAccumPath;
            },
            child: Text(
              parts[i],
              style: TextStyle(
                color: isLast ? AppColors.textBody : AppColors.violet,
                fontSize: 12,
                fontWeight: isLast ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          )
        );

        if (!isLast) {
          widgets.add(const Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)));
        }
      }
      return widgets;
    }

    return Consumer(
      builder: (context, ref, _) {
        final itemsAsync = ref.watch(displayedItemsProvider(path));

        // Show CircularBubbleLoader only on the very first load (no previous data yet)
        if (!itemsAsync.hasValue) {
          if (itemsAsync.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularBubbleLoader(size: 36)),
            );
          }
          if (itemsAsync.hasError) {
            return Padding(
              padding: const EdgeInsets.all(48),
              child: Center(child: Text('Error: ${itemsAsync.error}', style: const TextStyle(color: AppColors.error))),
            );
          }
        }

        // For navigation and filter changes: use previous or current data — no spinner!
        final items = itemsAsync.value ?? [];

        final page = ref.watch(displayedItemsPageProvider(path));
        final displayedCount = math.min(items.length, page);
        final displayedItems = items.take(displayedCount).toList();

        final selectedPaths = ref.watch(selectionProvider).selectedPaths;
        final selectedItems = items.where((item) => selectedPaths.contains(item.path)).toList();

        final selectedCount = selectedItems.length;
        final selectedSize = selectedItems.fold<int>(0, (prev, item) => prev + item.size);

        final currentPath = ref.watch(analysisCurrentPathProvider(path));
        final allPaths = items.map((e) => e.path).toList();
        final parentTotalSize = items.fold<int>(0, (prev, element) => prev + element.size);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Path: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    InkWell(
                      onTap: () {
                        ref.read(displayedItemsPageProvider(path).notifier).state = 50;
                        ref.read(analysisCurrentPathProvider(path).notifier).state = path;
                      },
                      child: Text(p.basename(path).isEmpty ? path : p.basename(path), style: TextStyle(color: currentPath == path ? AppColors.textBody : AppColors.violet, fontSize: 12, fontWeight: currentPath == path ? FontWeight.w400 : FontWeight.w600)),
                    ),
                    if (currentPath != path) ...[
                      const Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ...buildBreadcrumbSegments(ref, path, currentPath),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.filter_list_rounded, size: 16, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Text('Filter', style: TextStyle(color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const _SizeFilterDropdown(),
                    const SizedBox(width: 8),
                    const _TypeFilterDropdown(),
                    const SizedBox(width: 8),
                    _ExtensionFilterDropdown(analysisPath: path),
                    const SizedBox(width: 16),
                    const _FilterButton(
                      icon: Icons.search_rounded,
                      label: 'Duplicate Finder',
                    ),
                  ],
                ),
                if (selectedCount > 0) ...[
                  Builder(
                    builder: (context) {
                      final sizeStr = StringUtils.formatBytes(selectedSize);
                      final parts = sizeStr.split(' ');
                      final numberPart = parts.isNotEmpty ? parts[0] : '0';
                      final unitPart = parts.length > 1 ? parts[1] : '';

                      return Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$selectedCount items selected    ',
                              style: TextStyle(
                                color: AppColors.textBody.withOpacity(0.4),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.redAccent, Colors.orangeAccent],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds),
                              child: RichText(
                                text: TextSpan(
                                  text: numberPart,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1.0,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' $unitPart',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ] else
                  const Spacer(),
                if (selectedCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: AppColors.error,
                        onTap: () async {
                          final paths = selectedPaths.toList();
                          if (paths.isEmpty) return;
                          
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => _AnalysisDeleteDialog(
                              filesCount: selectedItems.where((i) => !i.isDirectory).length,
                              foldersCount: selectedItems.where((i) => i.isDirectory).length,
                              totalSize: StringUtils.formatBytes(selectedSize),
                            ),
                          );

                          if (result != null) {
                            final isPermanent = result;
                            ref.read(taskProvider.notifier).addTask(
                              title: isPermanent ? 'Deleting ${paths.length} items' : 'Moving ${paths.length} items to Trash',
                              subtitle: isPermanent ? 'Permanent deletion' : 'Trash',
                              sourcePaths: paths,
                              isLight: true,
                            );
                            ref.read(directoryRepositoryProvider).deleteItems(paths, permanent: isPermanent);
                            ref.read(selectionProvider.notifier).deselectAll();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.drive_file_move_outline,
                        label: 'Move',
                        color: Colors.cyan,
                        onTap: () async {
                          final paths = selectedPaths.toList();
                          if (paths.isEmpty) return;

                          final destinationList = await CustomFilePickerDialog.show(
                            context,
                            title: 'SELECT DESTINATION',
                            pickDirectory: true,
                          );

                          if (destinationList == null || destinationList.isEmpty) return;
                          final targetDir = destinationList.first;

                          final repo = ref.read(directoryRepositoryProvider);
                          final taskId = ref.read(taskProvider.notifier).addTask(
                            title: 'Moving ${paths.length} items',
                            subtitle: targetDir,
                            sourcePaths: paths,
                          );

                          for (final source in paths) {
                            final name = p.basename(source);
                            final target = p.join(targetDir, name);
                            try {
                              await repo.moveItemTo(source, target, taskId: taskId);
                            } catch (e) {
                              ref.read(taskProvider.notifier).addLog(taskId, 'Failed to move $name: $e');
                            }
                          }
                          ref.read(taskProvider.notifier).completeTask(taskId);
                          ref.read(selectionProvider.notifier).deselectAll();
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        color: AppColors.success,
                        onTap: () async {
                          final paths = selectedPaths.toList();
                          if (paths.isEmpty) return;

                          final destinationList = await CustomFilePickerDialog.show(
                            context,
                            title: 'SELECT DESTINATION',
                            pickDirectory: true,
                          );

                          if (destinationList == null || destinationList.isEmpty) return;
                          final targetDir = destinationList.first;

                          final repo = ref.read(directoryRepositoryProvider);
                          final taskId = ref.read(taskProvider.notifier).addTask(
                            title: 'Copying ${paths.length} items',
                            subtitle: targetDir,
                            sourcePaths: paths,
                          );

                          for (final source in paths) {
                            final name = p.basename(source);
                            final target = p.join(targetDir, name);
                            try {
                              await repo.copyItemTo(source, target, taskId: taskId);
                            } catch (e) {
                              ref.read(taskProvider.notifier).addLog(taskId, 'Failed to copy $name: $e');
                            }
                          }
                          ref.read(taskProvider.notifier).completeTask(taskId);
                          ref.read(selectionProvider.notifier).deselectAll();
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  // Table Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              tristate: true,
                              value: selectedCount == 0
                                  ? false
                                  : (selectedCount == items.length
                                      ? true
                                      : null),
                              activeColor: AppColors.violet,
                              side: const BorderSide(
                                color: Colors.white54,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                if (selectedCount > 0) {
                                  ref.read(selectionProvider.notifier).deselect(
                                      items.map((e) => e.path).toList());
                                } else {
                                  ref.read(selectionProvider.notifier).selectMultiple(
                                      items.map((e) => e.path).toList());
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: buildColHeader('Name'),
                          ),
                          Expanded(
                            flex: 1,
                            child: buildColHeader('Type'),
                          ),
                          Expanded(
                            flex: 1,
                            child: buildColHeader('Size'),
                          ),
                          Expanded(
                            flex: 1,
                            child: buildColHeader('Last Modified'),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1, color: AppColors.borderColor),
                  // List / Grid
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No items found matching filters.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedItems.length + (displayedCount < items.length ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppColors.borderColor),
                      itemBuilder: (context, index) {
                        if (index == displayedItems.length) {
                           return InkWell(
                             onTap: () {
                               ref.read(displayedItemsPageProvider(path).notifier).update((state) => state + 50);
                             },
                             child: Container(
                               padding: const EdgeInsets.symmetric(vertical: 24),
                               alignment: Alignment.center,
                               child: const Text('Load More', style: TextStyle(color: AppColors.violet, fontWeight: FontWeight.w600)),
                             ),
                           );
                        }
                        return _BrowserItemRow(
                          item: displayedItems[index],
                          analysisPath: path,
                          allPaths: allPaths,
                          parentTotalSize: parentTotalSize,
                        );
                      },
                    )
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends ConsumerStatefulWidget {
  final FileItemType type;
  final String title;
  final CategoryStats stats;
  final int totalBytes;

  const _CategoryCard({
    required this.type,
    required this.title,
    required this.stats,
    required this.totalBytes,
  });

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    FileIconConfig config;
    switch (widget.type) {
      case FileItemType.image:
        config = FileIconConfig(Icons.image_rounded, [
          const Color(0xFF2E7D32),
          const Color(0xFF69F0AE),
        ]);
        break;
      case FileItemType.video:
        config = FileIconConfig(Icons.movie_creation_rounded, [
          const Color(0xFFD32F2F),
          const Color(0xFFFF5252),
        ]);
        break;
      case FileItemType.audio:
        config = FileIconConfig(Icons.music_note_rounded, [
          const Color(0xFF7B1FA2),
          const Color(0xFFE040FB),
        ]);
        break;
      case FileItemType.document:
        config = FileIconConfig(Icons.picture_as_pdf_rounded, [
          const Color(0xFF1565C0),
          const Color(0xFF448AFF),
        ]);
        break;
      case FileItemType.archive:
        config = FileIconConfig(Icons.inventory_2_rounded, [
          const Color(0xFFFF6F00),
          const Color(0xFFFFAB40),
        ]);
        break;
      case FileItemType.other:
        config = FileIconConfig(Icons.insert_drive_file_rounded, [
          const Color(0xFF546E7A),
          const Color(0xFF90A4AE),
        ]);
        break;
      default:
        config = FileIconConfig(Icons.insert_drive_file_rounded, [
          AppColors.textMuted,
          AppColors.textMuted,
        ]);
        break;
    }

    final percentage = widget.totalBytes > 0 
        ? widget.stats.totalBytes / widget.totalBytes 
        : 0.0;

    final activeTypes = ref.watch(typeFilterProvider);
    final isActive = activeTypes.contains(widget.type);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          final types = Set<FileItemType>.from(ref.read(typeFilterProvider));
          if (types.contains(widget.type)) {
            types.remove(widget.type);
          } else {
            types.add(widget.type);
          }
          ref.read(typeFilterProvider.notifier).state = types;
        },
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: isActive 
              ? config.colors.first.withOpacity(0.1) 
              : Colors.white.withOpacity(0.02),
          border: Border.all(
            color: isActive 
                ? config.colors.first.withOpacity(0.5) 
                : (_isHovered 
                    ? config.colors.first.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.05)),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: (_isHovered || isActive) ? [
            BoxShadow(
              color: config.colors.first.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: config.colors.first.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(config.icon, color: config.colors.first, size: 20),
                ),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: config.colors.first,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textBody,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.stats.count} items • ${StringUtils.formatBytes(widget.stats.totalBytes)}',
              style: TextStyle(
                color: AppColors.textMuted.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage.toDouble(),
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(config.colors.first),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _BrowserItemRow extends ConsumerStatefulWidget {
  final BrowserItem item;
  final String analysisPath;
  final List<String> allPaths;
  final int parentTotalSize;

  const _BrowserItemRow({
    required this.item,
    required this.analysisPath,
    required this.allPaths,
    required this.parentTotalSize,
  });

  @override
  ConsumerState<_BrowserItemRow> createState() => _BrowserItemRowState();
}

class _BrowserItemRowState extends ConsumerState<_BrowserItemRow> {
  bool _isHovered = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _handleSelectionTap(WidgetRef ref) {
    final isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
    
    // Always true to enable checklist-style toggling
    final isCtrl = true;

    final currentIndex = widget.allPaths.indexOf(widget.item.path);
    if (currentIndex != -1) {
      ref.read(selectionProvider.notifier).onItemTap(
            currentIndex: currentIndex,
            allPaths: widget.allPaths,
            isShift: isShift,
            isCtrl: isCtrl,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.item.isDirectory 
      ? FileIconConfig(Icons.folder_rounded, [AppColors.violet, AppColors.violet])
      : getFileIconConfig(widget.item.name);
      
    final isSelected = ref.watch(selectionProvider).selectedPaths.contains(widget.item.path);
    final percentage = widget.parentTotalSize > 0 ? widget.item.size / widget.parentTotalSize : 0.0;

    final startColor = AppColors.cyan;
    final fullEndColor = AppColors.indigo;
    final endColor = Color.lerp(startColor, fullEndColor, percentage) ?? startColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          if (!isSelected) {
            ref.read(selectionProvider.notifier).select(widget.item.path);
          }
        },
        child: InkWell(
          onTap: () {
            _handleSelectionTap(ref);
          },
          onDoubleTap: () {
            if (widget.item.isDirectory) {
              // Reset pagination when drilling into subfolder
              ref.read(displayedItemsPageProvider(widget.analysisPath).notifier).state = 50;
              ref.read(analysisCurrentPathProvider(widget.analysisPath).notifier).state = widget.item.path;
            } else {
              final fileItem = FileItem(
                path: widget.item.path,
                name: widget.item.name,
                type: widget.item.type ?? FileItemType.other,
                modified: widget.item.modified,
                sizeBytes: widget.item.size,
              );
              ref.read(previewFileProvider.notifier).state = fileItem;
            }
          },
          child: Stack(
            children: [
              if (percentage > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            startColor.withOpacity(0.15),
                            endColor.withOpacity(0.15),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                color: isSelected
                    ? Colors.white.withOpacity(0.05)
                    : _isHovered
                        ? Colors.white.withOpacity(0.02)
                        : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.violet,
                    side: BorderSide(
                      color: _isHovered ? Colors.white54 : Colors.white24,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      if (val == true) {
                        ref.read(selectionProvider.notifier).select(widget.item.path);
                      } else {
                        ref.read(selectionProvider.notifier).deselect([widget.item.path]);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: config.colors.first.withOpacity(
                            _isHovered || isSelected ? 0.25 : 0.15
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isHovered ? [
                            BoxShadow(
                              color: config.colors.first.withOpacity(0.2),
                              blurRadius: 8,
                            )
                          ] : [],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          config.icon,
                          size: 18,
                          color: config.colors.first,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.item.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.violet : AppColors.textBody,
                            fontWeight: FontWeight.w500,
                          ),
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
                    widget.item.isDirectory ? 'Folder' : '${widget.item.type?.name[0].toUpperCase()}${widget.item.type?.name.substring(1)} File',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    StringUtils.formatBytes(widget.item.size),
                    style: const TextStyle(
                      color: AppColors.textBody,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    _formatDate(widget.item.modified),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeFilterDropdown extends ConsumerWidget {
  const _SizeFilterDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSize = ref.watch(sizeFilterProvider);
    final isActive = currentSize != null;
    final label = isActive ? '> $currentSize MB' : 'Size';

    final bgColor = isActive ? AppColors.violet.withOpacity(0.15) : Colors.white.withOpacity(0.05);
    final borderColor = isActive ? AppColors.violet.withOpacity(0.3) : Colors.white.withOpacity(0.1);
    final textColor = isActive ? AppColors.violet : AppColors.textBody;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceBase),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
      ),
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 14),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: () => ref.read(sizeFilterProvider.notifier).state = null,
          child: const Text('All Sizes', style: TextStyle(color: AppColors.textBody, fontSize: 13)),
        ),
        const PopupMenuDivider(),
        MenuItemButton(onPressed: () => ref.read(sizeFilterProvider.notifier).state = 10, child: const Text('> 10 MB', style: TextStyle(color: AppColors.textBody, fontSize: 13))),
        MenuItemButton(onPressed: () => ref.read(sizeFilterProvider.notifier).state = 50, child: const Text('> 50 MB', style: TextStyle(color: AppColors.textBody, fontSize: 13))),
        MenuItemButton(onPressed: () => ref.read(sizeFilterProvider.notifier).state = 100, child: const Text('> 100 MB', style: TextStyle(color: AppColors.textBody, fontSize: 13))),
        MenuItemButton(onPressed: () => ref.read(sizeFilterProvider.notifier).state = 500, child: const Text('> 500 MB', style: TextStyle(color: AppColors.textBody, fontSize: 13))),
        MenuItemButton(onPressed: () => ref.read(sizeFilterProvider.notifier).state = 1024, child: const Text('> 1 GB', style: TextStyle(color: AppColors.textBody, fontSize: 13))),
      ],
    );
  }
}

class _CustomMenuCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final VoidCallback onChanged;

  const _CustomMenuCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onChanged,
      closeOnActivate: false,
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? AppColors.violet : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value ? AppColors.violet : Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textBody, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TypeFilterDropdown extends ConsumerWidget {
  const _TypeFilterDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTypes = ref.watch(typeFilterProvider);
    final isActive = currentTypes.isNotEmpty;
    
    String label = 'Type';
    if (isActive) {
      if (currentTypes.length == 1) {
        label = '${currentTypes.first.name[0].toUpperCase()}${currentTypes.first.name.substring(1)}';
      } else {
        label = '${currentTypes.length} Types';
      }
    }

    final bgColor = isActive ? AppColors.violet.withOpacity(0.15) : Colors.white.withOpacity(0.05);
    final borderColor = isActive ? AppColors.violet.withOpacity(0.3) : Colors.white.withOpacity(0.1);
    final textColor = isActive ? AppColors.violet : AppColors.textBody;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceBase),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
      ),
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 14),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: isActive ? () {
            ref.read(typeFilterProvider.notifier).state = {};
          } : null,
          child: const Text('Clear All', style: TextStyle(color: AppColors.violet)),
        ),
        const PopupMenuDivider(),
        ...FileItemType.values.where((t) => t != FileItemType.folder).map((type) {
          return _CustomMenuCheckbox(
            value: currentTypes.contains(type),
            label: '${type.name[0].toUpperCase()}${type.name.substring(1)}',
            onChanged: () {
              final newSet = Set<FileItemType>.from(currentTypes);
              if (currentTypes.contains(type)) {
                newSet.remove(type);
              } else {
                newSet.add(type);
              }
              ref.read(typeFilterProvider.notifier).state = newSet;
            },
          );
        }),
      ],
    );
  }
}

class _ExtensionFilterDropdown extends ConsumerWidget {
  final String analysisPath;
  const _ExtensionFilterDropdown({required this.analysisPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableExtensionsProvider(analysisPath));
    final currentExts = ref.watch(extensionFilterProvider);
    final isActive = currentExts.isNotEmpty;
    
    if (available.isEmpty) return const SizedBox.shrink();

    String label = 'Extensions';
    if (isActive) {
      if (currentExts.length == 1) {
        label = currentExts.first;
      } else {
        label = '${currentExts.length} Exts';
      }
    }

    final bgColor = isActive ? AppColors.violet.withOpacity(0.15) : Colors.white.withOpacity(0.05);
    final borderColor = isActive ? AppColors.violet.withOpacity(0.3) : Colors.white.withOpacity(0.1);
    final textColor = isActive ? AppColors.violet : AppColors.textBody;

    final exts = available.toList()..sort();

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceBase),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
      ),
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 14),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: isActive ? () {
            ref.read(extensionFilterProvider.notifier).state = {};
          } : null,
          child: const Text('Clear All', style: TextStyle(color: AppColors.violet)),
        ),
        const PopupMenuDivider(),
        ...exts.map((ext) {
          return _CustomMenuCheckbox(
            value: currentExts.contains(ext),
            label: ext,
            onChanged: () {
              final newSet = Set<String>.from(currentExts);
              if (currentExts.contains(ext)) {
                newSet.remove(ext);
              } else {
                newSet.add(ext);
              }
              ref.read(extensionFilterProvider.notifier).state = newSet;
            },
          );
        }),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilterButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textBody, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textBody, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<FileItemType, double> percentages;
  final double strokeWidth;

  _DonutChartPainter({required this.percentages, this.strokeWidth = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // The image seems to have flat/butt caps for segments

    // Draw background
    paint.color = Colors.white.withOpacity(0.05);
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);

    double startAngle = -math.pi / 2;

    void drawSegment(FileItemType type, Color color) {
      final percentage = percentages[type] ?? 0.0;
      if (percentage <= 0) return;
      final sweepAngle = percentage * 2 * math.pi;
      paint.color = color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    drawSegment(FileItemType.image, const Color(0xFF2E7D32));
    drawSegment(FileItemType.video, const Color(0xFFD32F2F));
    drawSegment(FileItemType.audio, const Color(0xFF7B1FA2));
    drawSegment(FileItemType.document, const Color(0xFF1565C0));
    drawSegment(FileItemType.archive, const Color(0xFFFF6F00));
    
    // Calculate 'other' percentage
    double otherPercentage = 1.0 - (percentages[FileItemType.image] ?? 0) - (percentages[FileItemType.video] ?? 0) - (percentages[FileItemType.audio] ?? 0) - (percentages[FileItemType.document] ?? 0) - (percentages[FileItemType.archive] ?? 0);
    
    if (otherPercentage > 0.001) { // Floating point safety
      final sweepAngle = otherPercentage * 2 * math.pi;
      paint.color = const Color(0xFF546E7A); // Grey for other
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (strokeWidth != oldDelegate.strokeWidth) return true;
    if (percentages.length != oldDelegate.percentages.length) return true;
    for (final key in percentages.keys) {
      if (percentages[key] != oldDelegate.percentages[key]) return true;
    }
    return false;
  }
}

class CircularBubbleLoader extends StatefulWidget {
  final double size;
  const CircularBubbleLoader({super.key, this.size = 64.0});

  @override
  State<CircularBubbleLoader> createState() => _CircularBubbleLoaderState();
}

class _CircularBubbleLoaderState extends State<CircularBubbleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: Stack(
              children: List.generate(3, (index) {
                final angle = (index * 2 * math.pi) / 3;
                final bubbleSize = widget.size / 4.0;
                final radius = widget.size / 2.0 - bubbleSize / 2.0;
                final dx = radius * math.cos(angle) + widget.size / 2.0 - bubbleSize / 2.0;
                final dy = radius * math.sin(angle) + widget.size / 2.0 - bubbleSize / 2.0;

                return Positioned(
                  left: dx,
                  top: dy,
                  child: Container(
                    width: bubbleSize,
                    height: bubbleSize,
                    decoration: BoxDecoration(
                      color: AppColors.violet.withOpacity(1.0 - (index * 0.3)),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _AnalysisDeleteDialog extends StatefulWidget {
  final int filesCount;
  final int foldersCount;
  final String totalSize;

  const _AnalysisDeleteDialog({
    required this.filesCount,
    required this.foldersCount,
    required this.totalSize,
  });

  @override
  State<_AnalysisDeleteDialog> createState() => _AnalysisDeleteDialogState();
}

class _AnalysisDeleteDialogState extends State<_AnalysisDeleteDialog> {
  bool _isPermanent = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 50,
              spreadRadius: 10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _isPermanent ? AppColors.error.withOpacity(0.05) : AppColors.violet.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isPermanent ? AppColors.error.withOpacity(0.15) : AppColors.violet.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  _isPermanent ? Icons.delete_forever_rounded : Icons.delete_outline_rounded,
                  color: _isPermanent ? AppColors.error.withOpacity(0.9) : AppColors.violet.withOpacity(0.9),
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _isPermanent ? "Permanently Delete?" : "Move to Trash?",
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    label: "Folders",
                    value: widget.foldersCount.toString(),
                    color: Colors.white.withOpacity(0.7),
                  ),
                  _buildStatItem(
                    label: "Files",
                    value: widget.filesCount.toString(),
                    color: Colors.white.withOpacity(0.7),
                  ),
                  _buildStatItem(
                    label: "Total Space",
                    value: widget.totalSize,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isPermanent ? AppColors.error.withOpacity(0.04) : AppColors.violet.withOpacity(0.04),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _isPermanent ? AppColors.error.withOpacity(0.08) : AppColors.violet.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPermanent ? Icons.info_outline_rounded : Icons.delete_sweep_outlined,
                    color: _isPermanent ? AppColors.error.withOpacity(0.6) : AppColors.violet.withOpacity(0.6),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPermanent ? "This action cannot be undone" : "You can restore it from system Trash",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: _isPermanent ? AppColors.error.withOpacity(0.6) : AppColors.violet.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isPermanent = !_isPermanent;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _isPermanent ? AppColors.error : Colors.transparent,
                      border: Border.all(
                        color: _isPermanent ? AppColors.error : Colors.white38,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _isPermanent
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Permanently delete instead of moving to Trash",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: () {
                      Navigator.pop(context, _isPermanent);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPermanent ? AppColors.error : AppColors.violet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isPermanent ? "Yes, Delete" : "Yes, Trash",
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white24,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
