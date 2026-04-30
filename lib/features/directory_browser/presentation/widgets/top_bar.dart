import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/core/widgets/task_progress_overlay.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/device.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';

/// Top bar with breadcrumbs, search, and settings — pixel-perfect replica of original _buildTopBar().
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentPath = ref.watch(currentPathProvider);
    final previewFile = ref.watch(previewFileProvider);
    final String homePath = Platform.environment['HOME'] ?? '/';
    final devices = ref.watch(deviceProvider).value ?? [];

    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildBreadcrumbs(ref, currentPath, homePath, previewFile?.name, devices),
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
            const SizedBox(width: 12),
            const TaskProgressButton(),
            const SizedBox(width: 16),
            const WindowButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(WidgetRef ref, String currentPath, String homePath, String? previewFileName, List<Device> devices) {
    // Basic segments calculation
    List<MapEntry<String, String>> parts = []; // List of name to path mappings

    if (currentPath.startsWith('virtual:')) {
      final label = currentPath.replaceFirst('virtual:', '');
      final name = label.isNotEmpty ? '${label[0].toUpperCase()}${label.substring(1)}' : label;
      parts.add(MapEntry(name, currentPath));
    } else if (currentPath.startsWith(homePath)) {
      // Prioritize User Home labeling
      final relPath = currentPath.replaceFirst(homePath, 'Home');
      final subParts = relPath.split('/').where((s) => s.isNotEmpty).toList();
      
      String accumulated = homePath;
      parts.add(MapEntry('Home', homePath));
      
      // The first part is 'Home', so we skip it in subParts if it's there (it shouldn't be due to replaceFirst)
      for (final sub in subParts) {
        if (sub == 'Home') continue;
        // Reconstruct the real path for each segment
        // We need to find where this segment is in the real currentPath
        final subIndex = currentPath.indexOf('/$sub', accumulated.length - 1);
        if (subIndex != -1) {
          accumulated = currentPath.substring(0, subIndex + sub.length + 1);
          if (accumulated.endsWith('/')) accumulated = accumulated.substring(0, accumulated.length - 1);
          parts.add(MapEntry(sub, accumulated));
        } else {
          // Fallback if index matching fails
          accumulated = p.join(accumulated, sub);
          parts.add(MapEntry(sub, accumulated));
        }
      }
    } else {
      // Find the most specific device that matches the path
      Device? matchingDevice;
      for (final device in devices) {
        if (currentPath.startsWith(device.path)) {
          if (matchingDevice == null || device.path.length > matchingDevice.path.length) {
            matchingDevice = device;
          }
        }
      }

      if (matchingDevice != null) {
        parts.add(MapEntry(matchingDevice.name, matchingDevice.path));
        final subPath = currentPath.substring(matchingDevice.path.length);
        final subParts = subPath.split('/').where((s) => s.isNotEmpty).toList();
        
        String accumulatedPath = matchingDevice.path;
        for (final pPart in subParts) {
          accumulatedPath = p.join(accumulatedPath, pPart);
          parts.add(MapEntry(pPart, accumulatedPath));
        }
      } else {
        // Fallback for unexpected paths
        final splitParts = currentPath.split('/').where((s) => s.isNotEmpty).toList();
        String accumulatedPath = '/';
        parts.add(const MapEntry('File System', '/'));
        for (final pPart in splitParts) {
          accumulatedPath = p.join(accumulatedPath, pPart);
          parts.add(MapEntry(pPart, accumulatedPath));
        }
      }
    }

    // Add filename if in preview mode
    if (previewFileName != null) {
      parts.add(MapEntry(StringUtils.truncateMiddle(previewFileName, maxLength: 32), ''));
    }

    return Row(
      children: parts.asMap().entries.map((entry) {
        final index = entry.key;
        final name = entry.value.key;
        final targetPath = entry.value.value;
        final isLast = index == parts.length - 1;
        final isFileName = previewFileName != null && isLast;

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

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildButton(
          icon: Icons.remove,
          onPressed: () => windowManager.minimize(),
        ),
        const SizedBox(width: 8),
        _buildButton(
          icon: Icons.crop_square,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        const SizedBox(width: 8),
        _buildButton(
          icon: Icons.close,
          onPressed: () => windowManager.close(),
          isClose: true,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isClose = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 14,
            color: isClose ? Colors.white70 : Colors.white60,
          ),
        ),
      ),
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

    if (widget.targetPath.isEmpty || widget.isFileName) {
      return textWidget;
    }

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        // We always allow hover navigation to any folder in breadcrumbs
        // even if it's the source folder (dirname == targetPath).
        // This allows users to navigate back to where they started.

        _hoverTimer?.cancel();
        _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
          _navigate();
        });
        return true;
      },
      onLeave: (_) {
        _hoverTimer?.cancel();
      },
      onAcceptWithDetails: (details) async {
        _hoverTimer?.cancel();

        // Prevent dropping into the same directory (no-op)
        if (details.data.every((path) => p.dirname(path) == widget.targetPath)) return;
        
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
