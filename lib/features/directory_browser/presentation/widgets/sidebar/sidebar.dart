import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/devices_section.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/storage_indicator.dart';

/// Main sidebar widget — pixel-perfect replica of original _buildSidebar().
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentPath = ref.watch(currentPathProvider);
    // Always use the real system home — never derive from currentPath
    final String home = Platform.environment['HOME'] ?? '/';

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Logo — icon + "ONYXCORE" all caps, gradient
          DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App icon — fixed 28×28, never stretches
                    SvgPicture.asset(
                      'assets/app_icon/app_icon.svg',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    // Gradient brand text
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppTheme.primaryGradient.createShader(bounds),
                      child: Text(
                        'ONYXCORE',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Navigation Items
          const SizedBox(height: 24),


          // Scrollable Navigation Area
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SidebarItem(
                    icon: Icons.home,
                    label: 'Home',
                    path: home,
                    isActive: currentPath == home,
                    onTap: () => _navigate(ref, home),
                  ),
                  SidebarItem(
                    icon: Icons.desktop_windows_outlined,
                    label: 'Desktop',
                    path: '$home/Desktop',
                    isActive: currentPath == '$home/Desktop',
                    onTap: () => _navigate(ref, '$home/Desktop'),
                  ),
                  SidebarItem(
                    icon: Icons.description_outlined,
                    label: 'Documents',
                    path: '$home/Documents',
                    isActive: currentPath == '$home/Documents',
                    onTap: () => _navigate(ref, '$home/Documents'),
                  ),
                  SidebarItem(
                    icon: Icons.music_note_outlined,
                    label: 'Music',
                    path: '$home/Music',
                    isActive: currentPath == '$home/Music',
                    onTap: () => _navigate(ref, '$home/Music'),
                  ),
                  SidebarItem(
                    icon: Icons.image_outlined,
                    label: 'Pictures',
                    path: '$home/Pictures',
                    isActive: currentPath == '$home/Pictures',
                    onTap: () => _navigate(ref, '$home/Pictures'),
                  ),
                  SidebarItem(
                    icon: Icons.videocam_outlined,
                    label: 'Videos',
                    path: '$home/Videos',
                    isActive: currentPath == '$home/Videos',
                    onTap: () => _navigate(ref, '$home/Videos'),
                  ),
                  SidebarItem(
                    icon: Icons.download_outlined,
                    label: 'Downloads',
                    path: '$home/Downloads',
                    isActive: currentPath == '$home/Downloads',
                    onTap: () => _navigate(ref, '$home/Downloads'),
                  ),
                  SidebarItem(
                    icon: Icons.access_time,
                    label: 'Recent',
                    path: 'virtual:recent',
                    isActive: currentPath == 'virtual:recent',
                    onTap: () => _navigate(ref, 'virtual:recent'),
                  ),

                  SidebarItem(
                    icon: Icons.delete_outline,
                    label: 'Trash',
                    path: '$home/.local/share/Trash/files',
                    isActive: currentPath == '$home/.local/share/Trash/files',
                    onTap: () =>
                        _navigate(ref, '$home/.local/share/Trash/files'),
                  ),

                  const SizedBox(height: 16),
                  _buildSectionLabel('DEVICES'),
                  DevicesSection(
                    currentPath: currentPath,
                    onNavigate: (path) => _navigate(ref, path),
                  ),

                  const SizedBox(height: 16),
                  _buildSectionLabel('CLOUD STORAGE'),
                  SidebarItem(
                    icon: Icons.add_circle_outline,
                    label: 'Add Account',
                    path: '',
                    isActive: false,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Cloud storage integration coming soon!',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.surfaceBase,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const StorageIndicator(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _navigate(WidgetRef ref, String path) {
    ref.read(previewFileProvider.notifier).state = null;
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).navigateTo(path);
    ref.read(currentPathProvider.notifier).state = path;
  }
}
