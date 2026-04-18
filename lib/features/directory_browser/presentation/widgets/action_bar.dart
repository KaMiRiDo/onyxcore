import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';

/// Action bar with gradient Add button and view options — pixel-perfect replica of original _buildActionBar().
class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentPath = ref.watch(currentPathProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            // Gradient "+ Add" button
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _handleAddFolder(context, ref, currentPath),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: Text(
                  'Add',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // View options
            Container(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildViewOption(Icons.grid_view_rounded, true),
                  _buildViewOption(Icons.sort_rounded, false),
                  _buildViewOption(Icons.filter_list_rounded, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOption(IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isActive ? Colors.white : AppColors.textMuted,
      ),
    );
  }

  Future<void> _handleAddFolder(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
  ) async {
    final name = await showInputDialog(
      context: context,
      title: 'New Folder',
      hint: 'Folder name',
    );
    if (name != null && name.isNotEmpty) {
      final repo = ref.read(directoryRepositoryProvider);
      await repo.createFolder(currentPath, name);
      await ref.read(directoryItemsProvider.notifier).refresh();
    }
  }
}
