import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_selection_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_runner_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';
import 'package:path/path.dart' as p;

/// Complete interactive comparison results view.
///
/// Features summary header statistics, virtualized lazy group rendering,
/// expand/collapse all controls, item selection across source and destination,
/// batch file operations (copy, move, trash, permanent delete), and an informative empty state.
class CompareResultsView extends StatelessWidget {
  const CompareResultsView({
    required this.result,
    this.sourceFolder,
    this.destinationFolder,
    this.onNewComparison,
    this.onOpenFile,
    this.onLocateFile,
    super.key,
  });

  final ComparisonResult result;
  final String? sourceFolder;
  final String? destinationFolder;
  final VoidCallback? onNewComparison;
  final void Function(String filePath)? onOpenFile;
  final void Function(String filePath)? onLocateFile;

  @override
  Widget build(BuildContext context) {
    if (result.isEmpty) {
      return _buildEmptyState(result);
    }

    final hasScope =
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
        null;
    if (!hasScope) {
      return ProviderScope(
        child: _CompareResultsContent(
          result: result,
          sourceFolder: sourceFolder,
          destinationFolder: destinationFolder,
          onNewComparison: onNewComparison,
          onOpenFile: onOpenFile,
          onLocateFile: onLocateFile,
        ),
      );
    }

    return _CompareResultsContent(
      result: result,
      sourceFolder: sourceFolder,
      destinationFolder: destinationFolder,
      onNewComparison: onNewComparison,
      onOpenFile: onOpenFile,
      onLocateFile: onLocateFile,
    );
  }

  static Widget _buildEmptyState(ComparisonResult result) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.greenAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Duplicates Found',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Analyzed ${result.totalSourceCandidates} source and '
                '${result.totalDestinationCandidates} destination candidates. '
                'No matching duplicates detected.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareResultsContent extends ConsumerStatefulWidget {
  const _CompareResultsContent({
    required this.result,
    this.sourceFolder,
    this.destinationFolder,
    this.onNewComparison,
    this.onOpenFile,
    this.onLocateFile,
  });

  final ComparisonResult result;
  final String? sourceFolder;
  final String? destinationFolder;
  final VoidCallback? onNewComparison;
  final void Function(String filePath)? onOpenFile;
  final void Function(String filePath)? onLocateFile;

  @override
  ConsumerState<_CompareResultsContent> createState() =>
      _CompareResultsContentState();
}

