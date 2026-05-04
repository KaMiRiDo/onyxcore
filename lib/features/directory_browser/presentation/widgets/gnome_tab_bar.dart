import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

class GnomeTabBar extends ConsumerStatefulWidget {
  const GnomeTabBar({super.key});

  @override
  ConsumerState<GnomeTabBar> createState() => _GnomeTabBarState();
}

class _GnomeTabBarState extends ConsumerState<GnomeTabBar> {
  final ScrollController _scrollController = ScrollController();
  static const double _minTabWidth = 140;
  static const double _height = 56;

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
    
    // Auto-scroll to end when tabs are added
    ref.listen(tabManagerProvider, (previous, next) {
      if (next.tabs.length > (previous?.tabs.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
  final TabState tab;
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
    
    final currentRef = ref;

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

        final repo = currentRef.read(directoryRepositoryProvider);
        final taskId = currentRef.read(taskProvider.notifier).addTask(
          title: 'Moving Files',
          subtitle: '${details.data.length} items to ${widget.tab.title}',
          totalCount: details.data.length,
          sourcePaths: details.data,
          targetPath: targetPath,
        );

        try {
          await repo.moveItems(details.data, targetPath);
          currentRef.read(taskProvider.notifier).completeTask(taskId);
          currentRef.read(directoryItemsProvider.notifier).refresh();
          currentRef.read(selectionProvider.notifier).deselectAll();
        } catch (e) {
          currentRef.read(taskProvider.notifier).failTask(taskId, e.toString());
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
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 3,
                        decoration: const BoxDecoration(
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

  const _CloseButton({required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.close,
            size: 14,
            color: isActive ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}
