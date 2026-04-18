import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/core/utils/string_utils.dart';

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
            onPressed: () {},
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

        return Row(
          children: [
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
              ),
            InkWell(
              onTap: () {
                if (!isFileName) {
                  ref.read(previewFileProvider.notifier).state = null;
                  
                  if (currentPath.startsWith('virtual:')) {
                    // Do nothing or re-set virtual path
                  } else {
                    final targetRel = parts.sublist(0, index + 1).join('/');
                    final targetPath = targetRel.replaceFirst('Home', homePath);
                    ref.read(selectionProvider.notifier).deselectAll();
                    ref.read(navigationProvider.notifier).navigateTo(targetPath);
                    ref.read(currentPathProvider.notifier).state = targetPath;
                  }
                }
              },
              child: _buildGradientText(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: (isLast && !isFileName) || isFileName ? FontWeight.w800 : FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }).toList(),
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
