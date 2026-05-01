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

class TopBar extends ConsumerStatefulWidget {
  const TopBar({super.key});

  @override
  ConsumerState<TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _breadcrumbController = ScrollController();
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (ref.read(isSearchActiveProvider)) {
        ref.read(searchQueryProvider.notifier).state = _searchController.text;
      }
    });
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && ref.read(isSearchActiveProvider)) {
        // Optional: close search on focus loss if desired
      }
    });
    _locationFocusNode.addListener(() {
      if (!_locationFocusNode.hasFocus && ref.read(isLocationEditingProvider)) {
        ref.read(isLocationEditingProvider.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _breadcrumbController.dispose();
    _locationController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch(bool active) {
    if (active) {
      ref.read(isLocationEditingProvider.notifier).state = false;
    }
    ref.read(isSearchActiveProvider.notifier).state = active;
  }

  @override
  Widget build(BuildContext context) {
    final String currentPath = ref.watch(currentPathProvider);
    final previewFile = ref.watch(previewFileProvider);
    final String homePath = Platform.environment['HOME'] ?? '/';
    final devices = ref.watch(deviceProvider).value ?? [];
    final isSearchActive = ref.watch(isSearchActiveProvider);
    final isLocationEditing = ref.watch(isLocationEditingProvider);
    final pathError = ref.watch(pathErrorProvider);

    // Auto-deactivate modes on directory change
    ref.listen(currentPathProvider, (previous, next) {
      if (previous != next) {
        if (ref.read(isSearchActiveProvider)) {
          _toggleSearch(false);
        }
        if (ref.read(isLocationEditingProvider)) {
          ref.read(isLocationEditingProvider.notifier).state = false;
        }
        
        // Auto-scroll to end
        if (_breadcrumbController.hasClients) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _breadcrumbController.animateTo(
              _breadcrumbController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        }
      }
    });

    // Handle location editing focus and text
    ref.listen(isLocationEditingProvider, (prev, next) {
      if (next) {
        _locationController.text = ref.read(currentPathProvider);
        _locationController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _locationController.text.length,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _locationFocusNode.requestFocus();
        });
      }
    });

    // Cleanup search state when deactivated & handle focus when activated
    ref.listen(isSearchActiveProvider, (previous, next) {
      if (next == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchController.clear();
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });

    return DragToMoveArea(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(
              children: [
                // Combined Breadcrumb/Search Container + Toggle
                Expanded(
                  flex: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSearchActive ? null : Colors.white.withOpacity(0.05),
                      gradient: isSearchActive 
                          ? LinearGradient(
                              colors: AppTheme.primaryGradient.colors.map((c) => c.withOpacity(0.15)).toList(),
                              begin: AppTheme.primaryGradient.begin,
                              end: AppTheme.primaryGradient.end,
                            ) 
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSearchActive 
                            ? AppColors.violet.withOpacity(0.5) 
                            : Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Breadcrumb Layer
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: (isSearchActive || isLocationEditing) ? 0.0 : 1.0,
                            child: IgnorePointer(
                              ignoring: isSearchActive || isLocationEditing,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        ref.read(isLocationEditingProvider.notifier).state = true;
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: SingleChildScrollView(
                                        controller: _breadcrumbController,
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.only(right: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(left: 14, right: 0),
                                              child: _buildGradientIcon(
                                                _getRootIconData(currentPath, homePath, devices),
                                              ),
                                            ),
                                            _buildBreadcrumbs(ref, currentPath, homePath, previewFile?.name, devices),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Location Editing Layer
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isLocationEditing ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !isLocationEditing,
                              child: TapRegion(
                                onTapOutside: (_) {
                                  if (ref.read(isLocationEditingProvider)) {
                                    ref.read(isLocationEditingProvider.notifier).state = false;
                                  }
                                },
                                child: TextField(
                                  controller: _locationController,
                                  focusNode: _locationFocusNode,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSubmitted: (value) {
                                    final dir = Directory(value);
                                    if (dir.existsSync()) {
                                      ref.read(selectionProvider.notifier).deselectAll();
                                      ref.read(navigationProvider.notifier).navigateTo(value);
                                      ref.read(currentPathProvider.notifier).state = value;
                                    } else if (value.isNotEmpty) {
                                      ref.read(pathErrorProvider.notifier).state = 'Invalid directory path';
                                      Future.delayed(const Duration(seconds: 2), () {
                                        ref.read(pathErrorProvider.notifier).state = null;
                                      });
                                    }
                                    ref.read(isLocationEditingProvider.notifier).state = false;
                                    // Request focus back to main node
                                    ref.read(mainFocusNodeProvider).requestFocus();
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      color: Colors.white38,
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 20,
                                      onPressed: () {
                                        ref.read(isLocationEditingProvider.notifier).state = false;
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Search Layer
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isSearchActive ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !isSearchActive,
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                onChanged: (value) {
                                  ref.read(searchQueryProvider.notifier).state = value;
                                },
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _searchFocusNode.requestFocus(),
                                decoration: InputDecoration(
                                  hintText: 'Search in ${p.basename(currentPath)}...',
                                  hintStyle: GoogleFonts.manrope(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: _buildGradientIcon(
                                      Icons.search,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 3),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    gradient: isSearchActive 
                        ? LinearGradient(
                            colors: AppTheme.primaryGradient.colors.map((c) => c.withOpacity(0.15)).toList(),
                            begin: AppTheme.primaryGradient.begin,
                            end: AppTheme.primaryGradient.end,
                          ) 
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSearchActive ? AppColors.violet.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Center(
                    child: _buildActionIcon(
                      icon: Icons.manage_search,
                      isActive: isSearchActive,
                      onPressed: () => _toggleSearch(!isSearchActive),
                    ),
                  ),
                ),
    
                const Spacer(flex: 4),
                
                const SizedBox(width: 16),
                
                _buildActionIcon(
                  icon: Icons.settings,
                  onPressed: () => SettingsDialog.show(context),
                ),
                const SizedBox(width: 8),
                const TaskProgressButton(),
                const SizedBox(width: 16),
                const WindowButtons(),
              ],
            ),
          ),
          if (pathError != null)
            Positioned(
              left: 32,
              bottom: -10, // Adjusted for padding
              child: AnimatedOpacity(
                opacity: pathError != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pathError,
                        style: GoogleFonts.manrope(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getRootIconData(String currentPath, String homePath, List<Device> devices) {
    if (currentPath.startsWith('virtual:')) {
      final label = currentPath.replaceFirst('virtual:', '').toLowerCase();
      if (label.contains('trash')) return Icons.delete_outline;
      if (label.contains('recent')) return Icons.access_time;
      if (label.contains('starred')) return Icons.star_outline_rounded;
      return Icons.folder_special_rounded;
    }
    
    if (currentPath.startsWith(homePath)) {
      return Icons.home;
    }
    
    for (final device in devices) {
      if (currentPath.startsWith(device.path)) {
        return Icons.storage_outlined;
      }
    }
    
    return Icons.storage_outlined; // File System
  }


  Widget _buildActionIcon({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? AppColors.violet.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.violet : Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(WidgetRef ref, String currentPath, String homePath, String? previewFileName, List<Device> devices) {
    List<MapEntry<String, String>> parts = [];

    if (currentPath.startsWith('virtual:')) {
      final label = currentPath.replaceFirst('virtual:', '');
      final name = label.isNotEmpty ? '${label[0].toUpperCase()}${label.substring(1)}' : label;
      parts.add(MapEntry(name, currentPath));
    } else if (currentPath.startsWith(homePath)) {
      final relPath = currentPath.replaceFirst(homePath, 'Home');
      final subParts = relPath.split('/').where((s) => s.isNotEmpty).toList();
      
      String accumulated = homePath;
      parts.add(MapEntry('Home', homePath));
      
      for (final sub in subParts) {
        if (sub == 'Home') continue;
        final subIndex = currentPath.indexOf('/$sub', accumulated.length - 1);
        if (subIndex != -1) {
          accumulated = currentPath.substring(0, subIndex + sub.length + 1);
          if (accumulated.endsWith('/')) accumulated = accumulated.substring(0, accumulated.length - 1);
          parts.add(MapEntry(StringUtils.truncateMiddle(sub, maxLength: 16), accumulated));
        } else {
          accumulated = p.join(accumulated, sub);
          parts.add(MapEntry(StringUtils.truncateMiddle(sub, maxLength: 16), accumulated));
        }
      }
    } else {
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
          parts.add(MapEntry(StringUtils.truncateMiddle(pPart, maxLength: 16), accumulatedPath));
        }
      } else {
        final splitParts = currentPath.split('/').where((s) => s.isNotEmpty).toList();
        String accumulatedPath = '/';
        parts.add(const MapEntry('File System', '/'));
        for (final pPart in splitParts) {
          accumulatedPath = p.join(accumulatedPath, pPart);
          parts.add(MapEntry(StringUtils.truncateMiddle(pPart, maxLength: 16), accumulatedPath));
        }
      }
    }

    if (previewFileName != null) {
      parts.add(MapEntry(StringUtils.truncateMiddle(previewFileName, maxLength: 32), ''));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts.asMap().entries.map((entry) {
        final index = entry.key;
        final name = entry.value.key;
        final targetPath = entry.value.value;
        final isLast = index == parts.length - 1;
        final isFileName = previewFileName != null && isLast;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildGradientText('/', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    if (widget.targetPath.isEmpty || widget.isFileName) {
      return textWidget;
    }

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
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

Widget _buildGradientText(String text, {required TextStyle style}) {
  return ShaderMask(
    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

Widget _buildGradientIcon(IconData icon, {double size = 18}) {
  return ShaderMask(
    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
    child: Icon(
      icon,
      size: size,
      color: Colors.white,
    ),
  );
}
