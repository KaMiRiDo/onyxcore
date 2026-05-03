import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/background_processes_button.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/top_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';

class GnomeTabBar extends ConsumerStatefulWidget {
  const GnomeTabBar({super.key});

  @override
  ConsumerState<GnomeTabBar> createState() => _GnomeTabBarState();
}

class _GnomeTabBarState extends ConsumerState<GnomeTabBar> {
  final ScrollController _scrollController = ScrollController();
  static const double _minTabWidth = 140.0;
  static const double _height = 56.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(tabManagerProvider);
    
    if (tabState.tabs.length <= 1) {
      return const SizedBox.shrink();
    }

    ref.listen(tabManagerProvider.select((s) => s.tabs.length), (prev, next) {
      if (next != null && (prev == null || next > prev)) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              double calculatedWidth = availableWidth / tabState.tabs.length;
              if (calculatedWidth < _minTabWidth) calculatedWidth = _minTabWidth;

              return SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: availableWidth),
                  child: Row(
                    children: tabState.tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tab = entry.value;
                      final isActive = index == tabState.activeTabIndex;
                      
                      return SizedBox(
                        width: calculatedWidth,
                        child: _TabWidget(
                          tab: tab,
                          isActive: isActive,
                          onTap: () => ref.read(tabManagerProvider.notifier).switchTab(index),
                          onClose: () => ref.read(tabManagerProvider.notifier).closeTab(tab.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
          },
        ),
    );
  }
}

class _TabWidget extends ConsumerStatefulWidget {
  final dynamic tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabWidget({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  ConsumerState<_TabWidget> createState() => _TabWidgetState();
}

class _TabWidgetState extends ConsumerState<_TabWidget> {
  bool _isHovered = false;
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }
  
  IconData _getTabIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('download')) return Icons.file_download_outlined;
    if (lowerTitle.contains('document') || lowerTitle.contains('work')) return Icons.work_outline_rounded;
    if (lowerTitle.contains('picture') || lowerTitle.contains('asset') || lowerTitle.contains('image')) return Icons.image_outlined;
    if (lowerTitle.contains('music')) return Icons.music_note_rounded;
    if (lowerTitle.contains('video')) return Icons.movie_outlined;
    if (lowerTitle.contains('desktop')) return Icons.desktop_windows_outlined;
    if (lowerTitle == 'vimal-babu' || lowerTitle == 'root') return Icons.account_box_outlined;
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    const activeBg = Color(0xFF212121);
    const inactiveBg = Color(0xFF141414);
    const borderColor = Color(0xFF2A2A2A);

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        _hoverTimer?.cancel();
        _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
          widget.onTap();
        });
        return true;
      },
      onLeave: (_) => _hoverTimer?.cancel(),
      onAcceptWithDetails: (details) async {
        _hoverTimer?.cancel();
        final targetPath = widget.tab.currentPath;
        if (details.data.every((path) => p.dirname(path) == targetPath)) return;

        final repo = ref.read(directoryRepositoryProvider);
        final taskId = ref.read(taskProvider.notifier).addTask(
          title: 'Moving Files',
          subtitle: '${details.data.length} items to ${widget.tab.title}',
          totalCount: details.data.length,
          sourcePaths: details.data,
          targetPath: targetPath,
        );

        try {
          await repo.moveItems(details.data, targetPath);
          ref.read(taskProvider.notifier).completeTask(taskId);
          ref.read(directoryItemsProvider.notifier).refresh();
          ref.read(selectionProvider.notifier).deselectAll();
        } catch (e) {
          ref.read(taskProvider.notifier).failTask(taskId, e.toString());
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isOver 
                    ? AppColors.violet.withOpacity(0.1) 
                    : (widget.isActive ? activeBg : inactiveBg),
                border: const Border(
                  right: BorderSide(color: borderColor, width: 1),
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        if (widget.isActive)
                          ShaderMask(
                            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                            child: Icon(
                              _getTabIcon(widget.tab.title),
                              size: 16,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            _getTabIcon(widget.tab.title),
                            size: 16,
                            color: Colors.white54,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: widget.isActive 
                            ? ShaderMask(
                                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                                child: Text(
                                  widget.tab.title,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : Text(
                                widget.tab.title,
                                style: GoogleFonts.manrope(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                        ),
                        if (widget.isActive || _isHovered)
                          _CloseButton(onTap: widget.onClose, isActive: widget.isActive),
                      ],
                    ),
                  ),
                  if (widget.isActive)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _CloseButton({required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: isActive 
        ? ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Colors.white,
            ),
          )
        : Icon(
            Icons.close_rounded,
            size: 14,
            color: Colors.white.withOpacity(0.3),
          ),
    );
  }
}
