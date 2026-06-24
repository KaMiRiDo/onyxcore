import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

/// Individual sidebar navigation item — Enhanced with Drag & Drop capabilities.
class SidebarItem extends ConsumerStatefulWidget {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.isActive,
    required this.onTap,
    this.progress,
    this.storageText,
    this.onEject,
    super.key,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onEject;
  final double? progress;
  final String? storageText;

  @override
  ConsumerState<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends ConsumerState<SidebarItem> {
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _navigate() {
    ref.read(previewFileProvider.notifier).state = null;
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).navigateTo(widget.path);
    ref.read(currentPathProvider.notifier).state = widget.path;
  }

  @override
  Widget build(BuildContext context) {
    Widget labelWidget = widget.isActive
        ? ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          )
        : Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          );

    Widget content = Row(
      children: [
        widget.isActive
            ? ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: Icon(widget.icon, size: 20, color: Colors.white),
              )
            : Icon(widget.icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              labelWidget,
              if (widget.progress != null) ...[
                const SizedBox(height: 4),
                if (widget.storageText != null) ...[
                  Text(
                    widget.storageText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: AppColors.textMuted.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Container(
                  height: 3,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.progress!.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.onEject != null)
          IconButton(
            icon: const Icon(
              Icons.eject_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: widget.onEject,
            hoverColor: Colors.white10,
            splashRadius: 20,
          ),
      ],
    );

    final bool isVirtual = widget.path.startsWith('virtual:');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) {
          if (isVirtual || widget.path.isEmpty) return false;
          // Prevent dropping into source folder (but allow hover navigation)
          if (details.data.every((path) => p.dirname(path) == widget.path)) {
            // Start hover timer anyway so user can navigate to the source
            _hoverTimer?.cancel();
            _hoverTimer = Timer(const Duration(milliseconds: 1000), _navigate);
            return true;
          }

          _hoverTimer?.cancel();
          _hoverTimer = Timer(const Duration(milliseconds: 1000), _navigate);
          return true;
        },
        onLeave: (_) => _hoverTimer?.cancel(),
        onAcceptWithDetails: (details) async {
          _hoverTimer?.cancel();
          if (isVirtual || widget.path.isEmpty) return;

          // Prevent dropping into same directory
          if (details.data.every((path) => p.dirname(path) == widget.path))
            return;

          final repo = ref.read(directoryRepositoryProvider);
          final taskId = ref
              .read(taskProvider.notifier)
              .addTask(
                title: 'Moving Files',
                subtitle: '${details.data.length} items to ${widget.label}',
                totalCount: details.data.length,
                sourcePaths: details.data,
                targetPath: widget.path,
              );

          try {
            await repo.moveItems(details.data, widget.path);
            ref.read(taskProvider.notifier).completeTask(taskId);
            ref.read(directoryItemsProvider.notifier).refresh();
            ref.read(selectionProvider.notifier).deselectAll();
          } catch (e) {
            ref.read(taskProvider.notifier).failTask(taskId, e.toString());
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isOver = candidateData.isNotEmpty;
          return InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOver
                    ? AppColors.violet.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: content,
            ),
          );
        },
      ),
    );
  }
}
