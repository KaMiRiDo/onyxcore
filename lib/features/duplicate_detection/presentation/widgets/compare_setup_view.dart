import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_config_notifier.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';

/// Form view where the user configures source/destination folders and category.
class CompareSetupView extends ConsumerWidget {
  const CompareSetupView({required this.onStart, super.key});

  final VoidCallback onStart;

  Future<void> _pickFolder(
    BuildContext context,
    WidgetRef ref, {
    required bool isSource,
    String? initialDir,
  }) async {
    final result = await CustomFilePickerDialog.show(
      context,
      title: isSource ? 'Select Source Folder' : 'Select Destination Folder',
      pickDirectory: true,
      initialDirectory: initialDir,
    );

    if (result != null && result.isNotEmpty) {
      final notifier = ref.read(compareConfigProvider.notifier);
      if (isSource) {
        notifier.setSourceFolder(result.first);
      } else {
        notifier.setDestinationFolder(result.first);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(compareConfigProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cross-Folder Duplicate Detection',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compare two directories to identify identical or matching media files across folders.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 24),

          // Source Folder
          _buildFolderField(
            context,
            ref,
            label: 'Source Folder',
            path: config.sourceFolder,
            isSource: true,
          ),
          const SizedBox(height: 16),

          // Destination Folder
          _buildFolderField(
            context,
            ref,
            label: 'Destination Folder',
            path: config.destinationFolder,
            isSource: false,
          ),
          const SizedBox(height: 24),

          // Category Selector
          Text(
            'Category',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ComparisonCategory.values.map((cat) {
              final isSelected = config.category == cat;
              final label = _categoryLabel(cat);
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(compareConfigProvider.notifier).setCategory(cat);
                  }
                },
                selectedColor: AppColors.violet,
                backgroundColor: const Color(0xFF222222),
                labelStyle: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Validation Error Message
          if (config.errorMessage != null &&
              config.errorMessage!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      config.errorMessage!,
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: config.isValid ? onStart : null,
              icon: const Icon(Icons.compare_arrows_rounded, size: 18),
              label: Text(
                'Start Comparison',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderField(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String path,
    required bool isSource,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  path.isEmpty ? 'Select a folder...' : path,
                  style: GoogleFonts.inter(
                    color: path.isEmpty ? Colors.white38 : Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _pickFolder(
                context,
                ref,
                isSource: isSource,
                initialDir: path.isNotEmpty ? path : null,
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Browse...',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _categoryLabel(ComparisonCategory cat) {
    switch (cat) {
      case ComparisonCategory.all:
        return 'All';
      case ComparisonCategory.images:
        return 'Images';
      case ComparisonCategory.videos:
        return 'Videos';
      case ComparisonCategory.audio:
        return 'Audio';
      case ComparisonCategory.other:
        return 'Other';
    }
  }
}
