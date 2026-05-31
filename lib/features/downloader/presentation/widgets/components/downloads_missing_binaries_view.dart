import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';

class DownloadsMissingBinariesView extends ConsumerWidget {
  final VoidCallback onCheckBinaries;

  const DownloadsMissingBinariesView({
    super.key,
    required this.onCheckBinaries,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(downloaderUpdateProvider);

    ref.listen(downloaderUpdateProvider, (prev, next) {
      if (prev?.isUpdating == true && !next.isUpdating && next.error == null) {
        onCheckBinaries();
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
            'Dependencies Needed',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Requires yt-dlp and gallery-dl binaries.',
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (updateState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
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
                'Download',
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
