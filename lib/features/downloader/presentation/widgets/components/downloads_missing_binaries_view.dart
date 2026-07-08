import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

/// Shows a blocking view when REQUIRED engines (yt-dlp, gallery-dl) are missing.
///
/// Optional engines (you-get, lux, streamlink, playwright) are managed
/// exclusively from Settings → Downloads → Installed Engines and never block
/// the panel here.
class DownloadsMissingBinariesView extends ConsumerWidget {

  const DownloadsMissingBinariesView({
    required this.onCheckBinaries, super.key,
  });
  final VoidCallback onCheckBinaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(downloaderUpdateProvider);
    final missingEngines = EngineRegistry.missingRequired;

    ref.listen(downloaderUpdateProvider, (prev, next) {
      if ((prev?.isUpdating ?? false) && !next.isUpdating && next.error == null) {
        onCheckBinaries();
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          Text(
            'Required Dependencies Missing',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Missing: ${missingEngines.map((e) => e.displayName).join(", ")}',
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Per-engine status indicators
          ...missingEngines.map(
            (engine) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(engine.icon, size: 16, color: engine.color),
                  const SizedBox(width: 8),
                  Text(
                    engine.displayName,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Missing',
                      style: GoogleFonts.manrope(
                        color: AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (updateState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Error: ${updateState.error}',
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (updateState.isUpdating) ...[
            LinearProgressIndicator(
              value: updateState.progress,
              backgroundColor: Colors.white10,
              color: AppColors.violet,
            ),
            const SizedBox(height: 8),
            Text(
              '${(updateState.progress * 100).toStringAsFixed(0)}% downloaded',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () {
                ref.read(downloaderUpdateProvider.notifier).updateBinaries();
              },
              icon: const Icon(Icons.cloud_download, size: 16),
              label: Text(
                'Download Required Engines',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
