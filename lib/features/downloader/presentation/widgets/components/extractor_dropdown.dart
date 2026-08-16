import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class ExtractorDropdown extends ConsumerWidget {
  const ExtractorDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extractors = ref.watch(customExtractorsProvider).value ?? [];
    final controller = ref.watch(downloadsSharedControllerProvider);
    final isEnabled = ref.watch(settingsProvider).value?.customExtractorsEnabled ?? false;

    final isSmallWindow = MediaQuery.of(context).size.width < 1100;

    final options = <Map<String, String>>[
      {'key': 'none', 'label': 'No Extractor'},
      ...extractors.map((e) => {'key': e.id, 'label': e.name}),
    ];

    final selected = options.firstWhere(
      (o) => o['key'] == controller.selectedExtractorId,
      orElse: () => options.first,
    );

    return PopupMenuButton<String>(
      enabled: isEnabled,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (val) {
        controller.selectedExtractorId = val;
      },
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt['key'] == controller.selectedExtractorId;
        return PopupMenuItem<String>(
          value: opt['key'] ?? '',
          height: isSmallWindow ? 28 : 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withAlpha(15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.extension_rounded,
                  size: isSmallWindow ? 12 : 16,
                  color: isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  opt['label'] ?? '',
                  style: GoogleFonts.manrope(
                    fontSize: isSmallWindow ? 11 : 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isEnabled
                        ? (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8))
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: isSmallWindow ? 24 : 38,
        width: isSmallWindow ? 108 : 155,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.extension_rounded,
                    size: isSmallWindow ? 12 : 16,
                    color: isEnabled ? Colors.white : Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selected['label']!,
                      style: GoogleFonts.manrope(
                        color: isEnabled ? Colors.white : Colors.white54,
                        fontSize: isSmallWindow ? 11 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: isSmallWindow ? 12 : 16,
            ),
          ],
        ),
      ),
    );
  }
}