class _CompareResultsContentState
    extends ConsumerState<_CompareResultsContent> {
  final Set<String> _collapsedSourcePaths = {};
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;

    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (isCtrl) {
      if (event.logicalKey == LogicalKeyboardKey.bracketRight ||
          event.physicalKey == PhysicalKeyboardKey.bracketRight) {
        _collapseAll();
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.bracketLeft ||
          event.physicalKey == PhysicalKeyboardKey.bracketLeft) {
        _expandAll();
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyA ||
          event.physicalKey == PhysicalKeyboardKey.keyA) {
        _selectAll();
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyC ||
          event.physicalKey == PhysicalKeyboardKey.keyC) {
        _handleCopy();
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyX ||
          event.physicalKey == PhysicalKeyboardKey.keyX) {
        _handleCut();
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.physicalKey == PhysicalKeyboardKey.escape) {
      _deselectAll();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.physicalKey == PhysicalKeyboardKey.delete) {
      _handleDelete(permanent: isShift);
      return true;
    }

    return false;
  }

  String get _effectiveSourceFolder {
    if (widget.sourceFolder != null && widget.sourceFolder!.isNotEmpty) {
      return widget.sourceFolder!;
    }
    if (widget.result.matches.isNotEmpty) {
      return p.dirname(widget.result.matches.first.sourcePath);
    }
    return '';
  }

  String get _effectiveDestinationFolder {
    if (widget.destinationFolder != null &&
        widget.destinationFolder!.isNotEmpty) {
      return widget.destinationFolder!;
    }
    if (widget.result.matches.isNotEmpty &&
        widget.result.matches.first.destinationMatches.isNotEmpty) {
      return p.dirname(
        widget.result.matches.first.destinationMatches.first.destinationPath,
      );
    }
    return '';
  }

  bool get _isAllCollapsed =>
      widget.result.matches.isNotEmpty &&
      widget.result.matches.every(
        (m) => _collapsedSourcePaths.contains(m.sourcePath),
      );

  void _collapseAll() {
    setState(() {
      _collapsedSourcePaths.addAll(
        widget.result.matches.map((m) => m.sourcePath),
      );
    });
  }

  void _expandAll() {
    setState(_collapsedSourcePaths.clear);
  }

  void _toggleAll() {
    setState(() {
      if (_isAllCollapsed) {
        _collapsedSourcePaths.clear();
      } else {
        _collapsedSourcePaths.addAll(
          widget.result.matches.map((m) => m.sourcePath),
        );
      }
    });
  }

  void _toggleGroup(String sourcePath) {
    setState(() {
      if (_collapsedSourcePaths.contains(sourcePath)) {
        _collapsedSourcePaths.remove(sourcePath);
      } else {
        _collapsedSourcePaths.add(sourcePath);
      }
    });
  }

  List<String> get _allSourcePaths =>
      widget.result.matches.map((m) => m.sourcePath).toList();

  List<String> get _allDestinationPaths => widget.result.matches
      .expand((m) => m.destinationMatches.map((d) => d.destinationPath))
      .toList();

  void _toggleAllSources() {
    ref.read(compareSelectionProvider.notifier).toggleGroup(_allSourcePaths);
  }

  void _toggleAllDestinations() {
    ref
        .read(compareSelectionProvider.notifier)
        .toggleGroup(_allDestinationPaths);
  }

  void _selectAll() {
    final allPaths = <String>{};
    for (final m in widget.result.matches) {
      allPaths.add(m.sourcePath);
      for (final d in m.destinationMatches) {
        allPaths.add(d.destinationPath);
      }
    }
    ref.read(compareSelectionProvider.notifier).selectAll(allPaths);
  }

  void _deselectAll() {
    ref.read(compareSelectionProvider.notifier).deselectAll();
  }

  void _showStyledSnackBar({
    required String message,
    IconData? icon,
    Color? iconColor,
    Color? borderColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color:
                      (iconColor ?? AppColors.violet).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.violet,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF262632),
        behavior: SnackBarBehavior.floating,
        elevation: 14,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: borderColor ?? AppColors.violet,
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        duration: duration,
      ),
    );
  }

  void _handleCopy() {
    final selected = ref.read(compareSelectionProvider);
    if (selected.isEmpty) return;

    ref.read(clipboardProvider.notifier).copy(selected.toList());
    if (mounted) {
      _showStyledSnackBar(
        message:
            '${selected.length} ${selected.length == 1 ? 'item' : 'items'} copied. Paste inside any folder in Directory Browser.',
        icon: Icons.content_copy_rounded,
        iconColor: AppColors.violet,
      );
    }
  }

  void _handleCut() {
    final selected = ref.read(compareSelectionProvider);
    if (selected.isEmpty) return;

    ref.read(clipboardProvider.notifier).cut(selected.toList());
    if (mounted) {
      _showStyledSnackBar(
        message:
            '${selected.length} ${selected.length == 1 ? 'item' : 'items'} cut for move. Paste inside any folder in Directory Browser.',
        icon: Icons.content_cut_rounded,
        iconColor: AppColors.violet,
      );
    }
  }

  Future<void> _handleDelete({required bool permanent}) async {
    final selected = ref.read(compareSelectionProvider);
    if (selected.isEmpty) return;

    final paths = selected.toList();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => ViewerDeleteDialog(
        fileName: paths.length == 1
            ? p.basename(paths.first)
            : '${paths.length} items',
        permanent: permanent,
      ),
    );

    if (shouldDelete != true) return;

    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: permanent
              ? 'Deleting ${paths.length} items permanently'
              : 'Moving ${paths.length} items to Trash',
          subtitle: permanent ? 'Permanent deletion' : 'Trash',
          sourcePaths: paths,
          isLight: true,
        );

    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (permanent) {
        await repo.deleteItems(
          paths,
          permanent: true,
          taskId: taskId,
          onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
          onProgress: (p, t) {
            ref.read(taskProvider.notifier).updateProgress(taskId, p / t);
            ref.read(taskProvider.notifier).updateItemCounts(taskId, p, t);
          },
        );
      } else {
        try {
          await repo.trashItems(
            paths,
            taskId: taskId,
            onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
            onProgress: (p, t) {
              ref.read(taskProvider.notifier).updateProgress(taskId, p / t);
              ref.read(taskProvider.notifier).updateItemCounts(taskId, p, t);
            },
          );
        } on TrashFailedException {
          ref
              .read(taskProvider.notifier)
              .failTask(taskId, 'Move to Trash failed');
          if (!mounted) return;
          final confirmPermanent = await showDialog<bool>(
            context: context,
            builder: (ctx) => ViewerDeleteDialog(
              fileName: paths.length == 1
                  ? p.basename(paths.first)
                  : '${paths.length} items',
              permanent: true,
            ),
          );
          if (confirmPermanent != true) return;

          final permTaskId = ref
              .read(taskProvider.notifier)
              .addTask(
                title: 'Deleting ${paths.length} items',
                subtitle: 'Permanent deletion',
                sourcePaths: paths,
                isLight: true,
              );
          await repo.deleteItems(
            paths,
            permanent: true,
            taskId: permTaskId,
            onLog: (msg) =>
                ref.read(taskProvider.notifier).addLog(permTaskId, msg),
            onProgress: (p, t) {
              ref.read(taskProvider.notifier).updateProgress(permTaskId, p / t);
              ref
                  .read(taskProvider.notifier)
                  .updateItemCounts(permTaskId, p, t);
            },
          );
          ref.read(taskProvider.notifier).completeTask(permTaskId);
        }
      }

      ref.read(comparisonRunnerProvider.notifier).removePaths(selected);
      ref.read(compareSelectionProvider.notifier).removePaths(selected);
      ref.read(taskProvider.notifier).completeTask(taskId);

      if (mounted) {
        _showStyledSnackBar(
          message:
              '${paths.length} ${paths.length == 1 ? 'item' : 'items'} ${permanent ? 'permanently deleted' : 'moved to trash'}.',
          icon: permanent
              ? Icons.delete_forever_rounded
              : Icons.delete_outline_rounded,
          iconColor: permanent ? Colors.redAccent : AppColors.violet,
          borderColor: permanent
              ? Colors.redAccent.withValues(alpha: 0.4)
              : null,
        );
      }
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
      if (mounted) {
        _showStyledSnackBar(
          message: 'Error deleting: $e',
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          borderColor: AppColors.error.withValues(alpha: 0.5),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalGroups = widget.result.matches.length;
    final totalDests = widget.result.matches.fold<int>(
      0,
      (sum, m) => sum + m.matchCount,
    );
    final selectedPaths = ref.watch(compareSelectionProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.bracketRight, control: true):
            _collapseAll,
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            _collapseAll,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true):
            _expandAll,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            _expandAll,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _selectAll,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): _selectAll,
        const SingleActivator(LogicalKeyboardKey.escape): _deselectAll,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _handleCopy,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _handleCopy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true):
            _handleCut,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): _handleCut,
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            _handleDelete(permanent: false),
        const SingleActivator(LogicalKeyboardKey.delete, shift: true): () =>
            _handleDelete(permanent: true),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Column(
          children: [
            // Top Summary Bar: Horizontal Banner & Separate Collapse Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF161618),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  // Horizontal Stats Banner
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Duplicate groups stat
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.violet.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.folder_copy_rounded,
                                  color: AppColors.violet,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$totalGroups Duplicate ${totalGroups == 1 ? 'Group' : 'Groups'} Found',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(
                            height: 20,
                            width: 1,
                            color: Colors.white12,
                          ),
                          const SizedBox(width: 16),
                          // Total matches stat
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.compare_arrows_rounded,
                                  color: Colors.tealAccent,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$totalDests Total ${totalDests == 1 ? 'Match' : 'Matches'}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(
                            height: 20,
                            width: 1,
                            color: Colors.white12,
                          ),
                          const SizedBox(width: 16),
                          // Evaluated candidates stat
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                color: Colors.white38,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.result.totalSourceCandidates} source / '
                                '${widget.result.totalDestinationCandidates} destination candidates evaluated'
                                '${widget.result.failures.isNotEmpty ? ' (${widget.result.failures.length} errors)' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Separate Collapse/Expand All Button
                  OutlinedButton.icon(
                    onPressed: _toggleAll,
                    icon: Icon(
                      _isAllCollapsed
                          ? Icons.unfold_more_rounded
                          : Icons.unfold_less_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isAllCollapsed ? 'Expand All' : 'Collapse All',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Action Toolbar (Always visible, clean, buttons disabled when empty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF19191D),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selectedPaths.isNotEmpty
                            ? AppColors.violet
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedPaths.length} selected',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selectedPaths.isNotEmpty
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: selectedPaths.isNotEmpty ? _deselectAll : null,
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 16,
                        color: selectedPaths.isNotEmpty
                            ? Colors.white70
                            : Colors.white24,
                      ),
                      label: Text(
                        'Clear',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: selectedPaths.isNotEmpty
                              ? Colors.white70
                              : Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: selectedPaths.isNotEmpty ? _handleCopy : null,
                      icon: Icon(
                        Icons.content_copy_rounded,
                        size: 15,
                        color: selectedPaths.isNotEmpty
                            ? Colors.white
                            : Colors.white24,
                      ),
                      label: Text(
                        'Copy',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedPaths.isNotEmpty
                              ? Colors.white
                              : Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: selectedPaths.isNotEmpty ? _handleCut : null,
                      icon: Icon(
                        Icons.content_cut_rounded,
                        size: 15,
                        color: selectedPaths.isNotEmpty
                            ? Colors.white
                            : Colors.white24,
                      ),
                      label: Text(
                        'Move',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedPaths.isNotEmpty
                              ? Colors.white
                              : Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: selectedPaths.isNotEmpty
                          ? () => _handleDelete(permanent: false)
                          : null,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: selectedPaths.isNotEmpty
                            ? Colors.white
                            : Colors.white24,
                      ),
                      label: Text(
                        'Trash',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedPaths.isNotEmpty
                              ? Colors.white
                              : Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: selectedPaths.isNotEmpty
                          ? () => _handleDelete(permanent: true)
                          : null,
                      icon: Icon(
                        Icons.delete_forever_rounded,
                        size: 15,
                        color: selectedPaths.isNotEmpty
                            ? Colors.redAccent
                            : Colors.white24,
                      ),
                      label: Text(
                        'Delete Permanently',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedPaths.isNotEmpty
                              ? Colors.redAccent
                              : Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Section Headers for Source & Destination
            if (_effectiveSourceFolder.isNotEmpty ||
                _effectiveDestinationFolder.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF161616),
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;
                    final isAllSourcesSelected = ref
                        .watch(compareSelectionProvider.notifier)
                        .isGroupSelected(_allSourcePaths);
                    final isAllDestinationsSelected = ref
                        .watch(compareSelectionProvider.notifier)
                        .isGroupSelected(_allDestinationPaths);

                    final sourceHeader = _buildSectionHeader(
                      label: 'SOURCE FOLDER',
                      path: _effectiveSourceFolder,
                      accentColor: AppColors.violet,
                      icon: Icons.folder_rounded,
                      selectAllValue: isAllSourcesSelected,
                      onToggleSelectAll: _toggleAllSources,
                    );
                    final destHeader = _buildSectionHeader(
                      label: 'DESTINATION FOLDER',
                      path: _effectiveDestinationFolder,
                      accentColor: Colors.tealAccent,
                      icon: Icons.folder_copy_rounded,
                      selectAllValue: isAllDestinationsSelected,
                      onToggleSelectAll: _toggleAllDestinations,
                    );

                    if (isWide) {
                      return Flex(
                        direction: Axis.horizontal,
                        children: [
                          Expanded(child: sourceHeader),
                          const SizedBox(width: 52),
                          Expanded(child: destHeader),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sourceHeader,
                        const SizedBox(height: 6),
                        destHeader,
                      ],
                    );
                  },
                ),
              ),
            // Virtualized Results List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.result.matches.length,
                itemBuilder: (context, index) {
                  final match = widget.result.matches[index];
                  final isExpanded = !_collapsedSourcePaths.contains(
                    match.sourcePath,
                  );
                  final destPaths = match.destinationMatches
                      .map((d) => d.destinationPath)
                      .toList();
                  final isDestGroupSelected = ref
                      .watch(compareSelectionProvider.notifier)
                      .isGroupSelected(destPaths);

                  return DuplicateGroupCard(
                    key: ValueKey(match.sourcePath),
                    match: match,
                    isExpanded: isExpanded,
                    isSourceGroupSelected:
                        selectedPaths.contains(match.sourcePath),
                    onToggleSelectSourceGroup: () {
                      ref
                          .read(compareSelectionProvider.notifier)
                          .toggle(match.sourcePath);
                    },
                    isDestinationGroupSelected: isDestGroupSelected,
                    onToggleSelectDestinationGroup: () {
                      ref
                          .read(compareSelectionProvider.notifier)
                          .toggleGroup(destPaths);
                    },
                    selectedPaths: selectedPaths,
                    onToggleSelectPath: (path) {
                      ref.read(compareSelectionProvider.notifier).toggle(path);
                    },
                    onToggleExpanded: () => _toggleGroup(match.sourcePath),
                    onOpenFile: widget.onOpenFile,
                    onLocateFile: widget.onLocateFile,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required String path,
    required Color accentColor,
    required IconData icon,
    bool? selectAllValue,
    VoidCallback? onToggleSelectAll,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (onToggleSelectAll != null) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: selectAllValue,
                tristate: true,
                activeColor: accentColor,
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.white54, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => onToggleSelectAll(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: accentColor, size: 15),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
