import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';

/// Top bar with breadcrumbs, search, and settings — pixel-perfect replica of original _buildTopBar().
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentPath = ref.watch(currentPathProvider);
    final previewFile = ref.watch(previewFileProvider);
    final String homePath = Platform.environment['HOME'] ?? '/';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildBreadcrumbs(ref, currentPath, homePath, previewFile?.name),
            ),
          ),
          const SizedBox(width: 24),
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
                hintText: 'Search archive...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => SettingsDialog.show(context),
            icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
          ),

        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(WidgetRef ref, String currentPath, String homePath, String? previewFileName) {
    // Basic segments calculation
    List<String> parts = [];
    if (currentPath.startsWith('virtual:')) {
      final label = currentPath.replaceFirst('virtual:', '');
      parts.add(label.isNotEmpty ? '${label[0].toUpperCase()}${label.substring(1)}' : label);
    } else {
      final relPath = currentPath.replaceFirst(homePath, 'Home');
      parts = relPath.split('/').where((s) => s.isNotEmpty).toList();
    }

    // Add filename if in preview mode
    if (previewFileName != null) {
      parts.add(StringUtils.truncateMiddle(previewFileName, maxLength: 32));
    }

    return Row(
      children: parts.asMap().entries.map((entry) {
        final index = entry.key;
        final name = entry.value;
        final isLast = index == parts.length - 1;
        final isFileName = previewFileName != null && isLast;

        String targetPath = '';
        if (!currentPath.startsWith('virtual:') && !isFileName) {
          final targetRel = parts.sublist(0, index + 1).join('/');
          targetPath = targetRel.replaceFirst('Home', homePath);
        }

        return Row(
          children: [
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
              ),
            BreadcrumbSegment(
              name: name,
              isLast: isLast,
              isFileName: isFileName,
              targetPath: targetPath,
            ),
          ],
        );
      }).toList(),
    );
  }
}

class BreadcrumbSegment extends ConsumerStatefulWidget {
  const BreadcrumbSegment({
    required this.name,
    required this.isLast,
    required this.isFileName,
    required this.targetPath,
    super.key,
  });

  final String name;
  final bool isLast;
  final bool isFileName;
  final String targetPath;

  @override
  ConsumerState<BreadcrumbSegment> createState() => _BreadcrumbSegmentState();
}

class _BreadcrumbSegmentState extends ConsumerState<BreadcrumbSegment> {
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _navigate() {
    if (!widget.isFileName) {
      ref.read(previewFileProvider.notifier).state = null;
      
      if (widget.targetPath.isNotEmpty) {
        ref.read(selectionProvider.notifier).deselectAll();
        ref.read(navigationProvider.notifier).navigateTo(widget.targetPath);
        ref.read(currentPathProvider.notifier).state = widget.targetPath;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = InkWell(
      onTap: _navigate,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _buildGradientText(
          widget.name,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: (widget.isLast && !widget.isFileName) || widget.isFileName ? FontWeight.w800 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (widget.targetPath.isEmpty || widget.isFileName || widget.isLast) {
      return textWidget;
    }

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        // Can't drop into itself
        if (details.data.every((path) => p.dirname(path) == widget.targetPath)) return false;

        _hoverTimer?.cancel();
        _hoverTimer = Timer(const Duration(milliseconds: 700), () {
          _navigate();
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
          subtitle: '${details.data.length} items to ${widget.name}',
        );
        try {
          await repo.moveItems(details.data, widget.targetPath);
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
            color: isOver ? AppColors.violet.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: textWidget,
        );
      },
    );
  }

  Widget _buildGradientText(String text, {required TextStyle style}) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          AppTheme.primaryGradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
