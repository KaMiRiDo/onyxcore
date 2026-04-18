import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/cloud_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/overview_button.dart';
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
      width: 280,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Logo — "ONYXCORE" all caps, gradient, no icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                'ONYXCORE',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SidebarItem(
                  icon: Icons.home,
                  label: 'Home',
                  path: home,
                  isActive: currentPath == home,
                  onTap: () => _navigate(ref, home),
                ),
                SidebarItem(
                  icon: Icons.access_time,
                  label: 'Recent',
                  path: 'virtual:recent',
                  isActive: currentPath == 'virtual:recent',
                  onTap: () => _navigate(ref, 'virtual:recent'),
                ),
                SidebarItem(
                  icon: Icons.star_outline,
                  label: 'Starred',
                  path: 'virtual:starred',
                  isActive: currentPath == 'virtual:starred',
                  onTap: () => _navigate(ref, 'virtual:starred'),
                ),
                SidebarItem(
                  icon: Icons.description_outlined,
                  label: 'Documents',
                  path: '$home/Documents',
                  isActive: currentPath == '$home/Documents',
                  onTap: () => _navigate(ref, '$home/Documents'),
                ),
                SidebarItem(
                  icon: Icons.download_outlined,
                  label: 'Downloads',
                  path: '$home/Downloads',
                  isActive: currentPath == '$home/Downloads',
                  onTap: () => _navigate(ref, '$home/Downloads'),
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
                  icon: Icons.delete_outline,
                  label: 'Trash',
                  path: '$home/.local/share/Trash/files',
                  isActive: currentPath == '$home/.local/share/Trash/files',
                  onTap: () => _navigate(ref, '$home/.local/share/Trash/files'),
                ),

                const SizedBox(height: 20),
                _buildSectionLabel('OTHER LOCATIONS'),
                SidebarItem(
                  icon: Icons.dns_outlined,
                  label: 'Network',
                  path: '',
                  isActive: false,
                  onTap: () {},
                ),

                const SizedBox(height: 20),
                _buildSectionLabel('CLOUD STORAGE'),
                const CloudItem(),
                SidebarItem(
                  icon: Icons.add,
                  label: 'Add Account',
                  path: '',
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const StorageIndicator(),
          const SizedBox(height: 16),
          const OverviewButton(),
          const SizedBox(height: 24),
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
